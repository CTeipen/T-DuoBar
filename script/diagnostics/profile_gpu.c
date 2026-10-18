#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

static double now_s(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC_RAW, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}
static void number(CFDictionaryRef d, CFStringRef key) {
    CFTypeRef value = d ? CFDictionaryGetValue(d, key) : NULL;
    double result;
    if (value && CFGetTypeID(value) == CFNumberGetTypeID() &&
        CFNumberGetValue(value, kCFNumberDoubleType, &result) && isfinite(result)) printf("%.6f", result);
    else printf("null");
}
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    char *end;
    double duration = strtod(argv[1], &end);
    if (*end || !isfinite(duration) || duration < 1 || duration > 3600) return 2;
    io_iterator_t iterator;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) != KERN_SUCCESS) return 1;
    io_service_t gpu = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (!gpu) { fprintf(stderr, "No IOAccelerator service\n"); return 1; }
    double start = now_s();
    for (unsigned sample = 0;; sample++) {
        double elapsed = now_s() - start;
        CFTypeRef property = IORegistryEntryCreateCFProperty(gpu, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0);
        CFDictionaryRef stats = property && CFGetTypeID(property) == CFDictionaryGetTypeID() ? (CFDictionaryRef)property : NULL;
        printf("{\"elapsed_s\":%.6f,\"device_utilization_percent\":", elapsed);
        number(stats, CFSTR("Device Utilization %"));
        printf(",\"renderer_utilization_percent\":"); number(stats, CFSTR("Renderer Utilization %"));
        printf(",\"tiler_utilization_percent\":"); number(stats, CFSTR("Tiler Utilization %"));
        printf("}\n"); fflush(stdout);
        if (property) CFRelease(property);
        if (elapsed >= duration) break;
        double delay = start + sample + 1 - now_s();
        if (delay > 0) { struct timespec wait = {(time_t)delay, (long)((delay - (time_t)delay) * 1e9)}; nanosleep(&wait, NULL); }
    }
    IOObjectRelease(gpu);
    return 0;
}
