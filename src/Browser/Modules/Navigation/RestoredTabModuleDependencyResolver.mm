#import "Browser/Modules/Navigation/RestoredTabModuleDependencyResolver.h"

#import "Browser/Modules/Core/ModuleActionService.h"
#import "Browser/Navigation/StableURLs/StableServerURLResolver.h"
#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"

static NSString* const kBabelProjectLauncherModuleIdentifier = @"babelforge.project-launcher";

@implementation BabelRestoredTabModuleDependencyResolver {
  BabelModuleActionService* moduleActionService_;
  BabelStableViewerURLResolver* stableViewerURLResolver_;
  BabelStableServerURLResolver* stableServerURLResolver_;
}

- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService
                    stableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
                     stableServerURLResolver:(BabelStableServerURLResolver*)stableServerURLResolver {
  self = [super init];
  if (self) {
    moduleActionService_ = moduleActionService;
    stableViewerURLResolver_ = stableViewerURLResolver;
    stableServerURLResolver_ = stableServerURLResolver;
  }

  return self;
}

- (NSString*)moduleIdentifierForRestoredURLString:(NSString*)urlString {
  if (urlString.length == 0) {
    return nil;
  }

  if ([stableViewerURLResolver_ isStableViewerURLString:urlString]) {
    NSURL* sourceURL = [stableViewerURLResolver_ sourceURLForViewerURLString:urlString];
    return [moduleActionService_ viewerModuleIdentifierForURL:sourceURL];
  }

  if ([stableServerURLResolver_ isStableServerURLString:urlString]) {
    return kBabelProjectLauncherModuleIdentifier;
  }

  NSURLComponents* components = [NSURLComponents componentsWithString:urlString ?: @""];
  if (!components) {
    return nil;
  }

  NSString* localServiceModuleIdentifier =
      [moduleActionService_ localServiceModuleIdentifierForURLComponents:components];
  if (localServiceModuleIdentifier.length > 0) {
    return localServiceModuleIdentifier;
  }

  if ([components.scheme isEqualToString:@"babelchrome"]) {
    return [moduleActionService_ moduleIdentifierForBabelChromeComponents:components];
  }

  return nil;
}

@end
