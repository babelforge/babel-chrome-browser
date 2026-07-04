#import "Browser/ViewerSourceResolver.h"

#import "Browser/BrowserModels.h"
#import "Browser/StableViewerURLResolver.h"

@implementation BabelViewerSourceResolver {
  BabelStableViewerURLResolver* stableViewerURLResolver_;
}

- (instancetype)initWithStableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver {
  self = [super init];
  if (self) {
    stableViewerURLResolver_ = stableViewerURLResolver;
  }
  return self;
}

- (NSURL*)viewerSourceFileURLForTab:(BabelBrowserTab*)tab {
  NSString* requestedURLString = tab.requestedURLString ?: @"";
  if (![stableViewerURLResolver_ isStableViewerURLString:requestedURLString] ||
      ![[stableViewerURLResolver_ sourceKindForStableViewerURLString:requestedURLString] isEqualToString:@"file"]) {
    return nil;
  }

  NSURL* sourceURL = [stableViewerURLResolver_ sourceURLForViewerURLString:requestedURLString];
  return sourceURL.isFileURL ? sourceURL : nil;
}

@end

