#import "Browser/InternalPageTabClassifier.h"

#import "Browser/BrowserModels.h"

@implementation BabelInternalPageTabClassifier {
  NSSet<NSString*>* internalPageURLStrings_;
}

- (instancetype)initWithInternalPageURLStrings:(NSArray<NSString*>*)internalPageURLStrings {
  self = [super init];
  if (self) {
    internalPageURLStrings_ = [NSSet setWithArray:internalPageURLStrings ?: @[]];
  }
  return self;
}

- (BOOL)isInternalPageTab:(BabelBrowserTab*)tab {
  return [internalPageURLStrings_ containsObject:tab.requestedURLString ?: @""];
}

@end

