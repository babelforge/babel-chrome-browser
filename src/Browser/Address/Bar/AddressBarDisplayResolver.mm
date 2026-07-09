#import "Browser/Address/Bar/AddressBarDisplayResolver.h"

#import "Browser/Modules/Core/ModuleActionService.h"
#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"

@implementation BabelAddressBarDisplayResolver {
  BabelStableViewerURLResolver* stableViewerURLResolver_;
  BabelModuleActionService* moduleActionService_;
  BabelInternalPageTabPredicateBlock internalPageTabPredicate_;
}

- (instancetype)initWithStableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
                            moduleActionService:(BabelModuleActionService*)moduleActionService
                       internalPageTabPredicate:(BabelInternalPageTabPredicateBlock)internalPageTabPredicate {
  self = [super init];
  if (self) {
    stableViewerURLResolver_ = stableViewerURLResolver;
    moduleActionService_ = moduleActionService;
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
  NSDictionary* badge = [moduleActionService_ addressBadgeForStableViewerURL:badgeURL];
  NSString* badgeText = [badge[@"text"] isKindOfClass:NSString.class] ? badge[@"text"] : @"";
  if (0 == badgeText.length) {
    return nil;
  }

  return badge;
}

@end
