#ifndef BABEL_CHROME_BROWSER_GROUP_LIST_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_GROUP_LIST_COORDINATOR_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserGroup;

/**
 * Coordinates visual layout and simple hit calculations for the group list.
 */
@interface BabelGroupListCoordinator : NSObject

/**
 * Returns the accent color assigned to a group.
 *
 * @param group The group whose accent color is requested.
 * @param groups The ordered group list.
 * @param view The view used for theme color resolution.
 *
 * @return The accent color.
 */
- (NSColor*)accentColorForGroup:(BabelBrowserGroup*)group
                         groups:(NSArray<BabelBrowserGroup*>*)groups
                           view:(NSView*)view;

/**
 * Lays out group selector views in the group list.
 *
 * @param groups The ordered group list.
 * @param groupsListView The list container view.
 * @param collapsed YES when the sidebar is collapsed.
 * @param view The view used for theme color resolution.
 */
- (void)layoutGroups:(NSArray<BabelBrowserGroup*>*)groups
    inGroupsListView:(NSView*)groupsListView
           collapsed:(BOOL)collapsed
                view:(NSView*)view;

/**
 * Computes the insertion index for a group drag Y coordinate.
 *
 * @param y The Y coordinate in group-list coordinates.
 * @param groupCount The number of groups in the list.
 *
 * @return The proposed insertion index.
 */
- (NSUInteger)insertionIndexForListY:(CGFloat)y groupCount:(NSUInteger)groupCount;

@end

#endif
