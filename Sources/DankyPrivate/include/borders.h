#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// Borders: plain SkyLight windows owned by danky, ordered directly below or above their target.
// Either way they never cover its content: they only cover the ring, and ignore the mouse. The
// JankyBorders approach, reimplemented, except that each border is four windows, one per edge, rather
// than one the size of its target: a window's backing store is its whole rectangle whatever its shape,
// so one window per border held a full-size bitmap per decorated window, ~25 MB each at 2x. The top
// and bottom edges are tall enough to carry the rounded corners. Main thread only.

// As CGSOrderingMode. Below, the target's own shadow falls on the ring and darkens it a
// little, as in JankyBorders; above, the ring is drawn over the shadow and keeps its colour.
typedef NS_ENUM(int, DankyBorderOrder) {
    DankyBorderOrderBelow = -1,
    DankyBorderOrderAbove = 1,
};

typedef struct {
    double red, green, blue, alpha;  // 0...1
} DankyBorderColor;

enum { DankyBorderEdges = 4 };

// One border: its edge windows (top, bottom, left, right) and where each sits in the ring, in points from
// the ring's top-left corner. An edge with an empty rect is unused, as the sides of a ring too short to
// have any between its corners.
typedef struct {
    uint32_t windows[DankyBorderEdges];
    CGRect edges[DankyBorderEdges];
} DankyBorder;

// Hidden, click-through, shadowless edge windows at `scale` (1 or 2, the target display's backing
// scale). All four or, returning false, none; the other functions take a border that was created.
bool danky_border_create(DankyBorder *border, double scale);

// Reshapes and redraws the border as a `width`-point ring hugging `frame` (the target's
// frame in global top-left coordinates) on the outside, then moves it, copies the target's
// level and sub-level and orders it directly next to `target`, all in one transaction.
void danky_border_update(DankyBorder *border, uint32_t target, CGRect frame, int cornerRadius,
                         DankyBorderColor color, double width, DankyBorderOrder order);

// Moves and re-orders without redrawing: for re-tiles and restacking that keep the size.
void danky_border_move(const DankyBorder *border, uint32_t target, CGRect frame, double width,
                       DankyBorderOrder order);

// Only moves, keeping the border's level and place in the stacking: the cheapest path, for a
// target that did nothing but move, as on every frame of a drag.
void danky_border_follow(const DankyBorder *border, CGRect frame, double width);

// Puts the border on the target's Space. New borders start on the current Space.
void danky_border_move_to_space(const DankyBorder *border, uint64_t spaceID);

void danky_border_hide(const DankyBorder *border);
void danky_border_destroy(DankyBorder *border);

// Whether `windowID` is one of the border's edge windows.
bool danky_border_owns(const DankyBorder *border, uint32_t windowID);

// The front app's frontmost document window on a visible Space, 0 if none.
// JankyBorders get_front_window.
uint32_t danky_border_focused_window(void);

NS_ASSUME_NONNULL_END
