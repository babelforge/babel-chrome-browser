#import "Browser/Tabs/Closing/TabDefaultPageResetter.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/UI/Views/BrowserViews.h"

@implementation BabelTabDefaultPageResetter {
  NSString* defaultURLString_;
  NSString* (^compactTitleBlock_)(NSString* title);
}

- (instancetype)initWithDefaultURLString:(NSString*)defaultURLString
                       compactTitleBlock:(NSString* (^)(NSString* title))compactTitleBlock {
  self = [super init];
  if (self) {
    defaultURLString_ = [defaultURLString copy];
    compactTitleBlock_ = [compactTitleBlock copy];
  }
  return self;
}

- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab {
  NSString* defaultURLString = defaultURLString_ ?: @"";
  tab.urlString = defaultURLString;
  tab.requestedURLString = defaultURLString;
  tab.title = defaultURLString;
  tab.tabItemView.title = compactTitleBlock_ ? compactTitleBlock_(defaultURLString) : defaultURLString;
}

@end
