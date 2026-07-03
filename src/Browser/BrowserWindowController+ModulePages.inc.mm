// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSString*)modulesPageHTML {
  NSError* error = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* body = [modulePageRenderer_ modulesPageBodyWithModules:modules
                                                             error:error
                                                   updateURLString:[moduleUpdateService_ updateURLString]
                                              updateLocalDirectory:[moduleUpdateService_ localDirectoryPath]];
  return [self internalPageHTMLWithTitle:@"Modules" body:body];
}

- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSError* error = nil;
  NSDictionary* snapshot = [moduleActionService_ modulesSnapshotWithError:&error];
  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  NSString* body = [modulePageRenderer_ moduleDetailsPageBodyForIdentifier:moduleIdentifier
                                                                    modules:modules
                                                                      error:error];
  NSString* pageTitle = moduleIdentifier.length > 0 ? moduleIdentifier : @"Module";
  return [self internalPageHTMLWithTitle:pageTitle body:body];
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
  return [self internalPageHTMLWithTitle:@"Module Updates" body:body];
}
