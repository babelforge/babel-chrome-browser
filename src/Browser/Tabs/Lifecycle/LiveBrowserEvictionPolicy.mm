#import "Browser/Tabs/Lifecycle/LiveBrowserEvictionPolicy.h"

#import "Browser/UI/Models/BrowserModels.h"

@interface BabelLiveBrowserEvictionPolicy ()

@property(nonatomic, strong) NSMutableArray<NSString*>* recentlyUsedTabIdentifiers;
@property(nonatomic, strong) NSMutableSet<NSString*>* evictingTabIdentifiers;

@end

@implementation BabelLiveBrowserEvictionPolicy

@synthesize recentlyUsedTabIdentifiers = recentlyUsedTabIdentifiers_;
@synthesize evictingTabIdentifiers = evictingTabIdentifiers_;

/**
 * Initializes the live browser eviction policy.
 *
 * @return The initialized policy.
 */
- (instancetype)init {
  self = [super init];
  if (self) {
    recentlyUsedTabIdentifiers_ = [NSMutableArray array];
    evictingTabIdentifiers_ = [NSMutableSet set];
  }
  return self;
}

- (void)reset {
  [self.recentlyUsedTabIdentifiers removeAllObjects];
  [self.evictingTabIdentifiers removeAllObjects];
}

- (void)touchTab:(BabelBrowserTab*)tab {
  if (0 == tab.identifier.length) {
    return;
  }

  [self.recentlyUsedTabIdentifiers removeObject:tab.identifier];
  [self.recentlyUsedTabIdentifiers addObject:tab.identifier];
}

- (void)removeTab:(BabelBrowserTab*)tab {
  NSString* tabIdentifier = tab.identifier ?: @"";
  [self.recentlyUsedTabIdentifiers removeObject:tabIdentifier];
  [self.evictingTabIdentifiers removeObject:tabIdentifier];
}

- (void)markTabEvicting:(BabelBrowserTab*)tab {
  if (0 == tab.identifier.length) {
    return;
  }

  [self.evictingTabIdentifiers addObject:tab.identifier];
}

- (void)unmarkTabEvicting:(BabelBrowserTab*)tab {
  [self.evictingTabIdentifiers removeObject:tab.identifier ?: @""];
}

- (BOOL)isTabEvicting:(BabelBrowserTab*)tab {
  return [self.evictingTabIdentifiers containsObject:tab.identifier ?: @""];
}

- (NSArray<BabelBrowserTab*>*)liveBrowserTabsInGroupsExcludingEvictions:
    (NSArray<BabelBrowserGroup*>*)groups {
  NSMutableArray<BabelBrowserTab*>* liveTabs = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && ![self isTabEvicting:tab]) {
        [liveTabs addObject:tab];
      }
    }
  }
  return liveTabs;
}

- (BabelBrowserTab*)leastRecentlyUsedEvictableTabFromTabs:(NSArray<BabelBrowserTab*>*)liveTabs
                                     protectedIdentifiers:(NSSet<NSString*>*)protectedIdentifiers {
  for (BabelBrowserTab* tab in liveTabs) {
    if (![self.recentlyUsedTabIdentifiers containsObject:tab.identifier ?: @""] &&
        ![protectedIdentifiers containsObject:tab.identifier ?: @""]) {
      return tab;
    }
  }

  for (NSString* tabIdentifier in self.recentlyUsedTabIdentifiers) {
    if ([protectedIdentifiers containsObject:tabIdentifier]) {
      continue;
    }

    for (BabelBrowserTab* tab in liveTabs) {
      if ([tab.identifier isEqualToString:tabIdentifier]) {
        return tab;
      }
    }
  }

  return nil;
}

@end
