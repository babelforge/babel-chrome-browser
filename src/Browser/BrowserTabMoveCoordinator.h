#ifndef BABEL_CHROME_BROWSER_TAB_MOVE_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_TAB_MOVE_COORDINATOR_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelTabDragCoordinator;

/**
 * Describes the outcome of a tab move operation.
 */
@interface BabelBrowserTabMoveResult : NSObject

@property(nonatomic, assign) BOOL didMove;
@property(nonatomic, assign) BOOL movedAcrossGroups;

@end

/**
 * Moves existing tabs within or across browser groups.
 */
@interface BabelBrowserTabMoveCoordinator : NSObject

/**
 * Initializes the move coordinator.
 *
 * @param dragCoordinator The drag coordinator used to adjust same-group insertion indexes.
 * @return The initialized coordinator.
 */
- (instancetype)initWithDragCoordinator:(BabelTabDragCoordinator*)dragCoordinator;

/**
 * Moves a tab from one group to another group.
 *
 * @param tab The tab to move.
 * @param sourceGroup The source group.
 * @param destinationGroup The destination group.
 * @param insertionIndex The requested insertion index in the destination group.
 * @return The move result.
 */
- (BabelBrowserTabMoveResult*)moveTab:(BabelBrowserTab*)tab
                            fromGroup:(BabelBrowserGroup*)sourceGroup
                              toGroup:(BabelBrowserGroup*)destinationGroup
                        insertionIndex:(NSUInteger)insertionIndex;

@end

#endif
