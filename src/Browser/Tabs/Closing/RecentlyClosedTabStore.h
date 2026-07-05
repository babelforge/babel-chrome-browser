#ifndef BABEL_CHROME_BROWSER_RECENTLY_CLOSED_TAB_STORE_H_
#define BABEL_CHROME_BROWSER_RECENTLY_CLOSED_TAB_STORE_H_

#import <Foundation/Foundation.h>

@class BabelClosedTab;
@class BabelBrowserGroup;
@class BabelBrowserTab;

/**
 * Owns the in-memory stack of recently closed tabs.
 */
@interface BabelRecentlyClosedTabStore : NSObject

/**
 * Returns the number of recently closed tabs.
 *
 * @return The number of recently closed tabs.
 */
- (NSUInteger)count;

/**
 * Returns all recently closed tabs in insertion order.
 *
 * @return The recently closed tabs.
 */
- (NSArray<BabelClosedTab*>*)allClosedTabs;

/**
 * Adds a closed tab to the top of the stack.
 *
 * @param closedTab The closed tab snapshot to store.
 */
- (void)pushClosedTab:(BabelClosedTab*)closedTab;

/**
 * Captures and stores a closed tab snapshot.
 *
 * @param tab The tab being closed.
 * @param group The group that contained the tab.
 * @param defaultGroupName The fallback group name used when the source group has no name.
 */
- (void)pushTab:(BabelBrowserTab*)tab
      fromGroup:(BabelBrowserGroup*)group
defaultGroupName:(NSString*)defaultGroupName;

/**
 * Removes and returns a closed tab at the provided index.
 *
 * @param index The index to remove.
 * @return The removed closed tab, or nil when the index is invalid.
 */
- (BabelClosedTab*)popClosedTabAtIndex:(NSUInteger)index;

@end

#endif
