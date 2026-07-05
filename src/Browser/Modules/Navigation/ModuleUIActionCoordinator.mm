#import "Browser/Modules/Navigation/ModuleUIActionCoordinator.h"

#import <AppKit/AppKit.h>

#import "Browser/Modules/Core/ModuleActionService.h"
#import "Browser/Modules/Updates/ModuleUpdateService.h"

@implementation BabelModuleUIActionCoordinator {
  BabelModuleActionService* moduleActionService_;
  BabelModuleUpdateService* moduleUpdateService_;
}

- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService
                        moduleUpdateService:(BabelModuleUpdateService*)moduleUpdateService {
  self = [super init];
  if (self) {
    moduleActionService_ = moduleActionService;
    moduleUpdateService_ = moduleUpdateService;
  }
  return self;
}

- (BOOL)installPHPModuleZipFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = YES;
  panel.title = @"Install PHP Modules";
  if ([panel runModal] != NSModalResponseOK) {
    return NO;
  }

  BOOL didInstallAtLeastOneModule = NO;
  NSMutableArray<NSString*>* errors = [NSMutableArray array];
  for (NSURL* url in panel.URLs) {
    if (![url.pathExtension.lowercaseString isEqualToString:@"zip"]) {
      [errors addObject:[NSString stringWithFormat:@"%@: selected package must be a zip archive.",
                                                   url.lastPathComponent ?: url.path ?: @"Unknown file"]];
      continue;
    }

    NSError* error = nil;
    if (![moduleActionService_ installModuleZipAtPath:url.path error:&error]) {
      NSString* message = error.localizedDescription ?: @"The module operation failed.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@",
                                                   url.lastPathComponent ?: url.path ?: @"Unknown file",
                                                   message]];
      continue;
    }

    didInstallAtLeastOneModule = YES;
  }

  if (errors.count > 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:1
                        userInfo:@{
                          NSLocalizedDescriptionKey : [errors componentsJoinedByString:@"\n"]
                        }]];
  }

  return didInstallAtLeastOneModule;
}

- (BOOL)setPHPModuleWithIdentifier:(NSString*)moduleIdentifier enabled:(BOOL)enabled {
  NSError* error = nil;
  if (![moduleActionService_ setModuleWithIdentifier:moduleIdentifier enabled:enabled error:&error]) {
    [self showModuleActionAlertWithError:error];
    return NO;
  }

  return YES;
}

- (BOOL)removePHPModuleWithIdentifier:(NSString*)moduleIdentifier {
  NSAlert* confirmation = [[NSAlert alloc] init];
  confirmation.messageText = @"Remove PHP Module";
  confirmation.informativeText =
      [NSString stringWithFormat:@"Remove module \"%@\" from BabelChrome?", moduleIdentifier ?: @""];
  [confirmation addButtonWithTitle:@"Remove"];
  [confirmation addButtonWithTitle:@"Cancel"];
  confirmation.alertStyle = NSAlertStyleWarning;
  if ([confirmation runModal] != NSAlertFirstButtonReturn) {
    return NO;
  }

  NSError* error = nil;
  if (![moduleActionService_ removeModuleWithIdentifier:moduleIdentifier error:&error]) {
    [self showModuleActionAlertWithError:error];
    return NO;
  }

  return YES;
}

- (void)configureModuleUpdateURLFromPrompt {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Module Update URL";
  alert.informativeText =
      @"Enter either the direct modules-release-manifest.json URL or a base URL containing that file.";
  [alert addButtonWithTitle:@"Save"];
  [alert addButtonWithTitle:@"Cancel"];
  NSTextField* textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 520, 28)];
  textField.stringValue = [moduleUpdateService_ updateURLString];
  alert.accessoryView = textField;
  if ([alert runModal] != NSAlertFirstButtonReturn) {
    return;
  }

  [moduleUpdateService_ setUpdateURLString:textField.stringValue];
}

- (void)configureModuleUpdateLocalDirectoryFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = NO;
  panel.canChooseDirectories = YES;
  panel.allowsMultipleSelection = NO;
  panel.title = @"Choose Module Update Folder";
  NSString* currentPath = [moduleUpdateService_ localDirectoryPath];
  if (currentPath.length > 0) {
    panel.directoryURL = [NSURL fileURLWithPath:currentPath];
  }
  if ([panel runModal] != NSModalResponseOK) {
    return;
  }

  NSString* path = panel.URL.path ?: @"";
  if (path.length == 0) {
    return;
  }

  [moduleUpdateService_ setLocalDirectoryPath:path];
}

- (BOOL)installPHPModuleUpdateWithIdentifier:(NSString*)moduleIdentifier {
  return [self installPHPModuleUpdatesWithIdentifiers:moduleIdentifier.length > 0 ? @[moduleIdentifier] : @[]];
}

- (BOOL)installPHPModuleUpdatesWithIdentifiers:(NSArray<NSString*>*)moduleIdentifiers {
  if (moduleIdentifiers.count == 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:1
                        userInfo:@{NSLocalizedDescriptionKey : @"Select at least one module update to install."}]];
    return NO;
  }

  NSDictionary* updateResult = [moduleUpdateService_ releaseManifestResult];
  BOOL didInstallAtLeastOneModule = NO;
  NSMutableSet<NSString*>* seenModuleIdentifiers = [NSMutableSet set];
  NSMutableArray<NSString*>* errors = [NSMutableArray array];

  for (NSString* moduleIdentifier in moduleIdentifiers) {
    NSString* trimmedModuleIdentifier =
        [moduleIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedModuleIdentifier.length == 0 || [seenModuleIdentifiers containsObject:trimmedModuleIdentifier]) {
      continue;
    }
    [seenModuleIdentifiers addObject:trimmedModuleIdentifier];

    NSDictionary* releaseModule = [moduleUpdateService_ releaseModuleWithIdentifier:trimmedModuleIdentifier
                                                                       updateResult:updateResult];
    if (!releaseModule) {
      [errors addObject:[NSString stringWithFormat:@"%@: update was not found.", trimmedModuleIdentifier]];
      continue;
    }

    NSError* error = nil;
    NSString* zipPath = [moduleUpdateService_ resolvedUpdateZipPathForReleaseModule:releaseModule
                                                                       updateResult:updateResult
                                                                              error:&error];
    if (zipPath.length == 0) {
      NSString* message = error.localizedDescription ?: @"Unable to resolve the update zip.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@", trimmedModuleIdentifier, message]];
      continue;
    }

    if (![moduleActionService_ installModuleZipAtPath:zipPath error:&error]) {
      NSString* message = error.localizedDescription ?: @"The module operation failed.";
      [errors addObject:[NSString stringWithFormat:@"%@: %@", trimmedModuleIdentifier, message]];
      continue;
    }

    didInstallAtLeastOneModule = YES;
  }

  if (errors.count > 0) {
    [self showModuleActionAlertWithError:
        [NSError errorWithDomain:@"fr.babelforge.babel-chrome.modules"
                            code:2
                        userInfo:@{NSLocalizedDescriptionKey : [errors componentsJoinedByString:@"\n"]}]];
  }

  return didInstallAtLeastOneModule;
}

- (void)showModuleActionAlertWithError:(NSError*)error {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Unable to Manage PHP Module";
  alert.informativeText = error.localizedDescription ?: @"The module operation failed.";
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
}

@end
