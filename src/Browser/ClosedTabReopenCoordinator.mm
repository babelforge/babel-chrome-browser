#import "Browser/ClosedTabReopenCoordinator.h"

#import "Browser/ClosedTabRestorationPlanner.h"
#import "Browser/RecentlyClosedTabStore.h"

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
