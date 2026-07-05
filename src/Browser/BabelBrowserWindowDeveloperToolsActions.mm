#import "Browser/BabelBrowserWindowDeveloperToolsActions.h"

#import "Browser/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowDeveloperToolsActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (void)loadDeveloperToolsForTab:(BabelBrowserTab*)tab
                inspectingBrowser:(CefRefPtr<CefBrowser>)browser {
  [owner_->developerToolsPanelController_ loadDeveloperToolsForTab:tab
                                         inspectingBrowser:browser
                                                      port:BabelChromeConfiguration.remoteDebuggingPort];
}

- (void)createDeveloperToolsBrowserForTab:(BabelBrowserTab*)tab
                                urlString:(NSString*)urlString {
  owner_->pendingDeveloperToolsTab_ = tab;

  CefWindowInfo windowInfo;
  NSRect bounds = tab.developerToolsHostView.bounds;
  windowInfo.SetAsChild((__bridge CefWindowHandle)tab.developerToolsHostView,
                        CefRect(0, 0, bounds.size.width, bounds.size.height));
  windowInfo.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings settings;
  CefBrowserHost::CreateBrowser(windowInfo,
                                owner_->browserClient_,
                                std::string(urlString.UTF8String),
                                settings,
                                nullptr,
                                nullptr);
}

- (void)hideDeveloperToolsForTab:(BabelBrowserTab*)tab {
  [owner_->developerToolsPanelController_ hideDeveloperToolsForTab:tab
                                                pagesPanel:owner_->pagesPanel_
                                                  dockMode:owner_->developerToolsDockMode_
                                                 sizeRatio:owner_->developerToolsSizeRatio_];
}

- (void)closeDeveloperToolsForTab:(BabelBrowserTab*)tab {
  [owner_->developerToolsPanelController_ closeDeveloperToolsForTab:tab
                                                 pagesPanel:owner_->pagesPanel_
                                                   dockMode:owner_->developerToolsDockMode_
                                                  sizeRatio:owner_->developerToolsSizeRatio_];
}

- (void)reparentDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              intoTab:(BabelBrowserTab*)tab {
  [owner_->developerToolsPanelController_ reparentDeveloperToolsBrowser:browser
                                                        intoTab:tab
                                                    ownerWindow:owner_.window];
  tab.developerToolsPanelView.hidden = tab != owner_->selectedTab_;
}

- (void)layoutBrowserViewsForTab:(BabelBrowserTab*)tab {
  [owner_->developerToolsPanelController_ layoutBrowserViewsForTab:tab
                                                pagesPanel:owner_->pagesPanel_
                                                  dockMode:owner_->developerToolsDockMode_
                                                 sizeRatio:owner_->developerToolsSizeRatio_];
}


@end
