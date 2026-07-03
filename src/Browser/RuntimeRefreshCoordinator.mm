#import "Browser/RuntimeRefreshCoordinator.h"

@implementation BabelRuntimeRefreshCoordinator {
  NSMutableDictionary<NSNumber*, NSArray<NSString*>*>* refreshURLStringsByBrowserIdentifier_;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    refreshURLStringsByBrowserIdentifier_ = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)enqueueRefreshURLStrings:(NSArray<NSString*>*)refreshURLStrings
            forBrowserIdentifier:(NSInteger)browserIdentifier {
  if (0 == refreshURLStrings.count) {
    return;
  }

  refreshURLStringsByBrowserIdentifier_[@(browserIdentifier)] = [refreshURLStrings copy];
}

- (NSArray<NSString*>*)consumeRefreshURLStringsForBrowserIdentifier:(NSInteger)browserIdentifier {
  NSNumber* key = @(browserIdentifier);
  NSArray<NSString*>* refreshURLStrings = refreshURLStringsByBrowserIdentifier_[key] ?: @[];
  [refreshURLStringsByBrowserIdentifier_ removeObjectForKey:key];
  return refreshURLStrings;
}

@end
