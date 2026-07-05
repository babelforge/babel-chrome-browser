#import "Browser/Address/Status/LinkStatusBarController.h"

#import "Browser/UI/Models/BrowserModels.h"

@implementation BabelLinkStatusBarController

- (void)hideStatusBar:(NSView*)statusBarView {
  statusBarView.hidden = YES;
}

- (void)updateStatusText:(NSString*)statusText
                  forTab:(BabelBrowserTab*)tab
             selectedTab:(BabelBrowserTab*)selectedTab
           statusBarView:(NSView*)statusBarView
             statusLabel:(NSTextField*)statusLabel
               rightView:(NSView*)rightView
              pagesPanel:(NSView*)pagesPanel {
  if (!tab || tab != selectedTab) {
    return;
  }

  NSString* displayedStatusText = statusText ?: @"";
  statusLabel.stringValue = displayedStatusText;
  statusBarView.hidden = displayedStatusText.length == 0;
  if (!statusBarView.hidden) {
    [rightView addSubview:statusBarView
               positioned:NSWindowAbove
               relativeTo:pagesPanel];
  }
}

@end
