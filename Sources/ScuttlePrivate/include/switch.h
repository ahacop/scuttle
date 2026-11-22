#pragma once
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

// Whether the native gesture supports an uninterrupted batch that skips intermediate redraws.
// Legacy gestures must instead acknowledge each adjacent landing.
bool scuttle_can_batch_space_swipes(void);

// Posts Space movement using legacy CGEvent fields before macOS 27 and augmented IOHID events from 27.
// Indices are 1-based and include full-screen Spaces. Refuses nonadjacent legacy movement or an unknown
// display; equal indices are a no-op. The entire movement is allocated before any input escapes, so false
// means nothing was posted. True confirms posting, not landing: observe the destination before posting
// again. If the cursor is elsewhere, warps to the display and pumps about 60 ms before restoring it.
bool scuttle_switch_to_space_index(int fromIndex, int toIndex, CFStringRef displayUUID);

// Real Dock swipes, for the trackpad swipe tap (Swipe.swift).

typedef NS_ENUM(int, ScuttleSwipePhase) {
    ScuttleSwipePhaseBegan = 1,
    ScuttleSwipePhaseChanged = 2,
    ScuttleSwipePhaseEnded = 4,
    ScuttleSwipePhaseCancelled = 8,
};

/// The events a tap needs to see the Dock swipe: Dock control events and the gesture events that come with them.
CGEventMask scuttle_dock_swipe_event_mask(void);
/// Reads a Dock swipe: its phase, whether it runs up and down (Mission Control and App Exposé) rather than sideways
/// (Spaces), and the way it heads: +1 toward what is right (a higher Space index) or below, -1 toward what is left
/// or above, 0 while it has not moved. False for any other event.
bool scuttle_read_dock_swipe(CGEventRef event, ScuttleSwipePhase *phase, bool *vertical, int *direction);
/// Whether the event is one of the gesture events that come with a Dock swipe.
bool scuttle_is_gesture_event(CGEventRef event);
/// Suppression is disabled on macOS 27+, whose attached IOHID payload cannot safely be neutralized here.
bool scuttle_can_suppress_dock_swipe(void);
/// Whether this particular event originated in scuttle. Never consumes unrelated physical events.
bool scuttle_is_own_dock_swipe(CGEventRef event);
