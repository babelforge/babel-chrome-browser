#ifndef BABEL_CHROME_BROWSER_PAGE_LIFECYCLE_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_PAGE_LIFECYCLE_CONTROLLER_H_

#import <Foundation/Foundation.h>

#include "include/cef_browser.h"

class BabelBrowserClient;

@class BabelAdjacentTabPreloadPlanner;
@class BabelBrowserCreationScheduler;
@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelLiveBrowserEvictionPolicy;
@class BabelLiveBrowserLimitEnforcer;

typedef NSArray<BabelBrowserTab*>* (^BabelVisibleTabsProvider)(void);
typedef BabelBrowserTab* (^BabelCurrentTabProvider)(void);
typedef BOOL (^BabelBrowserTerminationProvider)(void);

/**
 * Coordinates CEF browser creation, deferred tab activation, preloading, and live browser eviction.
 */
@interface BabelBrowserPageLifecycleController : NSObject

/**
 * Creates a browser page lifecycle controller.
 *
 * @param groups The shared browser groups collection.
 * @param pendingTabs The shared pending tab queue.
 * @param browserClient The CEF browser client used for new browsers.
 * @param creationScheduler The scheduler for deferred browser creation.
 * @param adjacentTabPreloadPlanner The planner for adjacent tab preloading.
 * @param evictionPolicy The policy tracking live browser use.
 * @param liveBrowserLimitEnforcer The service enforcing the live browser limit.
 * @param keyboardDelayNanoseconds The delay used after keyboard tab selection.
 * @param adjacentInitialDelayNanoseconds The initial delay before adjacent tab preload.
 * @param adjacentStepDelayNanoseconds The delay between adjacent tab preloads.
 * @param visibleTabsProvider The provider for tabs visible in the current group.
 * @param selectedTabProvider The provider for the selected tab.
 * @param terminationProvider The provider for termination state.
 * @return The initialized controller.
 */
- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                   pendingTabs:(NSMutableArray<BabelBrowserTab*>*)pendingTabs
                 browserClient:(CefRefPtr<BabelBrowserClient>)browserClient
             creationScheduler:(BabelBrowserCreationScheduler*)creationScheduler
      adjacentTabPreloadPlanner:(BabelAdjacentTabPreloadPlanner*)adjacentTabPreloadPlanner
                evictionPolicy:(BabelLiveBrowserEvictionPolicy*)evictionPolicy
       liveBrowserLimitEnforcer:(BabelLiveBrowserLimitEnforcer*)liveBrowserLimitEnforcer
       keyboardDelayNanoseconds:(int64_t)keyboardDelayNanoseconds
adjacentInitialDelayNanoseconds:(int64_t)adjacentInitialDelayNanoseconds
   adjacentStepDelayNanoseconds:(int64_t)adjacentStepDelayNanoseconds
           visibleTabsProvider:(BabelVisibleTabsProvider)visibleTabsProvider
            selectedTabProvider:(BabelCurrentTabProvider)selectedTabProvider
            terminationProvider:(BabelBrowserTerminationProvider)terminationProvider;

/**
 * Marks the selected restored tab as needing initial browser creation.
 */
- (void)markNeedsInitialRestoredBrowserCreation;

/**
 * Cancels the pending keyboard browser creation timer.
 */
- (void)cancelKeyboardBrowserCreation;

/**
 * Creates a CEF browser for a tab when it is visible and not already live.
 *
 * @param tab The tab to create.
 */
- (void)createBrowserForTabIfNeeded:(BabelBrowserTab*)tab;

/**
 * Schedules browser creation after keyboard tab navigation settles.
 *
 * @param tab The selected tab candidate.
 */
- (void)scheduleBrowserCreationAfterKeyboardNavigationForTab:(BabelBrowserTab*)tab;

/**
 * Creates the first restored browser once the app is ready to show content.
 */
- (void)createInitialRestoredBrowserIfNeeded;

/**
 * Schedules adjacent tab preloading around the selected tab.
 */
- (void)scheduleAdjacentTabPreloadForSelectedTab;

/**
 * Returns tabs adjacent to a tab in the current visible group.
 *
 * @param tab The anchor tab.
 * @return The adjacent tabs to preload.
 */
- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab;

/**
 * Touches a tab in the live browser eviction policy.
 *
 * @param tab The tab to mark as recently used.
 */
- (void)touchRecentlyUsedTab:(BabelBrowserTab*)tab;

/**
 * Closes the CEF browser for a tab while keeping the native tab model.
 *
 * @param tab The tab whose browser should be closed.
 */
- (void)closeBrowserForTabKeepingNativeTab:(BabelBrowserTab*)tab;

/**
 * Enforces the maximum number of live page browsers.
 */
- (void)enforceLivePageBrowserLimit;

/**
 * Resets lifecycle runtime state during app termination.
 */
- (void)reset;

@end

#endif
