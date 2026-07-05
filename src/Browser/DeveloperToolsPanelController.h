#ifndef BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_PANEL_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_PANEL_CONTROLLER_H_

#import <Cocoa/Cocoa.h>

#include "include/cef_browser.h"

@class BabelBrowserTab;
@class BabelDeveloperToolsLayoutCalculator;
@class BabelDeveloperToolsTargetResolver;

typedef BabelBrowserTab* (^BabelDeveloperToolsBrowserLookupBlock)(CefRefPtr<CefBrowser> browser);
typedef void (^BabelDeveloperToolsCreateBrowserBlock)(BabelBrowserTab* tab, NSString* urlString);

/**
 * Coordinates embedded Developer Tools browsers and their native AppKit panel.
 */
@interface BabelDeveloperToolsPanelController : NSObject

/**
 * Creates a Developer Tools panel controller.
 *
 * @param targetResolver The resolver used to find the DevTools frontend URL.
 * @param layoutCalculator The calculator used to layout the embedded panel.
 * @param browserLookupBlock The block used to verify that an inspected browser is still attached.
 * @param createBrowserBlock The block used to create a CEF browser for DevTools.
 * @param toolbarHeight The DevTools toolbar height.
 * @param resizeHandleThickness The resize handle thickness.
 * @return The initialized panel controller.
 */
- (instancetype)initWithTargetResolver:(BabelDeveloperToolsTargetResolver*)targetResolver
                      layoutCalculator:(BabelDeveloperToolsLayoutCalculator*)layoutCalculator
                    browserLookupBlock:(BabelDeveloperToolsBrowserLookupBlock)browserLookupBlock
                    createBrowserBlock:(BabelDeveloperToolsCreateBrowserBlock)createBrowserBlock
                         toolbarHeight:(CGFloat)toolbarHeight
                 resizeHandleThickness:(CGFloat)resizeHandleThickness;

/**
 * Loads DevTools for an inspected browser into a tab.
 *
 * @param tab The tab that owns the DevTools panel.
 * @param browser The inspected browser.
 * @param port The CEF remote debugging port.
 */
- (void)loadDeveloperToolsForTab:(BabelBrowserTab*)tab
               inspectingBrowser:(CefRefPtr<CefBrowser>)browser
                            port:(int)port;

/**
 * Hides an embedded DevTools panel without closing the inspected tab.
 *
 * @param tab The tab whose DevTools panel should be hidden.
 * @param pagesPanel The pages panel used to calculate frames.
 * @param dockMode The current dock mode.
 * @param sizeRatio The current panel size ratio.
 */
- (void)hideDeveloperToolsForTab:(BabelBrowserTab*)tab
                      pagesPanel:(NSView*)pagesPanel
                        dockMode:(NSString*)dockMode
                       sizeRatio:(CGFloat)sizeRatio;

/**
 * Closes an embedded DevTools browser and hides its panel.
 *
 * @param tab The tab whose DevTools panel should close.
 * @param pagesPanel The pages panel used to calculate frames.
 * @param dockMode The current dock mode.
 * @param sizeRatio The current panel size ratio.
 */
- (void)closeDeveloperToolsForTab:(BabelBrowserTab*)tab
                       pagesPanel:(NSView*)pagesPanel
                         dockMode:(NSString*)dockMode
                        sizeRatio:(CGFloat)sizeRatio;

/**
 * Moves a newly created popup DevTools browser into the tab's embedded panel.
 *
 * @param browser The DevTools browser.
 * @param tab The tab receiving the DevTools browser view.
 * @param ownerWindow The main BabelChrome window.
 */
- (void)reparentDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              intoTab:(BabelBrowserTab*)tab
                          ownerWindow:(NSWindow*)ownerWindow;

/**
 * Lays out one tab page and its optional DevTools panel.
 *
 * @param tab The tab to layout.
 * @param pagesPanel The pages panel containing the tab.
 * @param dockMode The current dock mode.
 * @param sizeRatio The current panel size ratio.
 */
- (void)layoutBrowserViewsForTab:(BabelBrowserTab*)tab
                      pagesPanel:(NSView*)pagesPanel
                        dockMode:(NSString*)dockMode
                       sizeRatio:(CGFloat)sizeRatio;

@end

#endif
