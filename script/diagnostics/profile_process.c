#include <errno.h>
#include <inttypes.h>
#include <libproc.h>
#include <limits.h>
#include <math.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>

static double monotonic_seconds(void) {
    struct timespec value;
    clock_gettime(CLOCK_MONOTONIC_RAW, &value);
    return (double)value.tv_sec + (double)value.tv_nsec / 1e9;
}

int main(int argc, char **argv) {
    if (argc != 3 && argc != 4) { fprintf(stderr, "Usage: profile_process PID SECONDS [INTERVAL]\n"); return 2; }
    char *end = NULL;
    long pid = strtol(argv[1], &end, 10);
    if (!end || *end || pid <= 0 || pid > INT_MAX) return 2;
    double duration = strtod(argv[2], &end);
    if (!end || *end || !isfinite(duration) || duration < 1 || duration > 3600) return 2;
    double interval = argc == 4 ? strtod(argv[3], &end) : 1;
    if (!isfinite(interval) || interval < 0.1 || interval > 5 || (argc == 4 && (!end || *end))) return 2;
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
#define AS_NS(value) ((uint64_t)((__uint128_t)(value) * timebase.numer / timebase.denom))
    double start = monotonic_seconds();
    uint64_t process_start = 0;
    for (unsigned index = 0;; index++) {
        struct rusage_info_v4 usage = {0};
        if (proc_pid_rusage((int)pid, RUSAGE_INFO_V4, (rusage_info_t *)&usage) != 0) {
            perror("proc_pid_rusage"); return 1;
        }
        if (index == 0) process_start = usage.ri_proc_start_abstime;
        if (usage.ri_proc_start_abstime != process_start) {
            fprintf(stderr, "PID was reused\n"); return 1;
        }
        double elapsed = monotonic_seconds() - start;
        printf("{\"elapsed_s\":%.6f,\"pid\":%ld,\"user_ns\":%" PRIu64
               ",\"system_ns\":%" PRIu64 ",\"child_user_ns\":%" PRIu64
               ",\"child_system_ns\":%" PRIu64 ",\"resident_bytes\":%" PRIu64
               ",\"footprint_bytes\":%" PRIu64 ",\"interrupt_wakeups\":%" PRIu64
               ",\"package_idle_wakeups\":%" PRIu64 ",\"disk_read_bytes\":%" PRIu64
               ",\"disk_write_bytes\":%" PRIu64 "}\n", elapsed, pid,
               AS_NS(usage.ri_user_time), AS_NS(usage.ri_system_time), AS_NS(usage.ri_child_user_time),
               AS_NS(usage.ri_child_system_time), usage.ri_resident_size, usage.ri_phys_footprint,
               usage.ri_interrupt_wkups, usage.ri_pkg_idle_wkups,
               usage.ri_diskio_bytesread, usage.ri_diskio_byteswritten);
        fflush(stdout);
        if (elapsed >= duration) break;
        double delay = start + (double)(index + 1) * interval - monotonic_seconds();
        if (delay > 0) {
            struct timespec sleep_time = { .tv_sec = (time_t)delay,
                .tv_nsec = (long)((delay - (double)(time_t)delay) * 1e9) };
            while (nanosleep(&sleep_time, &sleep_time) != 0 && errno == EINTR) {}
        }
    }
    return 0;
}
