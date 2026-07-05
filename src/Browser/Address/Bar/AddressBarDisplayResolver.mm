#import "Browser/Address/Bar/AddressBarDisplayResolver.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"
#import "LocalServices/LocalServiceHost.h"

@implementation BabelAddressBarDisplayResolver {
  BabelStableViewerURLResolver* stableViewerURLResolver_;
  BabelInternalPageTabPredicateBlock internalPageTabPredicate_;
}

- (instancetype)initWithStableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
                       internalPageTabPredicate:(BabelInternalPageTabPredicateBlock)internalPageTabPredicate {
  self = [super init];
  if (self) {
    stableViewerURLResolver_ = stableViewerURLResolver;
    internalPageTabPredicate_ = [internalPageTabPredicate copy];
  }
  return self;
}

- (NSString*)displayURLStringForTab:(BabelBrowserTab*)tab {
  if (internalPageTabPredicate_ && internalPageTabPredicate_(tab)) {
    return tab.requestedURLString ?: @"";
  }

  NSString* urlString = tab.requestedURLString ?: tab.urlString ?: @"";
  return [stableViewerURLResolver_ displayURLStringForStableViewerURLString:urlString];
}

- (NSDictionary*)addressBadgeForTab:(BabelBrowserTab*)tab {
  NSString* urlString = tab.requestedURLString ?: tab.urlString ?: @"";
  if (![stableViewerURLResolver_ isStableViewerURLString:urlString]) {
    return nil;
  }

  NSURL* badgeURL = [NSURL URLWithString:urlString];
  NSDictionary* badge = [BabelLocalServiceHost.sharedHost addressBadgeForURL:badgeURL];
  NSString* badgeText = [badge[@"text"] isKindOfClass:NSString.class] ? badge[@"text"] : @"";
  if (0 == badgeText.length) {
    return nil;
  }

  return badge;
}

@end
