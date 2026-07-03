#ifndef BABEL_CHROME_BROWSER_TAB_COLLECTION_H_
#define BABEL_CHROME_BROWSER_TAB_COLLECTION_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;

/**
 * Provides pure lookup and indexing helpers for browser tabs.
 */
@interface BabelBrowserTabCollection : NSObject

/**
 * Returns the tab matching an identifier inside one group.
 *
 * @param identifier The tab identifier.
 * @param group The group to inspect.
 * @return The matching tab, or nil when none exists.
 */
- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier
                              inGroup:(BabelBrowserGroup*)group;

/**
 * Returns the tab matching an identifier across ordered groups.
 *
 * @param identifier The tab identifier.
 * @param groups The ordered groups to inspect.
 * @return The matching tab, or nil when none exists.
 */
- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier
                               groups:(NSArray<BabelBrowserGroup*>*)groups;

/**
 * Returns the group that contains a tab.
 *
 * @param tab The tab to locate.
 * @param groups The ordered groups to inspect.
 * @return The containing group, or nil when none exists.
 */
- (BabelBrowserGroup*)groupContainingTab:(BabelBrowserTab*)tab
                                  groups:(NSArray<BabelBrowserGroup*>*)groups;

/**
 * Returns the ordered identifiers for all tabs in a group.
 *
 * @param group The group to inspect.
 * @return The ordered tab identifiers.
 */
- (NSArray<NSString*>*)tabIdentifiersForGroup:(BabelBrowserGroup*)group;

/**
 * Returns parent identifiers keyed by tab identifier for one group.
 *
 * @param group The group to inspect.
 * @return Parent identifiers keyed by child tab identifier.
 */
- (NSDictionary<NSString*, NSString*>*)parentIdentifiersByTabIdentifierForGroup:(BabelBrowserGroup*)group;

@end

#endif
