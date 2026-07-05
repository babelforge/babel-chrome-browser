#ifndef BABEL_CHROME_BROWSER_BROWSER_CREATION_SCHEDULER_H_
#define BABEL_CHROME_BROWSER_BROWSER_CREATION_SCHEDULER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserTab;

typedef BabelBrowserTab* (^BabelSelectedTabProvider)(void);
typedef BOOL (^BabelBrowserSchedulerTerminationProvider)(void);
typedef void (^BabelBrowserTabAction)(BabelBrowserTab* tab);
typedef void (^BabelBrowserSchedulerAction)(void);

/**
 * Schedules deferred browser creation and adjacent tab preloading.
 */
@interface BabelBrowserCreationScheduler : NSObject

/**
 * Invalidates pending keyboard-navigation browser creation.
 */
- (void)cancelKeyboardBrowserCreation;

/**
 * Schedules browser creation after keyboard tab navigation has settled.
 *
 * @param tab The tab to create if it is still selected.
 * @param delayNanoseconds The scheduling delay.
 * @param selectedTabProvider The provider for the current selected tab.
 * @param terminationProvider The provider for termination state.
 * @param createHandler The handler that creates the browser.
 * @param preloadHandler The handler that schedules adjacent preloads.
 */
- (void)scheduleKeyboardBrowserCreationForTab:(BabelBrowserTab*)tab
                             delayNanoseconds:(int64_t)delayNanoseconds
                          selectedTabProvider:(BabelSelectedTabProvider)selectedTabProvider
                          terminationProvider:(BabelBrowserSchedulerTerminationProvider)terminationProvider
                                createHandler:(BabelBrowserTabAction)createHandler
                               preloadHandler:(BabelBrowserSchedulerAction)preloadHandler;

/**
 * Schedules adjacent browser preloading.
 *
 * @param tabs The tabs to preload in order.
 * @param anchorTab The selected tab that anchors the preload generation.
 * @param initialDelayNanoseconds The initial delay.
 * @param stepDelayNanoseconds The delay between subsequent preloads.
 * @param selectedTabProvider The provider for the current selected tab.
 * @param terminationProvider The provider for termination state.
 * @param createHandler The handler that creates one browser.
 */
- (void)scheduleAdjacentPreloadForTabs:(NSArray<BabelBrowserTab*>*)tabs
                             anchorTab:(BabelBrowserTab*)anchorTab
               initialDelayNanoseconds:(int64_t)initialDelayNanoseconds
                  stepDelayNanoseconds:(int64_t)stepDelayNanoseconds
                    selectedTabProvider:(BabelSelectedTabProvider)selectedTabProvider
                    terminationProvider:(BabelBrowserSchedulerTerminationProvider)terminationProvider
                          createHandler:(BabelBrowserTabAction)createHandler;

@end

#endif
