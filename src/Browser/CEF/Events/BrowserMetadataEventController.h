#ifndef BABEL_CHROME_BROWSER_METADATA_EVENT_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_METADATA_EVENT_CONTROLLER_H_

#import <Cocoa/Cocoa.h>

#include "include/cef_browser.h"

@class BabelBrowserPasteboardWriter;
@class BabelBrowserTab;
@class BabelBrowserTabMetadataUpdater;
@class BabelFaviconStore;
@class BabelLinkStatusBarController;
@class BabelRuntimeRefreshCoordinator;

typedef BabelBrowserTab* (^BabelMetadataBrowserTabProvider)(CefRefPtr<CefBrowser> browser);
typedef BabelBrowserTab* (^BabelMetadataSelectedTabProvider)(void);
typedef NSString* (^BabelMetadataStringForTabProvider)(BabelBrowserTab* tab);
typedef NSArray<NSString*>* (^BabelMetadataStringArrayProvider)(NSString* urlString);
typedef BOOL (^BabelMetadataStringPredicate)(NSString* urlString);
typedef NSString* (^BabelMetadataStringTransform)(NSString* value);
typedef void (^BabelMetadataTabHandler)(BabelBrowserTab* tab);
typedef void (^BabelMetadataURLRefreshHandler)(NSArray<NSString*>* requestedURLStrings, BabelBrowserTab* excludedTab);
typedef void (^BabelMetadataVoidHandler)(void);

/**
 * Coordinates browser metadata callbacks into native tab state and visible UI.
 */
@interface BabelBrowserMetadataEventController : NSObject

/**
 * Creates a browser metadata event controller.
 *
 * @param metadataUpdater The tab metadata updater.
 * @param faviconStore The favicon persistence store.
 * @param runtimeRefreshCoordinator The runtime refresh coordinator.
 * @param linkStatusBarController The link status bar controller.
 * @param pasteboardWriter The system pasteboard writer.
 * @param browserTabProvider The provider mapping CEF browsers to tabs.
 * @param selectedTabProvider The provider for the selected tab.
 * @param compactTitleBlock The title compaction block.
 * @param stableServerPredicate The predicate for stable server URLs.
 * @param stableURLPredicate The predicate for stable BabelChrome URLs.
 * @param localServiceRuntimePredicate The predicate for tokenized module runtime URLs.
 * @param localServiceModulePredicate The predicate for tokenized module route URLs.
 * @param stableServerReloadURLProvider The stable server reload URL provider.
 * @param refreshURLStringsProvider The stable URL refresh provider.
 * @param reloadRequestedURLStringsHandler The callback used to reload matching tabs.
 * @param saveStateHandler The callback used to persist native state.
 * @param updateWindowTitleHandler The callback used after selected-tab title changes.
 * @param updateAddressBarHandler The callback used after selected-tab URL changes.
 * @param addressFieldEditingProvider The provider for address field edit state.
 * @param statusBarView The link status bar view.
 * @param statusLabel The link status label.
 * @param rightView The right content view.
 * @param pagesPanel The pages panel.
 * @return The initialized controller.
 */
- (instancetype)initWithMetadataUpdater:(BabelBrowserTabMetadataUpdater*)metadataUpdater
                            faviconStore:(BabelFaviconStore*)faviconStore
               runtimeRefreshCoordinator:(BabelRuntimeRefreshCoordinator*)runtimeRefreshCoordinator
                  linkStatusBarController:(BabelLinkStatusBarController*)linkStatusBarController
                         pasteboardWriter:(BabelBrowserPasteboardWriter*)pasteboardWriter
                       browserTabProvider:(BabelMetadataBrowserTabProvider)browserTabProvider
                      selectedTabProvider:(BabelMetadataSelectedTabProvider)selectedTabProvider
                        compactTitleBlock:(BabelMetadataStringTransform)compactTitleBlock
                    stableServerPredicate:(BabelMetadataStringPredicate)stableServerPredicate
                       stableURLPredicate:(BabelMetadataStringPredicate)stableURLPredicate
             localServiceRuntimePredicate:(BabelMetadataStringPredicate)localServiceRuntimePredicate
              localServiceModulePredicate:(BabelMetadataStringPredicate)localServiceModulePredicate
            stableServerReloadURLProvider:(BabelMetadataStringForTabProvider)stableServerReloadURLProvider
                refreshURLStringsProvider:(BabelMetadataStringArrayProvider)refreshURLStringsProvider
         reloadRequestedURLStringsHandler:(BabelMetadataURLRefreshHandler)reloadRequestedURLStringsHandler
                         saveStateHandler:(BabelMetadataVoidHandler)saveStateHandler
                 updateWindowTitleHandler:(BabelMetadataVoidHandler)updateWindowTitleHandler
                  updateAddressBarHandler:(BabelMetadataTabHandler)updateAddressBarHandler
              addressFieldEditingProvider:(BOOL (^)(void))addressFieldEditingProvider
                            statusBarView:(NSView*)statusBarView
                              statusLabel:(NSTextField*)statusLabel
                                rightView:(NSView*)rightView
                               pagesPanel:(NSView*)pagesPanel;

/**
 * Handles a browser title update.
 *
 * @param browser The source browser.
 * @param title The received title.
 */
- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title;

/**
 * Handles a browser URL update.
 *
 * @param browser The source browser.
 * @param urlString The received URL string.
 */
- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString;

/**
 * Handles a browser status text update.
 *
 * @param browser The source browser.
 * @param statusText The received status text.
 */
- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText;

/**
 * Handles a browser favicon update.
 *
 * @param browser The source browser.
 * @param faviconImage The received favicon image.
 */
- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage;

/**
 * Copies a URL string to the pasteboard.
 *
 * @param urlString The URL string to copy.
 */
- (void)copyURLStringToPasteboard:(NSString*)urlString;

@end

#endif
