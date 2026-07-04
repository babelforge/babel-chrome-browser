#import "Browser/RuntimeRefreshTabMatcher.h"

#import "Browser/LocalServiceURLClassifier.h"
#import "Browser/StableServerURLResolver.h"

@implementation BabelRuntimeRefreshTabMatcher {
  BabelStableServerURLResolver* stableServerURLResolver_;
  BabelLocalServiceURLClassifier* localServiceURLClassifier_;
}

- (instancetype)initWithStableServerURLResolver:(BabelStableServerURLResolver*)stableServerURLResolver
                      localServiceURLClassifier:(BabelLocalServiceURLClassifier*)localServiceURLClassifier {
  self = [super init];
  if (self) {
    stableServerURLResolver_ = stableServerURLResolver;
    localServiceURLClassifier_ = localServiceURLClassifier;
  }
  return self;
}

- (BOOL)tabRequestedURLString:(NSString*)tabRequestedURLString
           tabActualURLString:(NSString*)tabActualURLString
    matchesRefreshURLString:(NSString*)requestedURLString {
  if ([tabRequestedURLString isEqualToString:requestedURLString]) {
    return YES;
  }

  if ([requestedURLString isEqualToString:@"babelchrome://project-launcher"] &&
      [localServiceURLClassifier_ isProjectLauncherModuleURLString:tabActualURLString]) {
    return YES;
  }

  if (![stableServerURLResolver_ isStableServerURLString:requestedURLString]) {
    return NO;
  }

  NSString* requestedProjectIdentifier =
      [stableServerURLResolver_ serverProjectIdentifierForStableURLString:requestedURLString];
  NSString* tabProjectIdentifier =
      [stableServerURLResolver_ serverProjectIdentifierForStableURLString:tabRequestedURLString];
  return requestedProjectIdentifier.length > 0 &&
         [requestedProjectIdentifier isEqualToString:tabProjectIdentifier];
}

@end
