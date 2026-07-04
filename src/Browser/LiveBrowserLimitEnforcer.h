#ifndef BABEL_CHROME_BROWSER_LIVE_BROWSER_LIMIT_ENFORCER_H_
#define BABEL_CHROME_BROWSER_LIVE_BROWSER_LIMIT_ENFORCER_H_

#import <Foundation/Foundation.h>

@class BabelAdjacentTabPreloadPlanner;
@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelLiveBrowserEvictionPolicy;

typedef void (^BabelLiveBrowserCloseHandler)(BabelBrowserTab* tab);

/**
 * Enforces the maximum number of live page browsers.
 */
@interface BabelLiveBrowserLimitEnforcer : NSObject

/**
 * Creates a live browser limit enforcer.
 *
 * @param adjacentTabPreloadPlanner The planner used to protect adjacent tabs.
 * @param liveBrowserEvictionPolicy The policy used to select evictable tabs.
 * @param maximumLivePageBrowsers The maximum number of live page browsers.
 * @return The initialized live browser limit enforcer.
 */
- (instancetype)initWithAdjacentTabPreloadPlanner:(BabelAdjacentTabPreloadPlanner*)adjacentTabPreloadPlanner
                        liveBrowserEvictionPolicy:(BabelLiveBrowserEvictionPolicy*)liveBrowserEvictionPolicy
                          maximumLivePageBrowsers:(NSUInteger)maximumLivePageBrowsers;

/**
 * Closes evictable browsers until the live browser limit is respected.
 *
 * @param groups The groups containing all tabs.
 * @param selectedTab The currently selected tab.
 * @param visibleTabs The tabs in the currently visible group.
 * @param closeHandler The handler used to close one selected browser.
 */
- (void)enforceLiveBrowserLimitForGroups:(NSArray<BabelBrowserGroup*>*)groups
                             selectedTab:(BabelBrowserTab*)selectedTab
                             visibleTabs:(NSArray<BabelBrowserTab*>*)visibleTabs
                            closeHandler:(BabelLiveBrowserCloseHandler)closeHandler;

@end

#endif
