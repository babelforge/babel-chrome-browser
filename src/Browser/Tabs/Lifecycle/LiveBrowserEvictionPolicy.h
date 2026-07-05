#ifndef BABEL_CHROME_BROWSER_LIVE_BROWSER_EVICTION_POLICY_H_
#define BABEL_CHROME_BROWSER_LIVE_BROWSER_EVICTION_POLICY_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;

/**
 * Tracks live browser usage and selects page browsers that may be evicted.
 */
@interface BabelLiveBrowserEvictionPolicy : NSObject

/**
 * Clears all tracked usage and in-flight eviction state.
 */
- (void)reset;

/**
 * Marks a tab as recently used.
 *
 * @param tab The tab that became recently used.
 */
- (void)touchTab:(BabelBrowserTab*)tab;

/**
 * Removes all usage and eviction state for a tab.
 *
 * @param tab The tab that is being removed.
 */
- (void)removeTab:(BabelBrowserTab*)tab;

/**
 * Marks a tab as being evicted.
 *
 * @param tab The tab whose browser close was requested for eviction.
 */
- (void)markTabEvicting:(BabelBrowserTab*)tab;

/**
 * Clears the in-flight eviction mark for a tab.
 *
 * @param tab The tab whose eviction close has completed.
 */
- (void)unmarkTabEvicting:(BabelBrowserTab*)tab;

/**
 * Returns whether a tab is currently being evicted.
 *
 * @param tab The tab to inspect.
 *
 * @return YES when the tab is being evicted.
 */
- (BOOL)isTabEvicting:(BabelBrowserTab*)tab;

/**
 * Returns live page-browser tabs while excluding tabs already being evicted.
 *
 * @param groups The groups that own browser tabs.
 *
 * @return The live browser tabs.
 */
- (NSArray<BabelBrowserTab*>*)liveBrowserTabsInGroupsExcludingEvictions:
    (NSArray<BabelBrowserGroup*>*)groups;

/**
 * Selects the least recently used tab that is not protected.
 *
 * @param liveTabs The current live browser tabs.
 * @param protectedIdentifiers The tab identifiers that cannot be evicted.
 *
 * @return The tab to evict, or nil when no tab is evictable.
 */
- (BabelBrowserTab*)leastRecentlyUsedEvictableTabFromTabs:(NSArray<BabelBrowserTab*>*)liveTabs
                                     protectedIdentifiers:(NSSet<NSString*>*)protectedIdentifiers;

@end

#endif
