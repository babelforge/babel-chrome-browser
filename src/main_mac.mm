#import <Cocoa/Cocoa.h>

#include <filesystem>
#include <string>

#include "App/ApplicationDelegate.h"
#include "Configuration/Configuration.h"
#include "Startup/ProfileExtensionStartupSynchronizer.h"
#include "include/cef_application_mac.h"
#include "include/cef_app.h"
#include "include/cef_command_line.h"
#include "include/cef_version.h"
#include "include/wrapper/cef_helpers.h"
#include "include/wrapper/cef_library_loader.h"

/**
 * NSApplication subclass required by CEF on macOS.
 */
@interface BabelApplication : NSApplication <CefAppProtocol> {
 @private
  BOOL handlingSendEvent_;
}
@end

@implementation BabelApplication

- (BOOL)isHandlingSendEvent {
  return handlingSendEvent_;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  handlingSendEvent_ = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
  CefScopedSendingEvent sendingEventScoper;
  [super sendEvent:event];
}

- (void)terminate:(id)sender {
  BabelApplicationDelegate* delegate =
      static_cast<BabelApplicationDelegate*>([NSApp delegate]);
  [delegate tryToTerminateApplication];
}

@end

/**
 * Builds the Chromium extension switch value from persisted unpacked extension paths.
 *
 * @return A comma-separated extension path list.
 */
static NSString* InstalledExtensionSwitchValue() {
  NSArray* extensionPaths =
      [NSUserDefaults.standardUserDefaults arrayForKey:BabelChromeConfiguration.extensionPathsDefaultsKey];
  if (![extensionPaths isKindOfClass:NSArray.class] || extensionPaths.count == 0) {
    return @"";
  }

  NSMutableArray<NSString*>* validPaths = [NSMutableArray array];
  NSFileManager* fileManager = NSFileManager.defaultManager;
  for (NSString* extensionPath in extensionPaths) {
    if (![extensionPath isKindOfClass:NSString.class] || extensionPath.length == 0) {
      continue;
    }

    NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:extensionPath isDirectory:&isDirectory] &&
        isDirectory &&
        [fileManager fileExistsAtPath:manifestPath]) {
      [validPaths addObject:extensionPath];
    }
  }

  return [validPaths componentsJoinedByString:@","];
}

/**
 * Supplies Chromium process command-line switches for BabelChrome.
 */
class BabelCefApp final : public CefApp {
 public:
  /**
   * Adds startup switches before Chromium creates browser processes.
   *
   * @param process_type The Chromium process type being configured.
   * @param command_line The mutable Chromium command line.
   */
  void OnBeforeCommandLineProcessing(const CefString& process_type,
                                     CefRefPtr<CefCommandLine> command_line) override {
    command_line->AppendSwitchWithValue("remote-allow-origins", "*");
    command_line->AppendSwitchWithValue(
        "disk-cache-dir",
        std::string(BabelChromeConfiguration.diskCacheRootDirectoryURL.path.UTF8String));
    command_line->AppendSwitchWithValue(
        "disk-cache-size",
        std::string(BabelChromeConfiguration.httpDiskCacheSizeBytes.UTF8String));
    command_line->AppendSwitchWithValue(
        "media-cache-size",
        std::string(BabelChromeConfiguration.mediaDiskCacheSizeBytes.UTF8String));

    if (process_type.empty()) {
      NSString* extensionSwitchValue = InstalledExtensionSwitchValue();
      if (extensionSwitchValue.length > 0) {
        command_line->AppendSwitchWithValue("load-extension",
                                            std::string(extensionSwitchValue.UTF8String));
      }
    }
  }

 private:
  IMPLEMENT_REFCOUNTING(BabelCefApp);
};

/**
 * Ensures that a directory exists before CEF starts.
 *
 * @param directoryURL The directory URL to create.
 * @return YES when the directory exists or was created.
 */
static BOOL EnsureDirectoryExists(NSURL* directoryURL) {
  NSError* error = nil;
  BOOL created = [NSFileManager.defaultManager createDirectoryAtURL:directoryURL
                                        withIntermediateDirectories:YES
                                                         attributes:nil
                                                              error:&error];
  if (created) {
    return YES;
  }

  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Unable to create BabelChrome profile";
  alert.informativeText = error.localizedDescription ?: directoryURL.path;
  alert.alertStyle = NSAlertStyleCritical;
  [alert runModal];
  return NO;
}

/**
 * Configures global CEF settings.
 *
 * @param settings The CEF settings structure to configure.
 */
static void ConfigureCefSettings(CefSettings& settings) {
#if !defined(CEF_USE_SANDBOX)
  settings.no_sandbox = true;
#endif

  NSURL* profileURL = BabelChromeConfiguration.profileDirectoryURL;
  CefString(&settings.cache_path) = std::string(profileURL.path.UTF8String);
  CefString(&settings.root_cache_path) = std::string(profileURL.path.UTF8String);
  settings.persist_session_cookies = true;
  settings.external_message_pump = false;
  settings.remote_debugging_port = BabelChromeConfiguration.remoteDebuggingPort;
  std::string chromeVersion = std::to_string(CHROME_VERSION_MAJOR) + "." +
                              std::to_string(CHROME_VERSION_MINOR) + "." +
                              std::to_string(CHROME_VERSION_BUILD) + "." +
                              std::to_string(CHROME_VERSION_PATCH);
  CefString(&settings.user_agent) =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/" +
      chromeVersion + " Safari/537.36 BabelChrome/1.0";
}

/**
 * Application entry point for the CEF browser process.
 *
 * @param argc The command-line argument count.
 * @param argv The command-line arguments.
 * @return The application exit code.
 */
int main(int argc, char* argv[]) {
  CefScopedLibraryLoader libraryLoader;
  if (!libraryLoader.LoadInMain()) {
    return 1;
  }

  CefMainArgs mainArgs(argc, argv);
  CefRefPtr<BabelCefApp> cefApp = new BabelCefApp();

  @autoreleasepool {
    [BabelApplication sharedApplication];
    CHECK([NSApp isKindOfClass:[BabelApplication class]]);
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    if (!EnsureDirectoryExists(BabelChromeConfiguration.profileDirectoryURL)) {
      return 1;
    }
    if (!EnsureDirectoryExists(BabelChromeConfiguration.diskCacheRootDirectoryURL)) {
      return 1;
    }
    [BabelProfileExtensionStartupSynchronizer applyProfileExtensionPackageState];

    BabelApplicationDelegate* delegate = [[BabelApplicationDelegate alloc] init];
    NSApp.delegate = delegate;
    [NSApp finishLaunching];

    [delegate beginStartupEventCollection];
    [NSApp run];

    CefSettings settings;
    ConfigureCefSettings(settings);

    if (!CefInitialize(mainArgs, settings, cefApp, nullptr)) {
      NSAlert* alert = [[NSAlert alloc] init];
      alert.messageText = @"Unable to initialize CEF";
      alert.informativeText = @"BabelChrome could not start Chromium Embedded Framework.";
      alert.alertStyle = NSAlertStyleCritical;
      [alert runModal];
      return CefGetExitCode();
    }

    [delegate createBrowserWindow];

    CefRunMessageLoop();
    CefShutdown();

    delegate = nil;
  }

  return 0;
}
