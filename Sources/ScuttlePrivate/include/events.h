#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// WindowServer notification types, the numbers SLSRegisterNotifyProc takes.
// From JankyBorders src/events.h; SpaceCreated/Destroyed from yabai src/yabai.c.
typedef NS_ENUM(uint32_t, ScuttleEventKind) {
    ScuttleEventWindowUpdate = 723,
    ScuttleEventWindowClose = 804,
    ScuttleEventWindowMove = 806,
    ScuttleEventWindowResize = 807,
    ScuttleEventWindowReorder = 808,
    ScuttleEventWindowLevel = 811,
    ScuttleEventWindowUnhide = 815,
    ScuttleEventWindowHide = 816,
    ScuttleEventWindowTitle = 1322,
    ScuttleEventWindowCreate = 1325,
    ScuttleEventWindowDestroy = 1326,
    ScuttleEventSpaceCreated = 1327,
    ScuttleEventSpaceDestroyed = 1328,
    ScuttleEventSpaceChange = 1401,
    ScuttleEventFrontApp = 1508,
};

typedef struct {
    ScuttleEventKind kind;
    uint32_t windowID;  // 0 for Space and front app events
    pid_t pid;          // window owner, or the front app for ScuttleEventFrontApp; 0 if gone, and for a move, resize or update
    uint64_t spaceID;   // create/destroy and Space created/destroyed only, else 0
} ScuttleEvent;

typedef void (*ScuttleEventCallback)(ScuttleEvent event, void *_Nullable context);

// Registers for every ScuttleEventKind on the main connection. Callbacks run on the main
// thread, from inside the AppKit event loop: SkyLight dispatches notify procs while it
// drains the connection's event port, which [NSApp run] does. Without a running
// NSApplication nothing is delivered. Returns false if registration failed.
bool scuttle_events_start(ScuttleEventCallback callback, void *_Nullable context);

// The per-window events (close, move, resize, reorder, level, hide, unhide) only arrive
// for windows named here. Each call replaces the previous list.
void scuttle_events_watch_windows(const uint32_t *windowIDs, int count);

typedef struct {
    bool exists;
    uint32_t windowID;
    pid_t pid;
    CGRect frame;          // global display coordinates, top-left origin
    int level;
    uint32_t parentID;
    uint64_t tags;
    uint64_t attributes;
    bool isOrderedIn;
    bool isDocument;       // JankyBorders window_suitable, kind only: a real document or modal window
    bool isVisible;        // the visible attribute or tag; clear while minimized
    bool isMinimized;      // yabai space_window_list minimized test
} ScuttleWindowInfo;

ScuttleWindowInfo scuttle_window_info(uint32_t windowID);

// The window's corner radius, 0 if SkyLight does not report one. SkyLight leaks the radii it reports
// whenever they are not whole numbers, so this is read once per window rather than with every info read.
int scuttle_window_corner_radius(uint32_t windowID);

// The frame alone, in one call where scuttle_window_info makes several: for a window that moved.
// CGRectNull if the window is gone.
CGRect scuttle_window_frame(uint32_t windowID);

// The smallest and largest frame each window's app has said the window takes (NSWindow's minSize and maxSize, or
// its content sizes with the title bar added), as the window server holds them: [minimum width, minimum height,
// maximum width, maximum height] by window id. Asks nothing of the apps. A window that has gone is left out; one
// whose app set no limit has zeros for the minimum and a very large maximum. A size an app only refuses when
// asked (a window delegate's, or a terminal's whole characters) is not here.
NSDictionary<NSNumber *, NSArray<NSNumber *> *> *scuttle_window_size_limits(NSArray<NSNumber *> *windowIDs);

// Every window on every Space, minimized included, filtered like scuttle_space_window_ids.
NSArray<NSNumber *> *scuttle_all_window_ids(void);

NS_ASSUME_NONNULL_END
