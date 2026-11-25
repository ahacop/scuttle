#import "borders.h"
#import "query.h"
#import "skylight.h"
#import "border_path.h"

// Window creation, shape and drawing, as JankyBorders src/misc/extern.h declares them.
extern CGError CGSNewRegionWithRect(CGRect *rect, CFTypeRef *region);
extern CGError SLSNewWindow(int cid, int type, float x, float y, CFTypeRef region, uint32_t *wid);
extern CGError SLSReleaseWindow(int cid, uint32_t wid);
extern CGError SLSSetWindowTags(int cid, uint32_t wid, uint64_t *tags, int tagSize);
extern CGError SLSSetWindowShape(int cid, uint32_t wid, float x, float y, CFTypeRef shape);
extern CGError SLSSetWindowResolution(int cid, uint32_t wid, double resolution);
extern CGError SLSSetWindowOpacity(int cid, uint32_t wid, bool isOpaque);
extern CGError SLSWindowSetShadowProperties(uint32_t wid, CFDictionaryRef properties);
extern CGError SLSGetWindowLevel(int cid, uint32_t wid, int64_t *level);
extern int32_t SLSGetWindowSubLevel(int cid, uint32_t wid) __attribute__((weak_import));
extern CGContextRef SLWindowContextCreate(int cid, uint32_t wid, CFDictionaryRef options);
extern CGError SLSFlushWindowContentRegion(int cid, uint32_t wid, void *dirty);
extern CGError SLSDisableUpdate(int cid);
extern CGError SLSReenableUpdate(int cid);

extern CFTypeRef SLSTransactionCreate(int cid);
extern CGError SLSTransactionMoveWindowWithGroup(CFTypeRef transaction, uint32_t wid, CGPoint point);
extern CGError SLSTransactionSetWindowLevel(CFTypeRef transaction, uint32_t wid, int level);
extern CGError SLSTransactionSetWindowSubLevel(CFTypeRef transaction, uint32_t wid, int level) __attribute__((weak_import));
extern CGError SLSTransactionOrderWindow(CFTypeRef transaction, uint32_t wid, int order, uint32_t relativeTo);
extern CGError SLSTransactionCommit(CFTypeRef transaction, int synchronous);
// Scales and places a window as the window server draws it, without touching its contents (yabai uses it to animate).
extern CGError SLSTransactionSetWindowTransform(CFTypeRef transaction, uint32_t wid, int unknown, int unknown2, CGAffineTransform transform) __attribute__((weak_import));

// SLSTransactionOrderWindow's order-out mode; ScuttleBorderOrder holds the other two.
enum { OrderOut = 0 };

// JankyBorders window_create: floating (bit 1) and ignores mouse events (bit 9), so clicks
// anywhere in the border window, ring or interior, go to the window below it.
static const uint64_t border_tags = (1ULL << 1) | (1ULL << 9);

static uint32_t create_window(int cid, double scale)
{
    CGRect frame = CGRectMake(0, 0, 1, 1);
    CFTypeRef region = NULL;
    CGSNewRegionWithRect(&frame, &region);
    if (!region) return 0;

    uint32_t wid = 0;
    SLSNewWindow(cid, kCGBackingStoreBuffered, -9999, -9999, region, &wid);
    CFRelease(region);
    if (!wid) return 0;

    uint64_t tags = border_tags;
    SLSSetWindowResolution(cid, wid, scale);
    SLSSetWindowTags(cid, wid, &tags, 64);
    SLSSetWindowOpacity(cid, wid, false);
    SLSWindowSetShadowProperties(wid, (__bridge CFDictionaryRef)@{@"com.apple.WindowShadowDensity": @0});
    return wid;
}

bool scuttle_border_create(ScuttleBorder *border, double scale)
{
    int cid = scuttle_connection();
    *border = (ScuttleBorder){0};
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        border->windows[i] = create_window(cid, scale);
        if (!border->windows[i]) {
            scuttle_border_destroy(border);
            return false;
        }
    }
    return true;
}

// The ring covers the target frame plus `width` on every side.
static CGRect outer_frame(CGRect frame, double width)
{
    return CGRectInset(frame, -width, -width);
}

// CGPathAddRoundedRect needs the radius to fit in the rect.
static double fitted_radius(CGRect rect, double radius)
{
    return MAX(0, MIN(radius, MIN(rect.size.width, rect.size.height) / 2));
}

