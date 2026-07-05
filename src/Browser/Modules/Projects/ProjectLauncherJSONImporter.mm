#import "Browser/Modules/Projects/ProjectLauncherJSONImporter.h"

#import "LocalServices/LocalServiceHost.h"

#import <Cocoa/Cocoa.h>

static NSString* const kProjectLauncherModuleIdentifier = @"babelforge.project-launcher";

@implementation BabelProjectLauncherJSONImporter {
  BabelProjectLauncherImportLogHandler logHandler_;
}

- (instancetype)initWithLogHandler:(BabelProjectLauncherImportLogHandler)logHandler {
  self = [super init];
  if (self) {
    logHandler_ = [logHandler copy];
  }
  return self;
}

- (NSURL*)projectLauncherImportURLFromPanel {
  NSOpenPanel* panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = NO;
  panel.title = @"Load Project Launcher JSON";
  if ([panel runModal] != NSModalResponseOK) {
    [self logLine:@"Project Launcher JSON panel cancelled."];
    return nil;
  }

  NSString* path = panel.URL.path ?: @"";
  if (![path.pathExtension.lowercaseString isEqualToString:@"json"]) {
    [self logLine:[NSString stringWithFormat:@"Project Launcher JSON panel rejected path=%@", path]];
    [self showInvalidProjectConfigurationAlert];
    return nil;
  }

  [self logLine:[NSString stringWithFormat:@"Project Launcher JSON panel selected path=%@", path]];
  NSURL* moduleURL = [BabelLocalServiceHost.sharedHost moduleURLForIdentifier:kProjectLauncherModuleIdentifier
                                                                       route:@"index"
                                                             sourceURLString:nil
                                                                       error:nil];
  if (!moduleURL || path.length == 0) {
    [self logLine:@"Project Launcher JSON panel could not build module URL."];
    return nil;
  }

  NSURLComponents* components = [NSURLComponents componentsWithURL:moduleURL resolvingAgainstBaseURL:NO];
  NSMutableArray<NSURLQueryItem*>* queryItems = [components.queryItems mutableCopy] ?: [NSMutableArray array];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"action" value:@"importPath"]];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"path" value:path]];
  components.queryItems = queryItems;
  return components.URL;
}

- (void)logLine:(NSString*)line {
  if (logHandler_) {
    logHandler_(line);
  }
}

- (void)showInvalidProjectConfigurationAlert {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.alertStyle = NSAlertStyleWarning;
  alert.messageText = @"Invalid Project Configuration";
  alert.informativeText = @"Please select a JSON project configuration file.";
  [alert runModal];
}

@end
