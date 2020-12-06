# Makefile for building "rick-roll".
PROG_NAME       := rick-roll
KERN_VERSION    := $(shell uname -r)
TARGET_ARCH     := $(shell uname -m | sed 's/x86_64/x86/')
VMLINUX_BTF     := /sys/kernel/btf/vmlinux
LIBBPF_SRC      := $(abspath ./libbpf/src)
LIBBPF_STATIC   := $(abspath $(LIBBPF_SRC)/libbpf.a)
DEBIAN_FRONTEND := noninteractive
INCLUDES_DIR    := $(abspath ./include)
INCLUDES        := -I./include
CFLAGS          := -g -O2 -Wall -Wextra
CFLAGS_LAX      := -Wno-visibility -Wno-unused-function -Wno-unused-variable \
                   -Wno-unused-parameter
LIB_EXT         := -lz -lelf

CLANG           = $(shell command -v clang)
LLVM_STRIP      = $(shell command -v llvm-strip)
BPFTOOL         = $(shell command -v bpftool)

BUILD_SHARED    ?= true
OBJ_DIR         ?= $(abspath ./objects)
BIN_DIR         ?= $(abspath ./bin)

# Build the binary with the shared or static version of `libbpf`.
ifeq ($(BUILD_SHARED),true)
LIB_FLAGS = -L$(LIBBPF_SRC) -Wl,-rpath=$(LIBBPF_SRC) -lbpf
else
LIB_FLAGS = $(LIBBPF_STATIC)
endif

# For verbosity.
ifeq ($(V),1)
Q =
msg =
APT_FLAGS = -y
APT_QUIET =
LIBBPF_MAKEFLAGS = V=1
else
Q = @
APT_FLAGS = -qq -o=Dpkg::Use-Pty=0
APT_QUIET = < /dev/null > /dev/null
msg = @printf '  %-8s %s%s\n' "$(1)" "$(2)" "$(if $(3), $(3))";
MAKEFLAGS += --no-print-directory
LIBBPF_MAKEFLAGS = -s
endif

all: $(BIN_DIR)/$(PROG_NAME)

# Build the binary.
$(BIN_DIR)/$(PROG_NAME): $(INCLUDES_DIR)/$(PROG_NAME)-skel.h
	$(call msg,MKDIR,$(BIN_DIR))
	$(Q)mkdir -p $(BIN_DIR)
	$(call msg,BINARY,$@)
	$(Q)$(CLANG) $(CFLAGS) $(CFLAGS_LAX) $(INCLUDES) \
		$(PROG_NAME)-user.c $(LIB_FLAGS) $(LIB_EXT) -o $@

# Generate skeleton headers from the built eBPF program object file.
$(INCLUDES_DIR)/$(PROG_NAME)-skel.h: $(OBJ_DIR)/$(PROG_NAME)-ebpf.o
	$(call msg,SKEL,$@)
	$(Q)$(BPFTOOL) gen skeleton $^ > $@

# Build the eBPF program.
$(OBJ_DIR)/$(PROG_NAME)-ebpf.o: $(INCLUDES_DIR)/vmlinux.h
	$(call msg,MKDIR,$(OBJ_DIR))
	$(Q)mkdir -p $(OBJ_DIR)
	$(call msg,CC,$@)
	$(Q)$(CLANG) $(CFLAGS) $(CFLAGS_LAX) $(INCLUDES) -target bpf \
		-D__TARGET_ARCH_$(TARGET_ARCH) -c $(PROG_NAME)-ebpf.c -o $@
	$(call msg,STRIP,$@)
	$(Q)$(LLVM_STRIP) -g $@

# Generate "vmlinux.h".
$(INCLUDES_DIR)/vmlinux.h: libbpf
	$(call msg,MKDIR,$(INCLUDES_DIR))
	$(Q)mkdir -p $(INCLUDES_DIR)
	$(call msg,LN,$(INCLUDES_DIR)/bpf)
	$(Q)ln -sfn $(LIBBPF_SRC) $(INCLUDES_DIR)/bpf
	$(call msg,VMLINUX,$@)
	$(Q)$(BPFTOOL) btf dump file $(VMLINUX_BTF) format c > $@

# Build `libbpf`.
libbpf: deps
	$(call msg,MAKE,LIBBPF,$(LIBBPF_SRC))
	$(Q)$(MAKE) $(LIBBPF_MAKEFLAGS) -C $(LIBBPF_SRC)

# Install dependencies.
deps:
	$(call msg,"DEPS")
	$(Q)apt-get $(APT_FLAGS) update $(APT_QUIET)
	$(Q)apt-get $(APT_FLAGS) install git clang llvm libelf-dev    \
		pkg-config linux-tools-common linux-tools-generic     \
		linux-cloud-tools-generic linux-tools-$(KERN_VERSION) \
		linux-cloud-tools-$(KERN_VERSION) $(APT_QUIET)

# Clean build artifacts.
clean:
	$(call msg,"CLEAN")
	$(Q)rm -rf $(BIN_DIR) $(OBJ_DIR) $(INCLUDES_DIR)
	$(Q)$(MAKE) $(LIBBPF_MAKEFLAGS) -C $(LIBBPF_SRC) clean

.PHONY: libbpf deps clean

.DELETE_ON_ERROR:
.NOTPARALLEL:
