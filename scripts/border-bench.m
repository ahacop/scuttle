// Times scuttle_border_update (reshape + redraw) at a new width each call, as a glide resize would,
// against scuttle_border_follow (move only). Draws around the frontmost normal window for ~2 s.
#import <AppKit/AppKit.h>
#import <mach/mach_time.h>
#import "borders.h"

static double ms(uint64_t t) { static mach_timebase_info_data_t tb; if (!tb.denom) mach_timebase_info(&tb); return t * tb.numer / tb.denom / 1e6; }

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSArray *list = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID));
        uint32_t target = 0; CGRect frame = CGRectZero;
        for (NSDictionary *w in list) {
            if ([w[(id)kCGWindowLayer] intValue] != 0) continue;
            CGRect r; CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)w[(id)kCGWindowBounds], &r);
            if (r.size.width < 400) continue;
            target = [w[(id)kCGWindowNumber] unsignedIntValue]; frame = r; break;
        }
        if (!target) { puts("no window"); return 1; }
        ScuttleBorder border = {0};
        if (!scuttle_border_create(&border, NSScreen.mainScreen.backingScaleFactor)) { puts("create failed"); return 1; }
        ScuttleBorderColor c = {0.3, 0.8, 0.7, 1};
        int n = 120; double total = 0, worst = 0, followTotal = 0, followWorst = 0;
        for (int i = 0; i < n; i++) {
            CGRect f = frame; f.size.width = frame.size.width * (0.6 + 0.4 * i / (double)n);
            uint64_t t0 = mach_absolute_time();
            scuttle_border_update(&border, target, f, 10, c, 4, ScuttleBorderOrderAbove);
            double d = ms(mach_absolute_time() - t0); total += d; if (d > worst) worst = d;
            usleep(8000);
        }
        for (int i = 0; i < n; i++) {
            CGRect f = frame; f.origin.x += i;
            uint64_t t0 = mach_absolute_time();
            scuttle_border_follow(&border, f, 4);
            double d = ms(mach_absolute_time() - t0); followTotal += d; if (d > followWorst) followWorst = d;
            usleep(8000);
        }
        printf("display scale %.0f, window %.0fx%.0f\n", NSScreen.mainScreen.backingScaleFactor, frame.size.width, frame.size.height);
        printf("update (reshape+redraw): avg %.2f ms, worst %.2f ms over %d\n", total / n, worst, n);
        printf("follow (move only):      avg %.2f ms, worst %.2f ms over %d\n", followTotal / n, followWorst, n);
        scuttle_border_hide(&border);
        scuttle_border_destroy(&border);
    }
    return 0;
}
