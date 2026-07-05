#import "Browser/BrowserMetadataEventController.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserPasteboardWriter.h"
#import "Browser/BrowserTabMetadataUpdater.h"
#import "Browser/FaviconStore.h"
#import "Browser/LinkStatusBarController.h"
#import "Browser/RuntimeRefreshCoordinator.h"

@implementation BabelBrowserMetadataEventController {
  BabelBrowserTabMetadataUpdater* metadataUpdater_;
  BabelFaviconStore* faviconStore_;
  BabelRuntimeRefreshCoordinator* runtimeRefreshCoordinator_;
  BabelLinkStatusBarController* linkStatusBarController_;
  BabelBrowserPasteboardWriter* pasteboardWriter_;
  BabelMetadataBrowserTabProvider browserTabProvider_;
  BabelMetadataSelectedTabProvider selectedTabProvider_;
  BabelMetadataStringTransform compactTitleBlock_;
  BabelMetadataStringPredicate stableServerPredicate_;
  BabelMetadataStringPredicate stableURLPredicate_;
  BabelMetadataStringPredicate localServiceRuntimePredicate_;
  BabelMetadataStringPredicate localServiceModulePredicate_;
  BabelMetadataStringForTabProvider stableServerReloadURLProvider_;
  BabelMetadataStringArrayProvider refreshURLStringsProvider_;
  BabelMetadataURLRefreshHandler reloadRequestedURLStringsHandler_;
  BabelMetadataVoidHandler saveStateHandler_;
  BabelMetadataVoidHandler updateWindowTitleHandler_;
  BabelMetadataTabHandler updateAddressBarHandler_;
  BOOL (^addressFieldEditingProvider_)(void);
  __weak NSView* statusBarView_;
  __weak NSTextField* statusLabel_;
  __weak NSView* rightView_;
  __weak NSView* pagesPanel_;
}

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
                               pagesPanel:(NSView*)pagesPanel {
  self = [super init];
  if (self) {
    metadataUpdater_ = metadataUpdater;
    faviconStore_ = faviconStore;
    runtimeRefreshCoordinator_ = runtimeRefreshCoordinator;
    linkStatusBarController_ = linkStatusBarController;
    pasteboardWriter_ = pasteboardWriter;
    browserTabProvider_ = [browserTabProvider copy];
    selectedTabProvider_ = [selectedTabProvider copy];
    compactTitleBlock_ = [compactTitleBlock copy];
    stableServerPredicate_ = [stableServerPredicate copy];
    stableURLPredicate_ = [stableURLPredicate copy];
    localServiceRuntimePredicate_ = [localServiceRuntimePredicate copy];
    localServiceModulePredicate_ = [localServiceModulePredicate copy];
    stableServerReloadURLProvider_ = [stableServerReloadURLProvider copy];
    refreshURLStringsProvider_ = [refreshURLStringsProvider copy];
    reloadRequestedURLStringsHandler_ = [reloadRequestedURLStringsHandler copy];
    saveStateHandler_ = [saveStateHandler copy];
    updateWindowTitleHandler_ = [updateWindowTitleHandler copy];
    updateAddressBarHandler_ = [updateAddressBarHandler copy];
    addressFieldEditingProvider_ = [addressFieldEditingProvider copy];
    statusBarView_ = statusBarView;
    statusLabel_ = statusLabel;
    rightView_ = rightView;
    pagesPanel_ = pagesPanel;
  }
  return self;
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (![metadataUpdater_ updateTab:tab
                         withTitle:title
                 compactTitleBlock:^NSString*(NSString* value) {
                   return compactTitleBlock_ ? compactTitleBlock_(value) : value;
                 }]) {
    return;
  }
  if (saveStateHandler_) {
    saveStateHandler_();
  }
  if (tab == [self selectedTab] && updateWindowTitleHandler_) {
    updateWindowTitleHandler_();
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  if (!tab || [urlString hasPrefix:@"data:"]) {
    return;
  }

  tab.urlString = urlString;
  if (stableServerPredicate_ && stableServerPredicate_(tab.requestedURLString)) {
    tab.requestedURLString = stableServerReloadURLProvider_ ? stableServerReloadURLProvider_(tab) : tab.requestedURLString;
  } else if (!(stableURLPredicate_ && stableURLPredicate_(tab.requestedURLString)) ||
             !(localServiceRuntimePredicate_ && localServiceRuntimePredicate_(urlString))) {
    tab.requestedURLString = urlString;
  }
  if (!(localServiceModulePredicate_ && localServiceModulePredicate_(urlString))) {
    NSArray<NSString*>* pendingRefreshURLStrings =
        [runtimeRefreshCoordinator_ consumeRefreshURLStringsForBrowserIdentifier:[tab browser]->GetIdentifier()];
    if (pendingRefreshURLStrings.count > 0 && reloadRequestedURLStringsHandler_) {
      reloadRequestedURLStringsHandler_(pendingRefreshURLStrings, tab);
    }
  }
  NSArray<NSString*>* directRefreshURLStrings =
      refreshURLStringsProvider_ ? refreshURLStringsProvider_(urlString) : @[];
  if (directRefreshURLStrings.count > 0 && reloadRequestedURLStringsHandler_) {
    reloadRequestedURLStringsHandler_(directRefreshURLStrings, tab);
  }
  if (saveStateHandler_) {
    saveStateHandler_();
  }
  BOOL addressFieldEditing = addressFieldEditingProvider_ ? addressFieldEditingProvider_() : NO;
  if (tab == [self selectedTab] && !addressFieldEditing && updateAddressBarHandler_) {
    updateAddressBarHandler_(tab);
  }
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  [linkStatusBarController_ updateStatusText:statusText
                                      forTab:tab
                                 selectedTab:[self selectedTab]
                               statusBarView:statusBarView_
                                 statusLabel:statusLabel_
                                   rightView:rightView_
                                  pagesPanel:pagesPanel_];
}

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage {
  BabelBrowserTab* tab = [self tabForBrowser:browser];
  [metadataUpdater_ updateTab:tab
             withFaviconImage:faviconImage
                 faviconStore:faviconStore_];
}

- (void)copyURLStringToPasteboard:(NSString*)urlString {
  [pasteboardWriter_ copyURLStringToPasteboard:urlString];
}

- (BabelBrowserTab*)tabForBrowser:(CefRefPtr<CefBrowser>)browser {
  return browserTabProvider_ ? browserTabProvider_(browser) : nil;
}

- (BabelBrowserTab*)selectedTab {
  return selectedTabProvider_ ? selectedTabProvider_() : nil;
}

@end
