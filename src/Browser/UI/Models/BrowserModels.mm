#import "Browser/UI/Models/BrowserModels.h"

@implementation BabelBrowserTab {
  CefRefPtr<CefBrowser> browser_;
  CefRefPtr<CefBrowser> developerToolsBrowser_;
}

@synthesize identifier;
@synthesize title;
@synthesize urlString;
@synthesize requestedURLString;
@synthesize parentTabIdentifier;
@synthesize faviconImage;
@synthesize tabItemView;
@synthesize hostView;
@synthesize developerToolsPanelView;
@synthesize developerToolsToolbarView;
@synthesize developerToolsHostView;
@synthesize developerToolsResizeHandleView;
@synthesize developerToolsSourceWindow;
@synthesize developerToolsVisible;

- (void)setBrowser:(CefRefPtr<CefBrowser>)browser {
  browser_ = browser;
}

- (CefRefPtr<CefBrowser>)browser {
  return browser_;
}

- (void)setDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser {
  developerToolsBrowser_ = browser;
}

- (CefRefPtr<CefBrowser>)developerToolsBrowser {
  return developerToolsBrowser_;
}

@end

@implementation BabelBrowserGroup

@synthesize identifier;
@synthesize name;
@synthesize tabs;
@synthesize selectedTabIdentifier;
@synthesize groupItemView;

- (instancetype)init {
  self = [super init];
  if (self) {
    tabs = [NSMutableArray array];
  }
  return self;
}

@end

@implementation BabelClosedTab

@synthesize urlString;
@synthesize requestedURLString;
@synthesize title;
@synthesize groupIdentifier;
@synthesize groupName;

@end
