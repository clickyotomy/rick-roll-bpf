/*
 * rick-roll-user
 * --------------
 * Attach and run the generated eBPF program: "rick-roll-ebpf",
 * included in "rick-roll-skel.h" from userspace.
 */

#include <rick-roll-skel.h>
#include <bpf/bpf.h>
#include <bpf/libbpf.h>
#include <stdio.h>
#include <unistd.h>

#define LOG_PFX   "[rick-roll]"
#define WATCH_EXT ".mp3"

/* For debugging. */
int log_debug(enum libbpf_print_level level, const char *format, va_list args)
{

	return vfprintf(stderr, format, args);
}

int main(int argc, char **argv)
{
	int err;
	struct rick_roll_ebpf *obj;

	/* When we need debugging. */
	/* libbpf_set_print(log_debug); */

	/* Load the eBPF object. */
	obj = rick_roll_ebpf__open_and_load();
	if (!obj) {
		fprintf(stderr,
			"%s: failed to open and/or load eBPF object file\n",
		       LOG_PFX);
		return 1;
	}

	/* Attach it. */
	err = rick_roll_ebpf__attach(obj);
	if (err) {
		fprintf(stderr,
			"%s: failed to attach eBPF program (error: %s)\n",
			LOG_PFX,
			strerror(-err));
		goto cleanup;
	}

	/* Pause for a signal. */
	fprintf(stderr,
		"%s: intercepting calls to \"__x64_sys_openat\" "
		"for \"*%s\"...\n",
		LOG_PFX, WATCH_EXT);
	pause();

cleanup:
	rick_roll_ebpf__destroy(obj);

	return err != 0;
}