// Where the ring's pieces go, in points from its top-left corner: the left and the right side, each as wide as the
// outer corners' radius (at least the width) and as tall as the ring, which carry everything curved, then the
// straight runs between them along the top and the bottom, each the border's width thick. A ring too narrow to
// have runs is all one piece, the first.
static void layout_pieces(CGRect pieces[ScuttleBorderEdges], CGSize size, double outerRadius, double width)
{
    double cap = ceil(MAX(width, outerRadius));
    for (int i = 0; i < ScuttleBorderEdges; i++) pieces[i] = CGRectZero;
    if (2 * cap >= size.width) {
        pieces[0] = (CGRect){CGPointZero, size};
        return;
    }
    double across = size.width - 2 * cap;
    pieces[0] = CGRectMake(0, 0, cap, size.height);
    pieces[1] = CGRectMake(size.width - cap, 0, cap, size.height);
    pieces[2] = CGRectMake(cap, 0, across, width);
    pieces[3] = CGRectMake(cap, size.height - width, across, width);
}

// The first two pieces are the sides, which only ever move; the others are runs, which can be stretched.
static bool is_run(int i)
{
    return i >= 2;
}

static bool used(const ScuttleBorder *border, int i)
{
    return !CGRectIsEmpty(border->edges[i]);
}

static CGPoint edge_origin(const ScuttleBorder *border, int i, CGPoint ringOrigin)
{
    return CGPointMake(ringOrigin.x + border->edges[i].origin.x, ringOrigin.y + border->edges[i].origin.y);
}

// Puts a piece where `now` has it, the ring's top-left corner at `ringOrigin`. A run drawn at another length is
// stretched to `now`'s by the window server: its contents are one colour all along, so it needs no redrawing. The
// transform maps the screen to the piece's own points, so it places the piece as well. Only a run that is stretched,
// or was until now, is given one: transforms on every run of every border on every frame, moving windows' too, had
// the window server show more frames on which nothing moved (scripts/anim: `pfreeze`).
static void move_piece(CFTypeRef transaction, ScuttleBorder *border, int i, CGPoint ringOrigin, CGRect now)
{
    CGPoint origin = CGPointMake(ringOrigin.x + now.origin.x, ringOrigin.y + now.origin.y);
    SLSTransactionMoveWindowWithGroup(transaction, border->windows[i], origin);
    if (!is_run(i) || !SLSTransactionSetWindowTransform) return;
    bool stretch = !CGSizeEqualToSize(now.size, border->edges[i].size);
    if (!stretch && !border->stretched[i]) return;
    double sx = now.size.width / border->edges[i].size.width, sy = now.size.height / border->edges[i].size.height;
    CGAffineTransform transform = CGAffineTransformMake(1 / sx, 0, 0, 1 / sy, -origin.x / sx, -origin.y / sy);
    SLSTransactionSetWindowTransform(transaction, border->windows[i], 0, 0, transform);
    border->stretched[i] = stretch;
}

// Gives the runs that are stretched their drawn length back, at once.
static void unstretch(ScuttleBorder *border, CGPoint ringOrigin)
{
    bool any = false;
    for (int i = 0; i < ScuttleBorderEdges; i++) any = any || border->stretched[i];
    if (!any) return;
    CFTypeRef transaction = SLSTransactionCreate(scuttle_connection());
    if (!transaction) return;
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (border->stretched[i]) move_piece(transaction, border, i, ringOrigin, border->edges[i]);
    }
    SLSTransactionCommit(transaction, 1);
    CFRelease(transaction);
}

// Moves, copies the level and sub-level and orders each edge next to the target, in one transaction.
// Unused edges are ordered out. SLSGetWindowSubLevel needs Screen Recording and returns 0 without it
// (JankyBorders 7ba72e5), which is every normal window's sub-level anyway.
static void place(ScuttleBorder *border, uint32_t target, CGPoint origin, ScuttleBorderOrder order, bool synchronous)
{
    int cid = scuttle_connection();
    int64_t level = 0;
    SLSGetWindowLevel(cid, target, &level);
    bool sublevels = SLSGetWindowSubLevel && SLSTransactionSetWindowSubLevel;
    int32_t sublevel = sublevels ? SLSGetWindowSubLevel(cid, target) : 0;

    CFTypeRef transaction = SLSTransactionCreate(cid);
    if (!transaction) return;
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        uint32_t wid = border->windows[i];
        if (!used(border, i)) {
            SLSTransactionOrderWindow(transaction, wid, OrderOut, 0);
            continue;
        }
        move_piece(transaction, border, i, origin, border->edges[i]);
        SLSTransactionSetWindowLevel(transaction, wid, (int)level);
        if (sublevels) SLSTransactionSetWindowSubLevel(transaction, wid, sublevel);
        SLSTransactionOrderWindow(transaction, wid, order, target);
    }
    SLSTransactionCommit(transaction, synchronous);
    CFRelease(transaction);
}

