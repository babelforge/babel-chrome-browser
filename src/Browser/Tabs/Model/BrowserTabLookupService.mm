#import "Browser/Tabs/Model/BrowserTabLookupService.h"

#import "Browser/UI/Models/BrowserModels.h"

@implementation BabelBrowserTabLookupService

- (BabelBrowserTab*)tabForBrowser:(CefRefPtr<CefBrowser>)browser
                           groups:(NSArray<BabelBrowserGroup*>*)groups {
  if (!browser) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        return tab;
      }
    }
  }

  return nil;
}

@end
