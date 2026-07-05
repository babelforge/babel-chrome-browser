#import "Browser/InternalPages/Modules/ModuleInternalPageHTMLBuilder.h"

#import "Browser/InternalPages/Rendering/InternalPageRenderer.h"
#import "Browser/Modules/Core/ModuleActionService.h"
#import "Browser/InternalPages/Modules/ModulePageRenderer.h"
#import "Browser/Modules/Updates/ModuleUpdateService.h"

@implementation BabelModuleInternalPageHTMLBuilder {
  BabelModuleActionService* moduleActionService_;
  BabelModulePageRenderer* modulePageRenderer_;
  BabelModuleUpdateService* moduleUpdateService_;
  BabelInternalPageRenderer* internalPageRenderer_;
}

- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService
                         modulePageRenderer:(BabelModulePageRenderer*)modulePageRenderer
                        moduleUpdateService:(BabelModuleUpdateService*)moduleUpdateService
                       internalPageRenderer:(BabelInternalPageRenderer*)internalPageRenderer {
  self = [super init];
  if (self) {
    moduleActionService_ = moduleActionService;
    modulePageRenderer_ = modulePageRenderer;
    moduleUpdateService_ = moduleUpdateService;
    internalPageRenderer_ = internalPageRenderer;
  }

  return self;
}

- (NSString*)modulesPageHTML {
  NSError* error = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* body = [modulePageRenderer_ modulesPageBodyWithModules:modules
                                                             error:error
                                                   updateURLString:[moduleUpdateService_ updateURLString]
                                              updateLocalDirectory:[moduleUpdateService_ localDirectoryPath]];
  return [internalPageRenderer_ internalPageHTMLWithTitle:@"Modules" body:body];
}

- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSError* error = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* body = [modulePageRenderer_ moduleDetailsPageBodyForIdentifier:moduleIdentifier
                                                                    modules:modules
                                                                      error:error];
  NSString* pageTitle = moduleIdentifier.length > 0 ? moduleIdentifier : @"Module";
  return [internalPageRenderer_ internalPageHTMLWithTitle:pageTitle body:body];
}

- (NSString*)moduleUpdatesPageHTML {
  NSDictionary* updateResult = [moduleUpdateService_ releaseManifestResult];
  NSDictionary* manifest = [updateResult[@"manifest"] isKindOfClass:NSDictionary.class]
      ? updateResult[@"manifest"]
      : @{};
  NSArray* releaseModules = [manifest[@"modules"] isKindOfClass:NSArray.class] ? manifest[@"modules"] : @[];
  NSDictionary* releaseModulesByIdentifier =
      [moduleUpdateService_ releaseModulesByIdentifier:releaseModules];

  NSError* snapshotError = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&snapshotError];
  NSArray* installedModules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];

  NSString* body = [modulePageRenderer_ moduleUpdatesPageBodyWithUpdateResult:updateResult
                                                   releaseModulesByIdentifier:releaseModulesByIdentifier
                                                             installedModules:installedModules
                                                                snapshotError:snapshotError
                                                              updateURLString:[moduleUpdateService_ updateURLString]
                                                               localDirectory:[moduleUpdateService_ localDirectoryPath]];
  return [internalPageRenderer_ internalPageHTMLWithTitle:@"Module Updates" body:body];
}

@end
