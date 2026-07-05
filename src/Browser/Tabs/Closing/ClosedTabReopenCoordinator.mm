#import "Browser/Tabs/Closing/ClosedTabReopenCoordinator.h"

#import "Browser/Tabs/Closing/ClosedTabRestorationPlanner.h"
#import "Browser/Tabs/Closing/RecentlyClosedTabStore.h"

@implementation BabelClosedTabReopenCoordinator {
  BabelRecentlyClosedTabStore* recentlyClosedTabStore_;
  BabelClosedTabRestorationPlanner* closedTabRestorationPlanner_;
}

- (instancetype)initWithRecentlyClosedTabStore:(BabelRecentlyClosedTabStore*)recentlyClosedTabStore
                  closedTabRestorationPlanner:(BabelClosedTabRestorationPlanner*)closedTabRestorationPlanner {
  self = [super init];
  if (self) {
    recentlyClosedTabStore_ = recentlyClosedTabStore;
    closedTabRestorationPlanner_ = closedTabRestorationPlanner;
  }
  return self;
}

- (BabelClosedTabRestorationPlan*)restorationPlanForClosedTabAtIndex:(NSUInteger)closedTabIndex {
  BabelClosedTab* closedTab = [recentlyClosedTabStore_ popClosedTabAtIndex:closedTabIndex];
  if (!closedTab) {
    return nil;
  }

  return [closedTabRestorationPlanner_ restorationPlanForClosedTab:closedTab];
}

@end
