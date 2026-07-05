#import "Browser/Tabs/Lifecycle/LiveBrowserLimitEnforcer.h"

#import "Browser/Tabs/Selection/AdjacentTabPreloadPlanner.h"
#import "Browser/Tabs/Lifecycle/LiveBrowserEvictionPolicy.h"

@implementation BabelLiveBrowserLimitEnforcer {
  BabelAdjacentTabPreloadPlanner* adjacentTabPreloadPlanner_;
  BabelLiveBrowserEvictionPolicy* liveBrowserEvictionPolicy_;
  NSUInteger maximumLivePageBrowsers_;
}

- (instancetype)initWithAdjacentTabPreloadPlanner:(BabelAdjacentTabPreloadPlanner*)adjacentTabPreloadPlanner
                        liveBrowserEvictionPolicy:(BabelLiveBrowserEvictionPolicy*)liveBrowserEvictionPolicy
                          maximumLivePageBrowsers:(NSUInteger)maximumLivePageBrowsers {
  self = [super init];
  if (self) {
    adjacentTabPreloadPlanner_ = adjacentTabPreloadPlanner;
    liveBrowserEvictionPolicy_ = liveBrowserEvictionPolicy;
    maximumLivePageBrowsers_ = maximumLivePageBrowsers;
  }
  return self;
}

- (void)enforceLiveBrowserLimitForGroups:(NSArray<BabelBrowserGroup*>*)groups
                             selectedTab:(BabelBrowserTab*)selectedTab
                             visibleTabs:(NSArray<BabelBrowserTab*>*)visibleTabs
                            closeHandler:(BabelLiveBrowserCloseHandler)closeHandler {
  if (!closeHandler) {
    return;
  }

  NSArray<BabelBrowserTab*>* adjacentTabs =
      [adjacentTabPreloadPlanner_ adjacentTabsToPreloadAroundTab:selectedTab tabs:visibleTabs];
  NSMutableSet<NSString*>* protectedIdentifiers =
      [adjacentTabPreloadPlanner_ protectedLiveBrowserTabIdentifiersForSelectedTab:selectedTab
                                                                      adjacentTabs:adjacentTabs
                                                                            groups:groups];

  while (YES) {
    NSArray<BabelBrowserTab*>* liveTabs =
        [liveBrowserEvictionPolicy_ liveBrowserTabsInGroupsExcludingEvictions:groups];
    if (liveTabs.count <= maximumLivePageBrowsers_) {
      return;
    }

    BabelBrowserTab* tabToEvict =
        [liveBrowserEvictionPolicy_ leastRecentlyUsedEvictableTabFromTabs:liveTabs
                                                     protectedIdentifiers:protectedIdentifiers];
    if (!tabToEvict) {
      return;
    }

    closeHandler(tabToEvict);
  }
}

@end
