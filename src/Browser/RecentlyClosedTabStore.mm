#import "Browser/RecentlyClosedTabStore.h"

#import "Browser/BrowserModels.h"

@implementation BabelRecentlyClosedTabStore {
  NSMutableArray<BabelClosedTab*>* closedTabs_;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    closedTabs_ = [NSMutableArray array];
  }
  return self;
}

- (NSUInteger)count {
  return closedTabs_.count;
}

- (NSArray<BabelClosedTab*>*)allClosedTabs {
  return [closedTabs_ copy];
}

- (void)pushClosedTab:(BabelClosedTab*)closedTab {
  if (!closedTab) {
    return;
  }

  [closedTabs_ addObject:closedTab];
}

- (BabelClosedTab*)popClosedTabAtIndex:(NSUInteger)index {
  if (index >= closedTabs_.count) {
    return nil;
  }

  BabelClosedTab* closedTab = closedTabs_[index];
  [closedTabs_ removeObjectAtIndex:index];
  return closedTab;
}

@end
