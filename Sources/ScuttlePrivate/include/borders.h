#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

// Borders: plain SkyLight windows owned by scuttle, ordered directly below or above their target.
// Either way they never cover its content: they only cover the ring, and ignore the mouse. The
// JankyBorders approach, reimplemented, except that each border is four windows rather than one the size of its
// target: a window's backing store is its whole rectangle whatever its shape, so one window per border held a
// full-size bitmap per decorated window, ~25 MB each at 2x. Two are the sides, which carry the corners, and two the
// straight runs between them along the top and the bottom. A run is one colour from end to end, so when its target
// changes width, which is the only size scuttle changes, the window server stretches it and nothing is reshaped or
// redrawn until the target has arrived: on every frame of a gliding resize, reshaping and redrawing the two pieces
// that changed length cost about 2 ms each. Four corners and four runs, which could follow a change of height as
// well, were tried: twice the windows had the window server drop frames while slow apps resized (scripts/anim,
// `pfreeze`). Main thread only.

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

// One border: its pieces (the left side, the right side, the top run, the bottom run) and where each sits in the
// ring as it was last drawn, in points from the ring's top-left corner. A piece with an empty rect is unused: a
// ring too narrow to have runs is all in the first piece.
typedef struct {
    uint32_t windows[ScuttleBorderEdges];
    CGRect edges[ScuttleBorderEdges];
    // Whether the window server has the piece stretched now: a run that is, is given a transform with every move.
    bool stretched[ScuttleBorderEdges];
} ScuttleBorder;

// Hidden, click-through, shadowless edge windows at `scale` (1 or 2, the target display's backing
// scale). All four or, returning false, none; the other functions take a border that was created.
bool scuttle_border_create(ScuttleBorder *border, double scale);

// Reshapes and redraws the border as a `width`-point ring hugging `frame` (the target's
// frame in global top-left coordinates) on the outside, then moves it, copies the target's
// level and sub-level and orders it directly next to `target`, all in one transaction.
void scuttle_border_update(ScuttleBorder *border, uint32_t target, CGRect frame, int cornerRadius,
                         ScuttleBorderColor color, double width, ScuttleBorderOrder order);

// For borders kept on moving windows every frame, all placed in one transaction: `scuttle_border_transaction_follow`
// moves a border's pieces to `frame` in the transaction, stretching its runs if the frame has another width than
// the border was drawn for, and one commit sends them all. A border keeps the level and place in the stacking it
// was last given. It answers false, having done nothing, when the border cannot follow as it is drawn (its height
// changed, or the ring became too narrow for runs, or wide enough for them): then `scuttle_border_redraw_shape`
// reshapes and redraws it for the frame and moves it there, without ordering it, and it can follow.
// With `sizeOnly` (only the size changed since the last draw), pieces whose size didn't change keep their drawing.
void scuttle_border_redraw_shape(ScuttleBorder *border, CGRect frame, int cornerRadius, ScuttleBorderColor color, double width,
                                 bool sizeOnly);
// For a frame of another height than the border was drawn for: reshapes and redraws the sides for it, which is
// cheap, and leaves the runs as drawn, to be stretched by `scuttle_border_transaction_follow`, which then succeeds.
// A window opening changes height on every frame, and redrawing the whole border with screen updates held took
// 20 to 30 ms of each. False, having done nothing, when the ring became too narrow for runs or wide enough for them.
bool scuttle_border_fit_sides(ScuttleBorder *border, CGRect frame, int cornerRadius, ScuttleBorderColor color, double width);
CFTypeRef _Nullable scuttle_border_transaction_create(void) CF_RETURNS_RETAINED;
bool scuttle_border_transaction_follow(CFTypeRef transaction, ScuttleBorder *border, CGRect frame, int cornerRadius, double width);
void scuttle_border_transaction_commit(CFTypeRef transaction);

// Redraws a border in another colour: same size, radius and width as it was last drawn with, so its pieces keep
// their shapes and only their contents change. Nothing is moved, ordered or held back: a focus change redraws two
// borders, and reshaping and placing each with screen updates held cost several times the drawing itself.
void scuttle_border_recolor(const ScuttleBorder *border, CGRect frame, int cornerRadius, ScuttleBorderColor color, double width);

// Moves and re-orders without redrawing: for re-tiles and restacking that keep the size.
void scuttle_border_move(ScuttleBorder *border, uint32_t target, CGRect frame, double width,
                       ScuttleBorderOrder order);

// Only moves, keeping the border's level and place in the stacking: the cheapest path, for a
// target that did nothing but move, as on every frame of a drag.
void scuttle_border_follow(ScuttleBorder *border, CGRect frame, double width);

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
