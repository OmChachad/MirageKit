#ifndef CLOOMSHELLSUPPORT_H
#define CLOOMSHELLSUPPORT_H

#include <sys/ioctl.h>
#include <sys/types.h>

pid_t loom_shell_forkpty_spawn(
    int *master_fd,
    const char *path,
    char *const argv[],
    char *const envp[],
    const char *working_directory,
    const struct winsize *window_size
);

#endif
