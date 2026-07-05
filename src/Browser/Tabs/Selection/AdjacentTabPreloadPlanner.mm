#import "Browser/Tabs/Selection/AdjacentTabPreloadPlanner.h"

#import "Browser/UI/Models/BrowserModels.h"

@implementation BabelAdjacentTabPreloadPlanner

- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab
                                                        tabs:(NSArray<BabelBrowserTab*>*)tabs {
  NSUInteger selectedIndex = [tabs indexOfObject:tab];
  if (selectedIndex == NSNotFound || tabs.count < 2) {
    return @[];
  }

  NSMutableArray<BabelBrowserTab*>* tabsToPreload = [NSMutableArray array];
  if (selectedIndex > 0) {
    [tabsToPreload addObject:tabs[selectedIndex - 1]];
  }

  if (selectedIndex + 1 < tabs.count) {
    BabelBrowserTab* nextTab = tabs[selectedIndex + 1];
    if (![tabsToPreload containsObject:nextTab]) {
      [tabsToPreload addObject:nextTab];
    }
  }

  return tabsToPreload;
}

- (NSMutableSet<NSString*>*)protectedLiveBrowserTabIdentifiersForSelectedTab:(BabelBrowserTab*)selectedTab
                                                                adjacentTabs:(NSArray<BabelBrowserTab*>*)adjacentTabs
                                                                      groups:(NSArray<BabelBrowserGroup*>*)groups {
  NSMutableSet<NSString*>* protectedIdentifiers = [NSMutableSet set];
  if (selectedTab.identifier.length > 0) {
    [protectedIdentifiers addObject:selectedTab.identifier];
  }

  for (BabelBrowserTab* tab in adjacentTabs) {
    if (tab.identifier.length > 0) {
      [protectedIdentifiers addObject:tab.identifier];
    }
  }

  for (BabelBrowserGroup* group in groups) {
    for (BabelBrowserTab* tab in group.tabs) {
      if (tab.developerToolsVisible && tab.identifier.length > 0) {
        [protectedIdentifiers addObject:tab.identifier];
      }
    }
  }

  return protectedIdentifiers;
}

@end
