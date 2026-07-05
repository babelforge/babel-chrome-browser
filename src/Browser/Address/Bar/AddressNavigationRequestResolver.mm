#import "Browser/Address/Bar/AddressNavigationRequestResolver.h"

#import "Browser/Address/Bar/AddressBarDisplayResolver.h"
#import "Browser/Address/Bar/AddressFieldNavigationResolver.h"
#import "Browser/Address/Bar/AddressNavigationNormalizer.h"
#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"

@implementation BabelAddressNavigationRequest
@synthesize requestedURLString;
@synthesize navigationURLString;
@synthesize shouldRestoreAddressBar;
@end

@implementation BabelAddressNavigationRequestResolver {
  NSString* defaultURLString_;
  BabelAddressNavigationNormalizer* navigationNormalizer_;
  BabelAddressFieldNavigationResolver* fieldNavigationResolver_;
  BabelAddressBarDisplayResolver* addressBarDisplayResolver_;
  BabelStableViewerURLResolver* stableViewerURLResolver_;
  BabelAddressURLResolutionBlock supportedViewerURLResolver_;
  BabelAddressURLResolutionBlock stableNavigationURLResolver_;
}

- (instancetype)initWithDefaultURLString:(NSString*)defaultURLString
                    navigationNormalizer:(BabelAddressNavigationNormalizer*)navigationNormalizer
                 fieldNavigationResolver:(BabelAddressFieldNavigationResolver*)fieldNavigationResolver
                addressBarDisplayResolver:(BabelAddressBarDisplayResolver*)addressBarDisplayResolver
                  stableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
               supportedViewerURLResolver:(BabelAddressURLResolutionBlock)supportedViewerURLResolver
             stableNavigationURLResolver:(BabelAddressURLResolutionBlock)stableNavigationURLResolver {
  self = [super init];
  if (self) {
    defaultURLString_ = [defaultURLString copy];
    navigationNormalizer_ = navigationNormalizer;
    fieldNavigationResolver_ = fieldNavigationResolver;
    addressBarDisplayResolver_ = addressBarDisplayResolver;
    stableViewerURLResolver_ = stableViewerURLResolver;
    supportedViewerURLResolver_ = [supportedViewerURLResolver copy];
    stableNavigationURLResolver_ = [stableNavigationURLResolver copy];
  }
  return self;
}

- (BabelAddressNavigationRequest*)navigationRequestForAddressString:(NSString*)addressString
                                                        selectedTab:(BabelBrowserTab*)selectedTab {
  if (!selectedTab) {
    return nil;
  }

  NSString* resolvedAddressString = [self resolvedAddressStringForAddressString:addressString
                                                                    selectedTab:selectedTab];
  NSString* normalizedURLString =
      [navigationNormalizer_ navigationStringFromAddress:resolvedAddressString
                                        defaultURLString:defaultURLString_ ?: @""];
  NSString* supportedViewerURLString =
      supportedViewerURLResolver_ ? supportedViewerURLResolver_(normalizedURLString) : nil;
  NSString* requestedURLString = supportedViewerURLString ?: normalizedURLString;
  NSString* navigationURLString =
      stableNavigationURLResolver_ ? stableNavigationURLResolver_(requestedURLString) : @"";

  BabelAddressNavigationRequest* request = [[BabelAddressNavigationRequest alloc] init];
  request.requestedURLString = requestedURLString ?: @"";
  if (navigationURLString.length == 0) {
    if ([stableViewerURLResolver_ isStableViewerURLString:requestedURLString] ||
        supportedViewerURLString.length > 0) {
      request.shouldRestoreAddressBar = YES;
      return request;
    }
    navigationURLString = normalizedURLString;
  }

  request.navigationURLString = navigationURLString ?: @"";
  request.shouldRestoreAddressBar = NO;
  return request;
}

- (NSString*)resolvedAddressStringForAddressString:(NSString*)addressString
                                       selectedTab:(BabelBrowserTab*)selectedTab {
  NSString* displayedURLString = [addressBarDisplayResolver_ displayURLStringForTab:selectedTab];
  NSString* actualURLString = selectedTab.requestedURLString ?: selectedTab.urlString ?: @"";
  return [fieldNavigationResolver_ navigationStringForAddressString:addressString ?: @""
                                                displayedURLString:displayedURLString
                                                   actualURLString:actualURLString];
}

@end
