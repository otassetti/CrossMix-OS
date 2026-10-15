SHELL := /bin/sh
CROSS_COMPILE ?= aarch64-nextui-linux-gnu-
CC := $(CROSS_COMPILE)gcc
PKG_CONFIG ?= pkg-config
BUILD_DIR ?= build
SRC := $(wildcard src/*.c)
CFLAGS := -std=gnu11 -O2 -Wall -Wextra -Wno-unused-parameter -Wno-format-truncation -mcpu=cortex-a53 -DPLATFORM_TG5040 -Ithird_party/apostrophe/include -Isrc $(shell $(PKG_CONFIG) --cflags sdl2)
LDLIBS := $(shell $(PKG_CONFIG) --libs sdl2) -lSDL2_ttf -lSDL2_image -lpthread -lm

.PHONY: all
all: $(BUILD_DIR)/moonlight-pak
$(BUILD_DIR)/moonlight-pak: $(SRC) $(wildcard src/*.h third_party/apostrophe/include/*.h)
	mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SRC) -o $@ $(LDLIBS)
