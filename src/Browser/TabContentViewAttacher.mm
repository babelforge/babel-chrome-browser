#import "Browser/TabContentViewAttacher.h"

#import "Browser/BrowserModels.h"
#import "Browser/BrowserViews.h"

@implementation BabelTabContentViewAttacher

- (void)attachTab:(BabelBrowserTab*)tab toPagesPanel:(NSView*)pagesPanel {
  if (!tab || !pagesPanel) {
    return;
  }

  [pagesPanel addSubview:tab.hostView];
  [pagesPanel addSubview:tab.developerToolsPanelView];
}

@end
