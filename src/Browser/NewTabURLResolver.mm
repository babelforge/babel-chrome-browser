#import "Browser/NewTabURLResolver.h"

@implementation BabelNewTabURLResolution

@synthesize shouldOpen;
@synthesize requestedURLString;
@synthesize navigationURLString;

@end

@implementation BabelNewTabURLResolver {
  BabelSupportedViewerURLResolverBlock supportedViewerURLResolver_;
  BabelStableNavigationURLResolverBlock stableNavigationURLResolver_;
  BabelStableViewerURLPredicateBlock stableViewerURLPredicate_;
}

- (instancetype)initWithSupportedViewerURLResolver:(BabelSupportedViewerURLResolverBlock)supportedViewerURLResolver
                      stableNavigationURLResolver:(BabelStableNavigationURLResolverBlock)stableNavigationURLResolver
                         stableViewerURLPredicate:(BabelStableViewerURLPredicateBlock)stableViewerURLPredicate {
  self = [super init];
  if (self) {
    supportedViewerURLResolver_ = [supportedViewerURLResolver copy];
    stableNavigationURLResolver_ = [stableNavigationURLResolver copy];
    stableViewerURLPredicate_ = [stableViewerURLPredicate copy];
  }
  return self;
}

- (BabelNewTabURLResolution*)resolveURLString:(NSString*)urlString {
  BabelNewTabURLResolution* resolution = [[BabelNewTabURLResolution alloc] init];
  if (0 == urlString.length) {
    return resolution;
  }

  NSString* stableViewerURLString = supportedViewerURLResolver_ ? supportedViewerURLResolver_(urlString) : nil;
  NSString* requestedURLString = stableViewerURLString ?: urlString;
  NSString* navigationURLString = stableNavigationURLResolver_
      ? stableNavigationURLResolver_(requestedURLString)
      : nil;

  if (0 == navigationURLString.length) {
    BOOL isStableViewerURL = stableViewerURLPredicate_ ? stableViewerURLPredicate_(requestedURLString) : NO;
    if (isStableViewerURL || stableViewerURLString.length > 0) {
      return resolution;
    }
    navigationURLString = urlString;
  }

  resolution.shouldOpen = YES;
  resolution.requestedURLString = requestedURLString;
  resolution.navigationURLString = navigationURLString;
  return resolution;
}

@end
