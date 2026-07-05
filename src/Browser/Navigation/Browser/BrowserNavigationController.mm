#import "Browser/Navigation/Browser/BrowserNavigationController.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/UI/Views/BrowserSupportViews.h"

@implementation BabelBrowserNavigationController

- (void)navigateTabBack:(BabelBrowserTab*)tab {
  if (!tab || ![tab browser] || ![tab browser]->CanGoBack()) {
    return;
  }

  [tab browser]->GoBack();
}

- (void)navigateTabForward:(BabelBrowserTab*)tab {
  if (!tab || ![tab browser] || ![tab browser]->CanGoForward()) {
    return;
  }

  [tab browser]->GoForward();
}

- (void)reloadTab:(BabelBrowserTab*)tab {
  if (!tab || ![tab browser]) {
    return;
  }

  [tab browser]->Reload();
}

- (void)reloadTabIgnoringCache:(BabelBrowserTab*)tab {
  if (!tab || ![tab browser]) {
    return;
  }

  CefRefPtr<CefBrowser> browser = [tab browser];
  CefRefPtr<CefRequestContext> requestContext = browser->GetHost()->GetRequestContext();
  if (requestContext) {
    requestContext->ClearHttpCache(new BabelReloadIgnoreCacheCallback(browser));
    return;
  }

  browser->ReloadIgnoreCache();
}

@end
