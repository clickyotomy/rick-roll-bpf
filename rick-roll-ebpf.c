/*
 * rick-roll-ebpf
 * --------------
 * Intercept "__x64_sys_openat" calls using "fentry" hooks
 * and replace the "pathname[]" argument of the function.
 */

#include <vmlinux.h>
#include <linux/version.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>

#define MAX_STRLEN 256
#define WATCH_EXT ".mp3"
#define REPL_PATH "/tmp/rick-roll.mp3"

/* Returns the length of "str[]". */
static __always_inline
int strlen(char *str)
{
	int i;
	for (i = 0; i < MAX_STRLEN && str[i] != '\0'; i++);

	return i;
}

/* Checks if "fname[]" ends with "WATCH_EXT". */
static __always_inline
int is_mp3(char *fname)
{
	int i, len, off;

	len = strlen(fname);
	if (!len || len > MAX_STRLEN || len < 5)
		return 0;

	char ext[] = WATCH_EXT;
	off = len - sizeof(ext) + 1;

	for (i = 0; i < 4; i++)
		if (fname[off + i] != ext[i])
			return 0;

	return 1;
}

/* Hooks onto "__x64_sys_openat". */
SEC("fentry/__x64_sys_openat")
int BPF_PROG(intercept_sys_openat, struct pt_regs *regs)
{
	char buf[MAX_STRLEN] = { 0 };
	char ext[] = WATCH_EXT;
	char rep[] = REPL_PATH;
	char log[] = "[rick-roll]: fentry/__x64_sys_openat: \"%s\"\n";

	/* Copy the "pathname[]" argument of "openat()" to the buffer. */
	char *fname = (char *)PT_REGS_PARM2(regs);
	bpf_probe_read(buf, sizeof(buf), fname);

	/* Check if the file extension is "WATCH_EXT"; replace it. */
	if (is_mp3(buf)) {
		/* This logs it to "/sys/kernel/tracing/trace". */
		bpf_trace_printk(log, sizeof(log), fname);
		bpf_probe_write_user(fname, rep, sizeof(rep));
	}

	return 0;
}

char _license[] SEC("license") = "GPL";
u32 _version SEC("version") = LINUX_VERSION_CODE;
