#import "Browser/BrowserWindowController+Private.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation BabelBrowserWindowController (DeveloperToolsEmbedding)

- (void)loadDeveloperToolsForTab:(BabelBrowserTab*)tab
                inspectingBrowser:(CefRefPtr<CefBrowser>)browser {
  [developerToolsPanelController_ loadDeveloperToolsForTab:tab
                                         inspectingBrowser:browser
                                                      port:BabelChromeConfiguration.remoteDebuggingPort];
}

- (void)createDeveloperToolsBrowserForTab:(BabelBrowserTab*)tab
                                urlString:(NSString*)urlString {
  pendingDeveloperToolsTab_ = tab;

  CefWindowInfo windowInfo;
  NSRect bounds = tab.developerToolsHostView.bounds;
  windowInfo.SetAsChild((__bridge CefWindowHandle)tab.developerToolsHostView,
                        CefRect(0, 0, bounds.size.width, bounds.size.height));
  windowInfo.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings settings;
  CefBrowserHost::CreateBrowser(windowInfo,
                                browserClient_,
                                std::string(urlString.UTF8String),
                                settings,
                                nullptr,
                                nullptr);
}

- (void)hideDeveloperToolsForTab:(BabelBrowserTab*)tab {
  [developerToolsPanelController_ hideDeveloperToolsForTab:tab
                                                pagesPanel:pagesPanel_
                                                  dockMode:developerToolsDockMode_
                                                 sizeRatio:developerToolsSizeRatio_];
}

- (void)closeDeveloperToolsForTab:(BabelBrowserTab*)tab {
  [developerToolsPanelController_ closeDeveloperToolsForTab:tab
                                                 pagesPanel:pagesPanel_
                                                   dockMode:developerToolsDockMode_
                                                  sizeRatio:developerToolsSizeRatio_];
}

- (void)reparentDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              intoTab:(BabelBrowserTab*)tab {
  [developerToolsPanelController_ reparentDeveloperToolsBrowser:browser
                                                        intoTab:tab
                                                    ownerWindow:self.window];
  tab.developerToolsPanelView.hidden = tab != selectedTab_;
}

- (void)layoutBrowserViewsForTab:(BabelBrowserTab*)tab {
  [developerToolsPanelController_ layoutBrowserViewsForTab:tab
                                                pagesPanel:pagesPanel_
                                                  dockMode:developerToolsDockMode_
                                                 sizeRatio:developerToolsSizeRatio_];
}

@end

#pragma clang diagnostic pop