// Draws the edge's part of the ring: the ring between the outer edge and the target's own rounded
// outline, in the ring's top-left coordinates, shifted so the edge's rect fills the window. Everything is
// in points: the context comes scaled to the window's resolution, so the same width and radii are right at
// 1x and 2x. CG contexts put the origin bottom left, so the ring's top-left coordinates are flipped first.
static void draw(uint32_t wid, CGRect edge, CGPathRef ring, ScuttleBorderColor color)
{
    int cid = scuttle_connection();
    CGContextRef context = SLWindowContextCreate(cid, wid, NULL);
    if (!context) return;

    CGContextClearRect(context, (CGRect){CGPointZero, edge.size});
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, 0, edge.size.height);
    CGContextScaleCTM(context, 1, -1);
    CGContextTranslateCTM(context, -edge.origin.x, -edge.origin.y);
    CGContextSetRGBFillColor(context, color.red, color.green, color.blue, color.alpha);
    CGContextAddPath(context, ring);
    CGContextEOFillPath(context);
    CGContextRestoreGState(context);

    CGContextFlush(context);
    CGContextRelease(context);
    SLSFlushWindowContentRegion(cid, wid, NULL);
}

void scuttle_border_update(ScuttleBorder *border, uint32_t target, CGRect frame, int cornerRadius,
                         ScuttleBorderColor color, double width, ScuttleBorderOrder order)
{
    int cid = scuttle_connection();
    CGRect outer = outer_frame(frame, width);
    CGRect bounds = { CGPointZero, outer.size };
    // Keep the inner outline fixed and optically thicken rounded corner midpoints by 5%.
    double outerRadius = fitted_radius(bounds, cornerRadius + width);
    CGPathRef ring = scuttle_border_path(bounds, cornerRadius, width, 0.05);

    // Hold screen updates so the reshaped, redrawn and moved border appears at once. Runs lose their stretch
    // before they are reshaped: see scuttle_border_redraw_shape.
    SLSDisableUpdate(cid);
    unstretch(border, outer.origin);
    layout_pieces(border->edges, outer.size, outerRadius, width);
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (!used(border, i)) continue;
        CGRect shape = { CGPointZero, border->edges[i].size };
        CFTypeRef region = NULL;
        CGSNewRegionWithRect(&shape, &region);
        if (!region) continue;
        CGPoint origin = edge_origin(border, i, outer.origin);
        SLSSetWindowShape(cid, border->windows[i], origin.x, origin.y, region);
        CFRelease(region);
        draw(border->windows[i], border->edges[i], ring, color);
    }
    // Finish placement before screen updates resume; an asynchronous commit can expose
    // the reshaped border at its temporary origin for a frame during a focus redraw.
    place(border, target, outer.origin, order, true);
    SLSReenableUpdate(cid);
    CGPathRelease(ring);
}

