#include "apostrophe.h"
#include "moonlight.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include <poll.h>
#include <errno.h>

static void parse_pin(const char *line, char *pin_out, int pin_size)
{
    const char *pin_marker = strstr(line, "PIN");
    if (!pin_marker) return;

    const char *digit = pin_marker;
    while (*digit && (*digit < '0' || *digit > '9'))
        digit++;
    if (!*digit) return;

    const char *end = digit;
    while (*end >= '0' && *end <= '9')
        end++;

    int len = (int)(end - digit);
    if (len > 0 && len < pin_size) {
        memcpy(pin_out, digit, len);
        pin_out[len] = '\0';
    }
}

static pid_t spawn_cmd(char *const argv[], int *out_fd)
{
    int pipefd[2];
    if (pipe(pipefd) < 0) return -1;

    pid_t pid = fork();
    if (pid < 0) {
        close(pipefd[0]);
        close(pipefd[1]);
        return -1;
    }

    if (pid == 0) {
        setpgid(0, 0);
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);
        execvp(argv[0], argv);
        _exit(127);
    }

    close(pipefd[1]);
    *out_fd = pipefd[0];
    return pid;
}

static void kill_child(pid_t pid, int fd)
{
    kill(-pid, SIGTERM);
    close(fd);
    waitpid(pid, NULL, 0);
}

int ml_pair(const char *host, char *pin_out, int pin_size,
            int *interrupt, char **dynamic_msg, char *msg_buf, int msg_buf_size)
{
    char *args[] = {"moonlight", "pair", (char *)host, NULL};

    ap_log("moonlight: pairing with %s", host);

    int fd;
    pid_t pid = spawn_cmd(args, &fd);
    if (pid < 0) return -1;

    pin_out[0] = '\0';
    char line[512];
    int line_pos = 0;
    bool success = false;

    struct pollfd pfd = { .fd = fd, .events = POLLIN };

    while (1) {
        if (interrupt && *interrupt) {
            ap_log("moonlight: pairing cancelled by user");
            kill_child(pid, fd);
            return -2;
        }

        int ready = poll(&pfd, 1, 200);
        if (ready < 0) break;
        if (ready == 0) continue;

        char ch;
        ssize_t n = read(fd, &ch, 1);
        if (n <= 0) break;

        if (ch == '\n' || line_pos >= (int)sizeof(line) - 1) {
            line[line_pos] = '\0';
            ap_log("moonlight pair: %s", line);

            if (!pin_out[0])
                parse_pin(line, pin_out, pin_size);

            if (pin_out[0] && dynamic_msg && msg_buf) {
                snprintf(msg_buf, msg_buf_size,
                         "Enter PIN on your PC:  %s",
                         pin_out);
                *dynamic_msg = msg_buf;
            }

            if (strstr(line, "Failed") || strstr(line, "failed"))
                break;
            if (strstr(line, "Successfully") || strstr(line, "successfully"))
                success = true;

            line_pos = 0;
        } else {
            line[line_pos++] = ch;
        }
    }

    close(fd);
    int status;
    waitpid(pid, &status, 0);
    int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : -1;

    if (success && exit_code != 0)
        exit_code = 0;

    return exit_code;
}

int ml_list_apps(const char *host, ml_app *apps, int max_apps, int *interrupt)
{
    char *args[] = {"moonlight", "list", (char *)host, NULL};

    ap_log("moonlight: listing apps on %s", host);

    int fd;
    pid_t pid = spawn_cmd(args, &fd);
    if (pid < 0) return -1;

    int count = 0;
    char line[512];
    int line_pos = 0;
    struct pollfd pfd = { .fd = fd, .events = POLLIN };

    while (count < max_apps) {
        if (interrupt && *interrupt) {
            ap_log("moonlight: list cancelled by user");
            kill_child(pid, fd);
            return -2;
        }

        int ready = poll(&pfd, 1, 200);
        if (ready < 0) break;
        if (ready == 0) continue;

        char ch;
        ssize_t n = read(fd, &ch, 1);
        if (n <= 0) break;

        if (ch == '\n' || line_pos >= (int)sizeof(line) - 1) {
            line[line_pos] = '\0';
            ap_log("moonlight list: %s", line);

            int app_num;
            char app_name[ML_MAX_NAME];
            /* Validate: line must start with digits, then ". ", then name.
             * Reject IPs like "192.168.0.1" where no space follows the dot. */
            char *first_dot = strchr(line, '.');
            if (first_dot && first_dot[1] == ' ' &&
                sscanf(line, "%d. %255[^\n]", &app_num, app_name) == 2 && app_name[0]) {
                snprintf(apps[count].name, sizeof(apps[count].name), "%s", app_name);
                ap_log("moonlight: found app [%d] %s", count, apps[count].name);
                count++;
            }

            line_pos = 0;
        } else {
            line[line_pos++] = ch;
        }
    }

    close(fd);
    int status;
    waitpid(pid, &status, 0);

    if (count == 0) return -1;
    return count;
}

int ml_stream(const ml_config *cfg, const char *app_name)
{
    if (cfg->active_server < 0 || cfg->active_server >= cfg->server_count)
        return -1;

    const char *host = cfg->servers[cfg->active_server].host;
    char width[16], height[16], fps[16], bitrate[16];
    snprintf(width, sizeof(width), "%d", cfg->width);
    snprintf(height, sizeof(height), "%d", cfg->height);
    snprintf(fps, sizeof(fps), "%d", cfg->fps);
    snprintf(bitrate, sizeof(bitrate), "%d", cfg->bitrate);
    char *args[] = {"moonlight", "stream", (char *)host,
                    "-app", (char *)app_name, "-width", width,
                    "-height", height, "-fps", fps, "-bitrate", bitrate, NULL};

    /* No shell: host/application names remain literal arguments. */
    pid_t pid = fork();
    if (pid < 0) return -1;
    if (pid == 0) {
        execvp(args[0], args);
        _exit(127);
    }
    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) return -1;
    }
    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}
