#import "Browser/Tabs/UI/TabContentViewAttacher.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/UI/Views/BrowserViews.h"

@implementation BabelTabContentViewAttacher

- (void)attachTab:(BabelBrowserTab*)tab toPagesPanel:(NSView*)pagesPanel {
  if (!tab || !pagesPanel) {
    return;
  }

  [pagesPanel addSubview:tab.hostView];
  [pagesPanel addSubview:tab.developerToolsPanelView];
}

@end
