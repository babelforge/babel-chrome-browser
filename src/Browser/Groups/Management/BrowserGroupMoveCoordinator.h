#ifndef BABEL_CHROME_BROWSER_GROUP_MOVE_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_GROUP_MOVE_COORDINATOR_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;

/**
 * Moves browser groups inside the ordered group collection.
 */
@interface BabelBrowserGroupMoveCoordinator : NSObject

/**
 * Moves a group to a requested insertion index.
 *
 * @param group The group to move.
 * @param groups The mutable ordered group collection.
 * @param insertionIndex The requested insertion index.
 *
 * @return YES when the group order changed.
 */
- (BOOL)moveGroup:(BabelBrowserGroup*)group
         inGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
 insertionIndex:(NSUInteger)insertionIndex;

@end

#endif
