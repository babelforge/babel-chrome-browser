#import "Browser/Extensions/Install/ExtensionFolderController.h"

#import "Browser/Extensions/Profile/ExtensionProfileStore.h"

#import <Cocoa/Cocoa.h>

@implementation BabelExtensionFolderController {
  BabelExtensionProfileStore* extensionProfileStore_;
}

- (instancetype)initWithExtensionProfileStore:(BabelExtensionProfileStore*)extensionProfileStore {
  self = [super init];
  if (self) {
    extensionProfileStore_ = extensionProfileStore;
  }
  return self;
}

- (void)addUnpackedExtensionFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = NO;
  panel.canChooseDirectories = YES;
  panel.allowsMultipleSelection = NO;
  panel.prompt = @"Add";
  panel.message = @"Choose an unpacked Chrome extension folder containing manifest.json.";

  if ([panel runModal] != NSModalResponseOK) {
    return;
  }

  NSString* extensionPath = panel.URL.path;
  NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
  if (![NSFileManager.defaultManager fileExistsAtPath:manifestPath]) {
    [self showMissingManifestAlertForExtensionPath:extensionPath];
    return;
  }

  NSMutableArray<NSString*>* extensionPaths =
      [[extensionProfileStore_ installedExtensionPaths] mutableCopy];
  if (![extensionPaths containsObject:extensionPath]) {
    [extensionPaths addObject:extensionPath];
  }
  [extensionProfileStore_ saveInstalledExtensionPaths:extensionPaths];
}

- (void)showMissingManifestAlertForExtensionPath:(NSString*)extensionPath {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Invalid Extension Folder";
  alert.informativeText = [NSString stringWithFormat:@"The selected folder does not contain manifest.json:\n%@",
                                                     extensionPath ?: @""];
  alert.alertStyle = NSAlertStyleWarning;
  [alert runModal];
}

@end