void scuttle_border_redraw_shape(ScuttleBorder *border, CGRect frame, int cornerRadius, ScuttleBorderColor color, double width,
                                 bool sizeOnly)
{
    int cid = scuttle_connection();
    CGRect outer = outer_frame(frame, width);
    CGRect bounds = { CGPointZero, outer.size };
    double outerRadius = fitted_radius(bounds, cornerRadius + width);
    CGPathRef ring = scuttle_border_path(bounds, cornerRadius, width, 0.05);
    CGRect before[ScuttleBorderEdges];
    memcpy(before, border->edges, sizeof(before));
    // A piece takes its new shape at once, while a run still has the stretch it was last given: shown like that
    // for a frame, the top of the border was part missing (scripts/anim/sheet.py). So screen updates are held
    // until every piece is placed as drawn, and the runs lose their stretch before they are reshaped, or one twice
    // as long as drawn would be four times as long for a moment. This runs once as a size settles, not on every
    // frame of a resize.
    SLSDisableUpdate(cid);
    unstretch(border, outer.origin);
    layout_pieces(border->edges, outer.size, outerRadius, width);
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (!used(border, i)) continue;
        // A piece of the same size looks the same: a window getting wider keeps its side pieces, which only move.
        if (sizeOnly && CGSizeEqualToSize(before[i].size, border->edges[i].size)) continue;
        CGRect shape = { CGPointZero, border->edges[i].size };
        CFTypeRef region = NULL;
        CGSNewRegionWithRect(&shape, &region);
        if (!region) continue;
        // The shape comes with a position, and the piece is there at once: given the corner of the screen and moved
        // back by the transaction that follows, it showed in the menu bar for a frame of every step of a resize
        // (scripts/anim: `stray`). So it is given the place it belongs.
        CGPoint origin = edge_origin(border, i, outer.origin);
        SLSSetWindowShape(cid, border->windows[i], origin.x, origin.y, region);
        CFRelease(region);
        draw(border->windows[i], border->edges[i], ring, color);
    }
    CFTypeRef transaction = SLSTransactionCreate(cid);
    if (transaction) {
        for (int i = 0; i < ScuttleBorderEdges; i++) {
            if (used(border, i)) move_piece(transaction, border, i, outer.origin, border->edges[i]);
        }
        SLSTransactionCommit(transaction, 1);
        CFRelease(transaction);
    }
    SLSReenableUpdate(cid);
    CGPathRelease(ring);
}

void scuttle_border_recolor(const ScuttleBorder *border, CGRect frame, int cornerRadius, ScuttleBorderColor color, double width)
{
    CGRect outer = outer_frame(frame, width);
    CGRect bounds = { CGPointZero, outer.size };
    CGPathRef ring = scuttle_border_path(bounds, cornerRadius, width, 0.05);
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (used(border, i)) draw(border->windows[i], border->edges[i], ring, color);
    }
    CGPathRelease(ring);
}

bool scuttle_border_fit_sides(ScuttleBorder *border, CGRect frame, int cornerRadius, ScuttleBorderColor color, double width)
{
    int cid = scuttle_connection();
    CGRect outer = outer_frame(frame, width);
    CGRect bounds = { CGPointZero, outer.size };
    CGRect now[ScuttleBorderEdges];
    layout_pieces(now, outer.size, fitted_radius(bounds, cornerRadius + width), width);
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (CGRectIsEmpty(now[i]) != CGRectIsEmpty(border->edges[i])) return false;
    }
    CGPathRef ring = scuttle_border_path(bounds, cornerRadius, width, 0.05);
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (!used(border, i)) continue;
        if (is_run(i)) {
            // Where it belongs in a ring of this height; its length stays as drawn.
            border->edges[i].origin = now[i].origin;
            continue;
        }
        if (CGSizeEqualToSize(now[i].size, border->edges[i].size)) continue;
        border->edges[i] = now[i];
        CGRect shape = { CGPointZero, now[i].size };
        CFTypeRef region = NULL;
        CGSNewRegionWithRect(&shape, &region);
        if (!region) continue;
        // With its place, as in scuttle_border_redraw_shape: a side is never stretched, so it can take its new shape
        // without screen updates held.
        CGPoint origin = edge_origin(border, i, outer.origin);
        SLSSetWindowShape(cid, border->windows[i], origin.x, origin.y, region);
        CFRelease(region);
        draw(border->windows[i], border->edges[i], ring, color);
    }
    CGPathRelease(ring);
    return true;
}

CFTypeRef scuttle_border_transaction_create(void)
{
    return SLSTransactionCreate(scuttle_connection());
}

bool scuttle_border_transaction_follow(CFTypeRef transaction, ScuttleBorder *border, CGRect frame, int cornerRadius, double width)
{
    CGRect outer = outer_frame(frame, width);
    CGRect bounds = { CGPointZero, outer.size };
    CGRect now[ScuttleBorderEdges];
    layout_pieces(now, outer.size, fitted_radius(bounds, cornerRadius + width), width);
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (CGRectIsEmpty(now[i]) != CGRectIsEmpty(border->edges[i])) return false;
        if (CGSizeEqualToSize(now[i].size, border->edges[i].size)) continue;
        // Only a run can be stretched, and only by a window server that has the call.
        if (!is_run(i) || !SLSTransactionSetWindowTransform) return false;
    }
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (used(border, i)) move_piece(transaction, border, i, outer.origin, now[i]);
    }
    return true;
}

