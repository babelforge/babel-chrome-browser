#ifndef BABEL_CHROME_BROWSER_NAVIGATION_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_NAVIGATION_CONTROLLER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserTab;

/**
 * Executes simple CEF navigation commands for browser tabs.
 */
@interface BabelBrowserNavigationController : NSObject

/**
 * Navigates a tab back when possible.
 *
 * @param tab The tab to navigate.
 */
- (void)navigateTabBack:(BabelBrowserTab*)tab;

/**
 * Navigates a tab forward when possible.
 *
 * @param tab The tab to navigate.
 */
- (void)navigateTabForward:(BabelBrowserTab*)tab;

/**
 * Reloads a tab using the normal browser reload command.
 *
 * @param tab The tab to reload.
 */
- (void)reloadTab:(BabelBrowserTab*)tab;

/**
 * Reloads a tab while bypassing HTTP cache.
 *
 * @param tab The tab to reload.
 */
- (void)reloadTabIgnoringCache:(BabelBrowserTab*)tab;

@end

#endif
