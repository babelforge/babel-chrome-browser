#ifndef BABEL_CHROME_BROWSER_WINDOW_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_WINDOW_CONTROLLER_H_

#import <Cocoa/Cocoa.h>

#include "include/cef_browser.h"

/**
 * Owns the main BabelChrome window, split view, tabs, and embedded CEF browsers.
 */
@interface BabelBrowserWindowController : NSWindowController <NSWindowDelegate, NSTextFieldDelegate>

/**
 * Creates the main browser window controller.
 *
 * @return The initialized window controller.
 */
- (instancetype)init;

/**
 * Opens one or more URLs in new tabs.
 *
 * @param urls The URLs to open. An empty list opens the default page.
 */
- (void)openURLs:(NSArray<NSURL*>*)urls;

/**
 * Opens a new tab using the default page.
 */
- (void)openNewTab;

/**
 * Opens a new tab next to the selected tab using the default page.
 */
- (void)openAdjacentNewTab;

/**
 * Closes the selected tab in the active group.
 */
- (void)closeSelectedTab;

/**
 * Reopens the most recently closed tab.
 */
- (void)reopenLastClosedTab;

/**
 * Selects the next tab in the active group.
 */
- (void)selectNextTab;

/**
 * Selects the previous tab in the active group.
 */
- (void)selectPreviousTab;

/**
 * Opens a URL in a new tab in the active group.
 *
 * @param urlString The URL string to open.
 */
- (void)openURLStringInNewTab:(NSString*)urlString;

/**
 * Opens a URL in a new tab parented by the tab that owns a browser.
 *
 * @param urlString The URL string to open.
 * @param browser The browser that requested the new tab.
 */
- (void)openURLStringInNewTab:(NSString*)urlString openerBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Receives local file paths observed during a browser drag.
 *
 * @param paths The absolute local paths.
 * @param browser The browser receiving the drag.
 */
- (void)browser:(CefRefPtr<CefBrowser>)browser didReceiveLocalDragPaths:(NSArray<NSString*>*)paths;

/**
 * Installs page-level local drop handling when the browser supports it.
 *
 * @param browser The browser that finished loading.
 */
- (void)browserDidFinishLoading:(CefRefPtr<CefBrowser>)browser;

/**
 * Reports whether a file navigation should be suppressed for a drop-aware page.
 *
 * @param browser The browser receiving the navigation.
 * @return YES when BabelChrome should suppress the navigation.
 */
- (BOOL)shouldSuppressLocalFileNavigationForBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Opens developer tools for the active tab.
 */
- (void)openDeveloperToolsForSelectedTab;

/**
 * Opens developer tools for a browser.
 *
 * @param browser The browser to inspect.
 * @param x The inspected x coordinate.
 * @param y The inspected y coordinate.
 */
- (void)openDeveloperToolsForBrowser:(CefRefPtr<CefBrowser>)browser x:(int)x y:(int)y;

/**
 * Reports whether developer tools may be opened for the active tab.
 *
 * @return YES when the active tab exists and does not already show developer tools.
 */
- (BOOL)canOpenDeveloperToolsForSelectedTab;

/**
 * Reports whether developer tools may be opened for a browser.
 *
 * @param browser The browser to inspect.
 * @return YES when the browser has a native tab without visible developer tools.
 */
- (BOOL)canOpenDeveloperToolsForBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Reports whether the browser shows a local viewer source.
 *
 * @param browser The browser to inspect.
 * @return YES when the browser is backed by a local viewer file.
 */
- (BOOL)canOpenViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Opens the local viewer source file for a browser.
 *
 * @param browser The browser backed by the source file.
 */
- (void)openViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Reveals the local viewer source file for a browser in Finder.
 *
 * @param browser The browser backed by the source file.
 */
- (void)revealViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Navigates the active tab back if possible.
 */
- (void)navigateSelectedTabBack;

/**
 * Navigates the active tab forward if possible.
 */
- (void)navigateSelectedTabForward;

/**
 * Reloads the active tab if its browser exists.
 */
- (void)reloadSelectedTab;

/**
 * Reloads the active tab after clearing HTTP cache for its request context.
 */
- (void)reloadSelectedTabIgnoringCache;

/**
 * Opens the BabelChrome history page.
 */
- (void)openHistoryPage;

/**
 * Opens the BabelChrome settings page.
 */
- (void)openSettingsPage;

/**
 * Opens the BabelChrome extensions page.
 */
- (void)openExtensionsPage;

/**
 * Handles a BabelChrome internal navigation requested by an embedded browser.
 *
 * @param urlString The requested URL string.
 * @return YES when BabelChrome handled the navigation.
 */
- (BOOL)handleInternalNavigationURLString:(NSString*)urlString;

/**
 * Handles a BabelChrome internal navigation requested by a known embedded browser.
 *
 * @param urlString The requested URL string.
 * @param browser The browser that requested the navigation.
 * @return YES when BabelChrome handled the navigation.
 */
- (BOOL)handleInternalNavigationURLString:(NSString*)urlString browser:(CefRefPtr<CefBrowser>)browser;

/**
 * Shows the window and brings the app forward.
 */
- (void)showMainWindow;

/**
 * Attaches a newly created CEF browser to the pending native tab.
 *
 * @param browser The created browser.
 */
- (void)attachCreatedBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Detaches a closed CEF browser from its native tab.
 *
 * @param browser The closed browser.
 */
- (void)detachClosedBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Reports whether a CEF browser close may propagate to the native parent window.
 *
 * @return YES only while BabelChrome is terminating.
 */
- (BOOL)shouldPropagateBrowserClose;

/**
 * Updates the tab title for a browser.
 *
 * @param browser The browser whose title changed.
 * @param title The new title.
 */
- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title;

/**
 * Updates the visible address for a browser.
 *
 * @param browser The browser whose address changed.
 * @param urlString The new URL string.
 */
- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString;

/**
 * Updates the hovered-link status text for a browser.
 *
 * @param browser The browser whose status changed.
 * @param statusText The status text to display, or an empty string to hide it.
 */
- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText;

/**
 * Updates the favicon image for a browser.
 *
 * @param browser The browser whose favicon changed.
 * @param faviconImage The new favicon image.
 */
- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage;

/**
 * Copies a URL string to the system pasteboard.
 *
 * @param urlString The URL string to copy.
 */
- (void)copyURLStringToPasteboard:(NSString*)urlString;

/**
 * Requests application shutdown and closes every embedded browser.
 */
- (void)requestApplicationTermination;

@end

#endif
