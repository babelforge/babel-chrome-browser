#import "Browser/Navigation/Viewer/ViewerSourceActionHandler.h"

#import <Cocoa/Cocoa.h>

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Navigation/Viewer/ViewerSourceResolver.h"

@implementation BabelViewerSourceActionHandler {
  BabelViewerSourceResolver* viewerSourceResolver_;
}

- (instancetype)initWithViewerSourceResolver:(BabelViewerSourceResolver*)viewerSourceResolver {
  self = [super init];
  if (self) {
    viewerSourceResolver_ = viewerSourceResolver;
  }
  return self;
}

- (BOOL)canOpenViewerSourceForTab:(BabelBrowserTab*)tab {
  NSURL* sourceURL = [viewerSourceResolver_ viewerSourceFileURLForTab:tab];
  return sourceURL && [NSFileManager.defaultManager fileExistsAtPath:sourceURL.path];
}

- (void)openViewerSourceForTab:(BabelBrowserTab*)tab {
  NSURL* sourceURL = [viewerSourceResolver_ viewerSourceFileURLForTab:tab];
  if (!sourceURL) {
    return;
  }

  [NSWorkspace.sharedWorkspace openURL:sourceURL];
}

- (void)revealViewerSourceForTab:(BabelBrowserTab*)tab {
  NSURL* sourceURL = [viewerSourceResolver_ viewerSourceFileURLForTab:tab];
  if (!sourceURL) {
    return;
  }

  [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[ sourceURL ]];
}

@end
