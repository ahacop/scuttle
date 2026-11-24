#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// Borders: plain SkyLight windows owned by scuttle, ordered directly below or above their target.
// Either way they never cover its content: they only cover the ring, and ignore the mouse. The
// JankyBorders approach, reimplemented, except that each border is four windows, one per edge, rather
// than one the size of its target: a window's backing store is its whole rectangle whatever its shape,
// so one window per border held a full-size bitmap per decorated window, ~25 MB each at 2x. The top
// and bottom edges are tall enough to carry the rounded corners. Main thread only.

// As CGSOrderingMode. Below, the target's own shadow falls on the ring and darkens it a
// little, as in JankyBorders; above, the ring is drawn over the shadow and keeps its colour.
typedef NS_ENUM(int, ScuttleBorderOrder) {
    ScuttleBorderOrderBelow = -1,
    ScuttleBorderOrderAbove = 1,
};

typedef struct {
    double red, green, blue, alpha;  // 0...1
} ScuttleBorderColor;

enum { ScuttleBorderEdges = 4 };

// One border: its edge windows (top, bottom, left, right) and where each sits in the ring, in points from
// the ring's top-left corner. An edge with an empty rect is unused, as the sides of a ring too short to
// have any between its corners.
typedef struct {
    uint32_t windows[ScuttleBorderEdges];
    CGRect edges[ScuttleBorderEdges];
} ScuttleBorder;

// Hidden, click-through, shadowless edge windows at `scale` (1 or 2, the target display's backing
// scale). All four or, returning false, none; the other functions take a border that was created.
bool scuttle_border_create(ScuttleBorder *border, double scale);

// Reshapes and redraws the border as a `width`-point ring hugging `frame` (the target's
// frame in global top-left coordinates) on the outside, then moves it, copies the target's
// level and sub-level and orders it directly next to `target`, all in one transaction.
void scuttle_border_update(ScuttleBorder *border, uint32_t target, CGRect frame, int cornerRadius,
                         ScuttleBorderColor color, double width, ScuttleBorderOrder order);

// For borders kept on moving windows every frame, all placed in one transaction: reshapes and redraws a border
// for a new size without placing it (screen updates are not held for it), then moves borders into a transaction
// that one commit sends. A border keeps the level and place in the stacking it was last given.
// With `sizeOnly` (only the size changed since the last draw), pieces whose size didn't change keep their drawing.
void scuttle_border_redraw_shape(ScuttleBorder *border, CGRect frame, int cornerRadius, ScuttleBorderColor color, double width,
                                 bool sizeOnly);
CFTypeRef _Nullable scuttle_border_transaction_create(void) CF_RETURNS_RETAINED;
void scuttle_border_transaction_follow(CFTypeRef transaction, const ScuttleBorder *border, CGRect frame, double width);
void scuttle_border_transaction_commit(CFTypeRef transaction);

// Redraws a border in another colour: same size, radius and width as it was last drawn with, so its pieces keep
// their shapes and only their contents change. Nothing is moved, ordered or held back: a focus change redraws two
// borders, and reshaping and placing each with screen updates held cost several times the drawing itself.
void scuttle_border_recolor(const ScuttleBorder *border, CGRect frame, int cornerRadius, ScuttleBorderColor color, double width);

// Moves and re-orders without redrawing: for re-tiles and restacking that keep the size.
void scuttle_border_move(const ScuttleBorder *border, uint32_t target, CGRect frame, double width,
                       ScuttleBorderOrder order);

// Only moves, keeping the border's level and place in the stacking: the cheapest path, for a
// target that did nothing but move, as on every frame of a drag.
void scuttle_border_follow(const ScuttleBorder *border, CGRect frame, double width);

// Puts the border on the target's Space. New borders start on the current Space.
void scuttle_border_move_to_space(const ScuttleBorder *border, uint64_t spaceID);

void scuttle_border_hide(const ScuttleBorder *border);
void scuttle_border_destroy(ScuttleBorder *border);

// Whether `windowID` is one of the border's edge windows.
bool scuttle_border_owns(const ScuttleBorder *border, uint32_t windowID);

// The front app's frontmost document window on a visible Space, 0 if none.
// JankyBorders get_front_window.
uint32_t scuttle_border_focused_window(void);

NS_ASSUME_NONNULL_END
