#ifndef BABEL_CHROME_BROWSER_GROUP_COLLECTION_H_
#define BABEL_CHROME_BROWSER_GROUP_COLLECTION_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;

/**
 * Provides pure lookup and naming helpers for ordered browser groups.
 */
@interface BabelBrowserGroupCollection : NSObject

/**
 * Returns the group matching an identifier.
 *
 * @param identifier The group identifier.
 * @param groups The ordered groups to inspect.
 * @return The matching group, or nil when none exists.
 */
- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier
                                   groups:(NSArray<BabelBrowserGroup*>*)groups;

/**
 * Returns the group matching a display name.
 *
 * @param name The group name.
 * @param groups The ordered groups to inspect.
 * @return The matching group, or nil when none exists.
 */
- (BabelBrowserGroup*)groupWithName:(NSString*)name
                             groups:(NSArray<BabelBrowserGroup*>*)groups;

/**
 * Returns the next generated manual group name.
 *
 * @param groups The ordered groups to inspect.
 * @return The next available group name.
 */
- (NSString*)nextManualGroupNameForGroups:(NSArray<BabelBrowserGroup*>*)groups;

/**
 * Returns the group that should be selected after deleting a group.
 *
 * @param groupIndex The deleted group index.
 * @param groups The ordered groups before deletion.
 * @return The next group to select, or nil when no safe target exists.
 */
- (BabelBrowserGroup*)groupToSelectAfterDeletingGroupAtIndex:(NSUInteger)groupIndex
                                                      groups:(NSArray<BabelBrowserGroup*>*)groups;

@end

#endif
