#ifndef BABEL_CHROME_BROWSER_LINK_STATUS_BAR_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_LINK_STATUS_BAR_CONTROLLER_H_

#import <AppKit/AppKit.h>

@class BabelBrowserTab;

/**
 * Presents the link-hover status bar inside the main browser window.
 */
@interface BabelLinkStatusBarController : NSObject

/**
 * Hides the status bar view.
 *
 * @param statusBarView The status bar view to hide.
 */
- (void)hideStatusBar:(NSView*)statusBarView;

/**
 * Updates the status bar for the current CEF status text.
 *
 * @param statusText The CEF status text.
 * @param tab The tab that emitted the status text.
 * @param selectedTab The currently selected tab.
 * @param statusBarView The status bar container view.
 * @param statusLabel The status text label.
 * @param rightView The right-side application container.
 * @param pagesPanel The pages panel used as the z-order reference.
 */
- (void)updateStatusText:(NSString*)statusText
                  forTab:(BabelBrowserTab*)tab
             selectedTab:(BabelBrowserTab*)selectedTab
           statusBarView:(NSView*)statusBarView
             statusLabel:(NSTextField*)statusLabel
               rightView:(NSView*)rightView
              pagesPanel:(NSView*)pagesPanel;

@end

#endif
