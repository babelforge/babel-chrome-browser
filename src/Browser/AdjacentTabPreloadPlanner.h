#ifndef BABEL_CHROME_BROWSER_ADJACENT_TAB_PRELOAD_PLANNER_H_
#define BABEL_CHROME_BROWSER_ADJACENT_TAB_PRELOAD_PLANNER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;

/**
 * Plans adjacent tab preloading and live-browser protection.
 */
@interface BabelAdjacentTabPreloadPlanner : NSObject

/**
 * Returns tabs adjacent to an anchor tab.
 *
 * @param tab The anchor tab.
 * @param tabs The visible group tabs.
 *
 * @return The adjacent tabs to preload.
 */
- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab
                                                        tabs:(NSArray<BabelBrowserTab*>*)tabs;

/**
 * Returns identifiers that must not be evicted from live browser memory.
 *
 * @param selectedTab The selected tab.
 * @param adjacentTabs The adjacent tabs planned for preload.
 * @param groups The browser groups to inspect for visible Developer Tools.
 *
 * @return The protected tab identifiers.
 */
- (NSMutableSet<NSString*>*)protectedLiveBrowserTabIdentifiersForSelectedTab:(BabelBrowserTab*)selectedTab
                                                                adjacentTabs:(NSArray<BabelBrowserTab*>*)adjacentTabs
                                                                      groups:(NSArray<BabelBrowserGroup*>*)groups;

@end

#endif
