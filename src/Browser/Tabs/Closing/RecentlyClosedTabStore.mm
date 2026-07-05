#import "Browser/Tabs/Closing/RecentlyClosedTabStore.h"

#import "Browser/UI/Models/BrowserModels.h"

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

- (void)pushTab:(BabelBrowserTab*)tab
      fromGroup:(BabelBrowserGroup*)group
defaultGroupName:(NSString*)defaultGroupName {
  if (!tab || tab.urlString.length == 0 || !group) {
    return;
  }

  BabelClosedTab* closedTab = [[BabelClosedTab alloc] init];
  closedTab.urlString = tab.urlString;
  closedTab.requestedURLString = tab.requestedURLString ?: tab.urlString;
  closedTab.title = tab.title ?: tab.urlString;
  closedTab.groupIdentifier = group.identifier;
  closedTab.groupName = group.name ?: defaultGroupName ?: @"";
  [self pushClosedTab:closedTab];
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