// The caller releases the transaction: Swift does, as it follows the Create rule for the one above.
void scuttle_border_transaction_commit(CFTypeRef transaction)
{
    SLSTransactionCommit(transaction, 0);
}

void scuttle_border_move(ScuttleBorder *border, uint32_t target, CGRect frame, double width, ScuttleBorderOrder order)
{
    place(border, target, outer_frame(frame, width).origin, order, false);
}

void scuttle_border_follow(ScuttleBorder *border, CGRect frame, double width)
{
    CFTypeRef transaction = SLSTransactionCreate(scuttle_connection());
    if (!transaction) return;
    CGPoint origin = outer_frame(frame, width).origin;
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (used(border, i)) move_piece(transaction, border, i, origin, border->edges[i]);
    }
    SLSTransactionCommit(transaction, 0);
    CFRelease(transaction);
}

void scuttle_border_move_to_space(const ScuttleBorder *border, uint64_t spaceID)
{
    NSMutableArray *windows = [NSMutableArray arrayWithCapacity:ScuttleBorderEdges];
    for (int i = 0; i < ScuttleBorderEdges; i++) [windows addObject:@(border->windows[i])];
    SLSMoveWindowsToManagedSpace(scuttle_connection(), (__bridge CFArrayRef)windows, spaceID);
}

void scuttle_border_hide(const ScuttleBorder *border)
{
    CFTypeRef transaction = SLSTransactionCreate(scuttle_connection());
    if (!transaction) return;
    for (int i = 0; i < ScuttleBorderEdges; i++) SLSTransactionOrderWindow(transaction, border->windows[i], OrderOut, 0);
    SLSTransactionCommit(transaction, 0);
    CFRelease(transaction);
}

void scuttle_border_destroy(ScuttleBorder *border)
{
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (border->windows[i]) SLSReleaseWindow(scuttle_connection(), border->windows[i]);
    }
    *border = (ScuttleBorder){0};
}

bool scuttle_border_owns(const ScuttleBorder *border, uint32_t windowID)
{
    if (!windowID) return false;
    for (int i = 0; i < ScuttleBorderEdges; i++) {
        if (border->windows[i] == windowID) return true;
    }
    return false;
}

// JankyBorders get_front_window: the front app's first suitable window on a current Space.
uint32_t scuttle_border_focused_window(void)
{
    int owner = scuttle_front_connection();
    if (!owner) return 0;

    // Document-tagged windows of the front app, front to back. A minimized one is never focused.
    int cid = scuttle_connection();
    uint64_t set_tags = 1;
    uint64_t clear_tags = 0;
    NSArray *spaces = scuttle_current_space_ids();
    CFArrayRef windows = SLSCopyWindowsWithOptionsAndTags(cid, owner, (__bridge CFArrayRef)spaces, 0x2, &set_tags, &clear_tags);
    if (!windows) return 0;

    uint32_t focused = 0;
    int count = (int)CFArrayGetCount(windows);
    if (count) {
        CFTypeRef query = SLSWindowQueryWindows(cid, windows, count);
        CFTypeRef iterator = query ? SLSWindowQueryResultCopyWindows(query) : NULL;

        // The iterator yields windows in the input array's order, so the first match is the
        // frontmost. JankyBorders get_front_window relies on the same. Only the normal level counts: a
        // window the app keeps on top, like a browser's picture-in-picture, is tagged as a document too and
        // sits in front of every normal one, but it is never tiled, so focus stays with the window below.
        while (iterator && SLSWindowIteratorAdvance(iterator)) {
            uint32_t wid = SLSWindowIteratorGetWindowID(iterator);
            uint32_t parent = SLSWindowIteratorGetParentID(iterator);
            uint64_t tags = SLSWindowIteratorGetTags(iterator);
            uint64_t attributes = SLSWindowIteratorGetAttributes(iterator);
            if (SLSWindowIteratorGetLevel(iterator) != 0) continue;
            if (scuttle_is_document_kind(parent, tags) && scuttle_is_visible(attributes, tags)) {
                focused = wid;
                break;
            }
        }

        if (iterator) CFRelease(iterator);
        if (query) CFRelease(query);
    }
    CFRelease(windows);
    return focused;
}
