#import "Browser/InternalExtensionsNavigationHandler.h"

#import "Browser/ExtensionFolderController.h"
#import "Browser/ExtensionProfileStore.h"
#import "Browser/InternalNavigationActionParser.h"

@implementation BabelInternalExtensionsNavigationResult

@synthesize searchQuery;
@synthesize shouldRestartApplication;

@end

@implementation BabelInternalExtensionsNavigationHandler {
  BabelInternalNavigationActionParser* actionParser_;
  BabelExtensionFolderController* extensionFolderController_;
  BabelExtensionProfileStore* extensionProfileStore_;
}

- (instancetype)initWithActionParser:(BabelInternalNavigationActionParser*)actionParser
           extensionFolderController:(BabelExtensionFolderController*)extensionFolderController
                extensionProfileStore:(BabelExtensionProfileStore*)extensionProfileStore {
  self = [super init];
  if (self) {
    actionParser_ = actionParser;
    extensionFolderController_ = extensionFolderController;
    extensionProfileStore_ = extensionProfileStore;
  }
  return self;
}

- (BabelInternalExtensionsNavigationResult*)handleExtensionsComponents:(NSURLComponents*)components {
  BabelInternalExtensionsNavigationResult* result = [[BabelInternalExtensionsNavigationResult alloc] init];
  BabelInternalNavigationAction* action = [actionParser_ extensionsActionFromComponents:components];

  if ([action.name isEqualToString:BabelInternalNavigationActionSearch]) {
    result.searchQuery = action.value ?: @"";
    return result;
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionAddUnpacked]) {
    [extensionFolderController_ addUnpackedExtensionFromPanel];
    return result;
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionRemove]) {
    NSMutableArray<NSString*>* extensionPaths =
        [[extensionProfileStore_ installedExtensionPaths] mutableCopy];
    [extensionPaths removeObject:action.value];
    [extensionProfileStore_ saveInstalledExtensionPaths:extensionPaths];
    return result;
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionDisableProfile]) {
    [extensionProfileStore_ setProfileExtensionWithIdentifier:action.value enabled:NO];
    return result;
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionEnableProfile]) {
    [extensionProfileStore_ setProfileExtensionWithIdentifier:action.value enabled:YES];
    return result;
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionRemoveProfile]) {
    [extensionProfileStore_ removeProfileExtensionWithIdentifier:action.value];
    return result;
  }

  if ([action.name isEqualToString:BabelInternalNavigationActionRestart]) {
    result.shouldRestartApplication = YES;
    return result;
  }

  return result;
}

@end
