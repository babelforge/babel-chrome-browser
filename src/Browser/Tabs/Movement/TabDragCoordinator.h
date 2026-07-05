#ifndef BABEL_CHROME_BROWSER_TAB_DRAG_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_TAB_DRAG_COORDINATOR_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;

/**
 * Provides tab drag-and-drop hit testing and index calculations.
 */
@interface BabelTabDragCoordinator : NSObject

/**
 * Returns the group under a point expressed in group-list coordinates.
 *
 * @param listPoint The point in the group list coordinate space.
 * @param groups The ordered group list.
 * @param groupsListBounds The group list bounds.
 *
 * @return The group under the point, or nil.
 */
- (BabelBrowserGroup*)groupAtListPoint:(NSPoint)listPoint
                                groups:(NSArray<BabelBrowserGroup*>*)groups
                      groupsListBounds:(NSRect)groupsListBounds;

/**
 * Computes the insertion index for a tab strip X coordinate.
 *
 * @param x The X coordinate in tab-strip coordinates.
 * @param tabs The ordered visible tabs.
 *
 * @return The insertion index.
 */
- (NSUInteger)insertionIndexForTabStripX:(CGFloat)x tabs:(NSArray<BabelBrowserTab*>*)tabs;

/**
 * Adjusts a proposed insertion index when moving an item already in the same array.
 *
 * @param currentIndex The current item index.
 * @param insertionIndex The proposed insertion index.
 * @param itemCount The item count before the move.
 *
 * @return The adjusted target index.
 */
- (NSUInteger)targetIndexForMovingItemAtIndex:(NSUInteger)currentIndex
                             toInsertionIndex:(NSUInteger)insertionIndex
                                    itemCount:(NSUInteger)itemCount;

@end

#endif
