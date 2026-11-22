#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// WindowServer notification types, the numbers SLSRegisterNotifyProc takes.
// From JankyBorders src/events.h; SpaceCreated/Destroyed from yabai src/yabai.c.
typedef NS_ENUM(uint32_t, DankyEventKind) {
    DankyEventWindowUpdate = 723,
    DankyEventWindowClose = 804,
    DankyEventWindowMove = 806,
    DankyEventWindowResize = 807,
    DankyEventWindowReorder = 808,
    DankyEventWindowLevel = 811,
    DankyEventWindowUnhide = 815,
    DankyEventWindowHide = 816,
    DankyEventWindowTitle = 1322,
    DankyEventWindowCreate = 1325,
    DankyEventWindowDestroy = 1326,
    DankyEventSpaceCreated = 1327,
    DankyEventSpaceDestroyed = 1328,
    DankyEventSpaceChange = 1401,
    DankyEventFrontApp = 1508,
};

typedef struct {
    DankyEventKind kind;
    uint32_t windowID;  // 0 for Space and front app events
    pid_t pid;          // window owner, or the front app for DankyEventFrontApp; 0 if gone, and for a move
    uint64_t spaceID;   // create/destroy and Space created/destroyed only, else 0
} DankyEvent;

typedef void (*DankyEventCallback)(DankyEvent event, void *_Nullable context);

// Registers for every DankyEventKind on the main connection. Callbacks run on the main
// thread, from inside the AppKit event loop: SkyLight dispatches notify procs while it
// drains the connection's event port, which [NSApp run] does. Without a running
// NSApplication nothing is delivered. Returns false if registration failed.
bool danky_events_start(DankyEventCallback callback, void *_Nullable context);

// The per-window events (close, move, resize, reorder, level, hide, unhide) only arrive
// for windows named here. Each call replaces the previous list.
void danky_events_watch_windows(const uint32_t *windowIDs, int count);

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
} DankyWindowInfo;

DankyWindowInfo danky_window_info(uint32_t windowID);

// The window's corner radius, 0 if SkyLight does not report one. SkyLight leaks the radii it reports
// whenever they are not whole numbers, so this is read once per window rather than with every info read.
int danky_window_corner_radius(uint32_t windowID);

// The frame alone, in one call where danky_window_info makes several: for a window that moved.
// CGRectNull if the window is gone.
CGRect danky_window_frame(uint32_t windowID);

// Every window on every Space, minimized included, filtered like danky_space_window_ids.
NSArray<NSNumber *> *danky_all_window_ids(void);

NS_ASSUME_NONNULL_END
