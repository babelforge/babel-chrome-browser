#import "Browser/Navigation/StableURLs/StableURLTabReloader.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Navigation/Refresh/RuntimeRefreshTabMatcher.h"
#import "Browser/Navigation/StableURLs/StableServerURLResolver.h"

@implementation BabelStableURLTabReloader {
  BabelStableServerURLResolver* stableServerURLResolver_;
  BabelRuntimeRefreshTabMatcher* refreshTabMatcher_;
  BabelStableURLNavigationResolverBlock navigationResolverBlock_;
}

- (instancetype)initWithStableServerURLResolver:(BabelStableServerURLResolver*)stableServerURLResolver
                              refreshTabMatcher:(BabelRuntimeRefreshTabMatcher*)refreshTabMatcher
                        navigationResolverBlock:(BabelStableURLNavigationResolverBlock)navigationResolverBlock {
  self = [super init];
  if (self) {
    stableServerURLResolver_ = stableServerURLResolver;
    refreshTabMatcher_ = refreshTabMatcher;
    navigationResolverBlock_ = [navigationResolverBlock copy];
  }
  return self;
}

- (BOOL)reloadTabsWithRequestedURLString:(NSString*)requestedURLString
                            excludingTab:(BabelBrowserTab*)excludedTab
                                  groups:(NSArray<BabelBrowserGroup*>*)groups {
  if (![stableServerURLResolver_ isStableBabelChromeURLString:requestedURLString]) {
    return NO;
  }

  BOOL didReload = NO;
  for (BabelBrowserGroup* group in groups) {
    for (BabelBrowserTab* tab in group.tabs) {
      if (tab == excludedTab ||
          ![refreshTabMatcher_ tabRequestedURLString:tab.requestedURLString
                                  tabActualURLString:tab.urlString
                           matchesRefreshURLString:requestedURLString]) {
        continue;
      }

      NSString* stableURLString =
          [stableServerURLResolver_ isStableServerURLString:requestedURLString]
              ? tab.requestedURLString
              : requestedURLString;
      NSString* navigationURLString = navigationResolverBlock_ ? navigationResolverBlock_(stableURLString) : nil;
      if (navigationURLString.length == 0) {
        continue;
      }

      tab.urlString = navigationURLString;
      if ([tab browser]) {
        tab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
      didReload = YES;
    }
  }

  return didReload;
}

- (BOOL)reloadServerTabsWithProjectIdentifiers:(NSArray<NSString*>*)projectIdentifiers
                                        groups:(NSArray<BabelBrowserGroup*>*)groups {
  NSSet<NSString*>* identifierSet = [NSSet setWithArray:projectIdentifiers];
  if (identifierSet.count == 0) {
    return NO;
  }

  BOOL didReload = NO;
  for (BabelBrowserGroup* group in groups) {
    for (BabelBrowserTab* tab in group.tabs) {
      NSString* projectIdentifier =
          [stableServerURLResolver_ serverProjectIdentifierForStableURLString:tab.requestedURLString];
      if (projectIdentifier.length == 0 || ![identifierSet containsObject:projectIdentifier]) {
        continue;
      }

      NSString* navigationURLString = navigationResolverBlock_
          ? navigationResolverBlock_(tab.requestedURLString)
          : nil;
      if (navigationURLString.length == 0) {
        continue;
      }

      tab.urlString = navigationURLString;
      if ([tab browser]) {
        tab.browser->GetMainFrame()->LoadURL(std::string(navigationURLString.UTF8String));
      }
      didReload = YES;
    }
  }

  return didReload;
}

@end
