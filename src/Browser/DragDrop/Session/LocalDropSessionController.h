#ifndef BABEL_CHROME_BROWSER_LOCAL_DROP_SESSION_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_LOCAL_DROP_SESSION_CONTROLLER_H_

#import <Foundation/Foundation.h>

#include "include/cef_browser.h"

@class BabelBrowserTab;
@class BabelLocalDropBridgeScriptBuilder;
@class BabelLocalDropCoordinator;
@class BabelLocalDropLogWriter;
@class BabelLocalDropPayloadBuilder;
@class BabelLocalDropSupportResolver;

typedef BabelBrowserTab* (^BabelLocalDropBrowserTabProvider)(CefRefPtr<CefBrowser> browser);
typedef NSString* (^BabelLocalDropCurrentURLProvider)(CefRefPtr<CefBrowser> browser);

/**
 * Coordinates local file drop support for embedded browser pages.
 */
@interface BabelLocalDropSessionController : NSObject

/**
 * Creates a local drop session controller.
 *
 * @param coordinator The pending drop coordinator.
 * @param bridgeScriptBuilder The JavaScript bridge builder.
 * @param logWriter The local drop log writer.
 * @param payloadBuilder The dropped paths payload builder.
 * @param supportResolver The URL support resolver.
 * @param browserTabProvider The block resolving a CEF browser to a native tab.
 * @param currentURLProvider The block resolving a browser's current URL.
 * @return The initialized controller.
 */
- (instancetype)initWithCoordinator:(BabelLocalDropCoordinator*)coordinator
                bridgeScriptBuilder:(BabelLocalDropBridgeScriptBuilder*)bridgeScriptBuilder
                          logWriter:(BabelLocalDropLogWriter*)logWriter
                     payloadBuilder:(BabelLocalDropPayloadBuilder*)payloadBuilder
                    supportResolver:(BabelLocalDropSupportResolver*)supportResolver
                 browserTabProvider:(BabelLocalDropBrowserTabProvider)browserTabProvider
                 currentURLProvider:(BabelLocalDropCurrentURLProvider)currentURLProvider;

/**
 * Handles drag paths received from CEF.
 *
 * @param paths The dragged local paths.
 * @param browser The browser receiving the drag.
 * @param selectedTab The currently selected tab used as fallback.
 */
- (void)didReceiveLocalDragPaths:(NSArray<NSString*>*)paths
                         browser:(CefRefPtr<CefBrowser>)browser
                     selectedTab:(BabelBrowserTab*)selectedTab;

/**
 * Returns whether a tab accepts local path drops.
 *
 * @param tab The tab to inspect.
 * @return YES when the tab URL belongs to a drop-aware module.
 */
- (BOOL)tabSupportsLocalDropPaths:(BabelBrowserTab*)tab;

/**
 * Installs the drop bridge after a supported page load.
 *
 * @param browser The browser that finished loading.
 */
- (void)browserDidFinishLoading:(CefRefPtr<CefBrowser>)browser;

/**
 * Returns whether a pending local file navigation should be suppressed.
 *
 * @param browser The browser receiving a file navigation.
 * @param selectedTab The currently selected tab used as fallback.
 * @return YES when the navigation belongs to local drop handling.
 */
- (BOOL)shouldSuppressLocalFileNavigationForBrowser:(CefRefPtr<CefBrowser>)browser
                                       selectedTab:(BabelBrowserTab*)selectedTab;

/**
 * Appends a line to the local drop log.
 *
 * @param line The line to append.
 */
- (void)appendLogLine:(NSString*)line;

@end

#endif
