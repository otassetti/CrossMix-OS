/* Observe key state without grabbing or consuming the client's input events. */
#include "stream_control.h"
#include <errno.h>
#include <linux/input.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static long long milliseconds(void)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (long long)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

int ml_wait_stream(pid_t pid, int input_fd)
{
    long long held_since = 0;
    bool exit_requested = false;
    int status;
    for (;;) {
        pid_t result = waitpid(pid, &status, WNOHANG);
        if (result == pid) break;
        if (result < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (input_fd >= 0 && !exit_requested) {
            unsigned char keys[(KEY_MAX + 8) / 8] = {0};
            bool pressed = ioctl(input_fd, EVIOCGKEY(sizeof(keys)), keys) >= 0
                && (keys[BTN_SELECT / 8] & (1u << (BTN_SELECT % 8)))
                && (keys[BTN_START / 8] & (1u << (BTN_START % 8)));
            long long now = milliseconds();
            if (!pressed) held_since = 0;
            else if (!held_since) held_since = now;
            else if (now - held_since >= 1000) {
                /* Target only our child adapter; its trap stops its client and
                   restores the CPU policy. Never kill unrelated Moonlight jobs. */
                if (kill(pid, SIGTERM) == 0) {
                    fprintf(stderr, "Stream exit requested by SELECT + START\n");
                    exit_requested = true;
                }
            }
        }
        struct timespec interval = {0, 100000000};
        nanosleep(&interval, NULL);
    }
    if (exit_requested) return 0;
    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}
