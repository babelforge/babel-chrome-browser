#ifndef BABEL_CHROME_BROWSER_GROUP_MANAGER_H_
#define BABEL_CHROME_BROWSER_GROUP_MANAGER_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserGroup;
@class BabelBrowserGroupCollection;
@class BabelBrowserGroupFactory;

typedef void (^BabelBrowserGroupLayoutHandler)(void);

/**
 * Manages creation and lookup of browser groups.
 */
@interface BabelBrowserGroupManager : NSObject

/**
 * Creates a browser group manager.
 *
 * @param groups The mutable group list.
 * @param groupsListView The view receiving group item views.
 * @param groupCollection The group collection helper.
 * @param groupFactory The factory used to create groups.
 * @param defaultGroupIdentifier The stable default group identifier.
 * @param defaultGroupName The default group name.
 * @param layoutHandler The callback used after group view changes.
 * @return The initialized manager.
 */
- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                groupsListView:(NSView*)groupsListView
               groupCollection:(BabelBrowserGroupCollection*)groupCollection
                  groupFactory:(BabelBrowserGroupFactory*)groupFactory
        defaultGroupIdentifier:(NSString*)defaultGroupIdentifier
              defaultGroupName:(NSString*)defaultGroupName
                 layoutHandler:(BabelBrowserGroupLayoutHandler)layoutHandler;

/**
 * Creates a group unless a group with the identifier already exists.
 *
 * @param name The group name.
 * @param identifier The group identifier.
 * @return The existing or created group.
 */
- (BabelBrowserGroup*)createGroupWithName:(NSString*)name identifier:(NSString*)identifier;

/**
 * Finds a group by identifier.
 *
 * @param identifier The group identifier.
 * @return The matching group, or nil.
 */
- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier;

/**
 * Finds a group by name.
 *
 * @param name The group name.
 * @return The matching group, or nil.
 */
- (BabelBrowserGroup*)groupWithName:(NSString*)name;

/**
 * Ensures a group with a name exists.
 *
 * @param name The group name.
 * @return The existing or created group.
 */
- (BabelBrowserGroup*)ensureGroupNamed:(NSString*)name;

/**
 * Builds the next manual group name.
 *
 * @return The next manual group name.
 */
- (NSString*)nextManualGroupName;

@end

#endif
