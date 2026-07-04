#import "Browser/HistoryPageDataSource.h"

#import "Browser/BrowserModels.h"
#import "Browser/HistoryPageRenderer.h"
#import "Browser/InternalPageTabClassifier.h"
#import "Browser/RecentlyClosedTabStore.h"

@implementation BabelHistoryPageDataSource {
  BabelInternalPageTabClassifier* internalPageTabClassifier_;
  BabelRecentlyClosedTabStore* recentlyClosedTabStore_;
  NSString* defaultGroupName_;
}

- (instancetype)initWithInternalPageTabClassifier:(BabelInternalPageTabClassifier*)internalPageTabClassifier
                          recentlyClosedTabStore:(BabelRecentlyClosedTabStore*)recentlyClosedTabStore
                                defaultGroupName:(NSString*)defaultGroupName {
  self = [super init];
  if (self) {
    internalPageTabClassifier_ = internalPageTabClassifier;
    recentlyClosedTabStore_ = recentlyClosedTabStore;
    defaultGroupName_ = defaultGroupName ?: @"";
  }
  return self;
}

- (NSArray<NSDictionary*>*)openTabRowsForGroups:(NSArray<BabelBrowserGroup*>*)groups {
  NSMutableArray<NSDictionary*>* rows = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups ?: @[]) {
    for (BabelBrowserTab* tab in group.tabs ?: @[]) {
      if ([internalPageTabClassifier_ isInternalPageTab:tab]) {
        continue;
      }

      NSString* title = tab.title.length > 0 ? tab.title : tab.requestedURLString;
      [rows addObject:@{
        BabelHistoryRowTitleKey : title ?: @"",
        BabelHistoryRowURLStringKey : tab.requestedURLString ?: tab.urlString ?: @"",
        BabelHistoryRowGroupNameKey : group.name ?: defaultGroupName_,
      }];
    }
  }
  return rows;
}

- (NSArray<NSDictionary*>*)recentlyClosedTabRows {
  NSMutableArray<NSDictionary*>* rows = [NSMutableArray array];
  NSArray<BabelClosedTab*>* closedTabs = [recentlyClosedTabStore_ allClosedTabs];
  for (NSInteger index = (NSInteger)closedTabs.count - 1; index >= 0; index--) {
    BabelClosedTab* closedTab = closedTabs[(NSUInteger)index];
    NSString* title = closedTab.title.length > 0 ? closedTab.title : closedTab.requestedURLString;
    [rows addObject:@{
      BabelHistoryRowTitleKey : title ?: @"",
      BabelHistoryRowURLStringKey : closedTab.requestedURLString ?: closedTab.urlString ?: @"",
      BabelHistoryRowGroupNameKey : closedTab.groupName ?: defaultGroupName_,
      BabelHistoryRowReopenIndexKey : @((NSUInteger)index),
    }];
  }
  return rows;
}

@end
