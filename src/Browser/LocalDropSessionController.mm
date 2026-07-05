#import "Browser/LocalDropSessionController.h"

#import "Browser/BrowserModels.h"
#import "Browser/LocalDropBridgeScriptBuilder.h"
#import "Browser/LocalDropCoordinator.h"
#import "Browser/LocalDropLogWriter.h"
#import "Browser/LocalDropPayloadBuilder.h"
#import "Browser/LocalDropSupportResolver.h"

@implementation BabelLocalDropSessionController {
  BabelLocalDropCoordinator* coordinator_;
  BabelLocalDropBridgeScriptBuilder* bridgeScriptBuilder_;
  BabelLocalDropLogWriter* logWriter_;
  BabelLocalDropPayloadBuilder* payloadBuilder_;
  BabelLocalDropSupportResolver* supportResolver_;
  BabelLocalDropBrowserTabProvider browserTabProvider_;
  BabelLocalDropCurrentURLProvider currentURLProvider_;
}

- (instancetype)initWithCoordinator:(BabelLocalDropCoordinator*)coordinator
                bridgeScriptBuilder:(BabelLocalDropBridgeScriptBuilder*)bridgeScriptBuilder
                          logWriter:(BabelLocalDropLogWriter*)logWriter
                     payloadBuilder:(BabelLocalDropPayloadBuilder*)payloadBuilder
                    supportResolver:(BabelLocalDropSupportResolver*)supportResolver
                 browserTabProvider:(BabelLocalDropBrowserTabProvider)browserTabProvider
                 currentURLProvider:(BabelLocalDropCurrentURLProvider)currentURLProvider {
  self = [super init];
  if (self) {
    coordinator_ = coordinator;
    bridgeScriptBuilder_ = bridgeScriptBuilder;
    logWriter_ = logWriter;
    payloadBuilder_ = payloadBuilder;
    supportResolver_ = supportResolver;
    browserTabProvider_ = [browserTabProvider copy];
    currentURLProvider_ = [currentURLProvider copy];
  }
  return self;
}

- (void)didReceiveLocalDragPaths:(NSArray<NSString*>*)paths
                         browser:(CefRefPtr<CefBrowser>)browser
                     selectedTab:(BabelBrowserTab*)selectedTab {
  [self appendLogLine:[NSString stringWithFormat:@"CEF drag enter paths=%@", paths ?: @[]]];
  if (!browser || paths.count == 0) {
    return;
  }

  BabelBrowserTab* tab = browserTabProvider_ ? browserTabProvider_(browser) : nil;
  BOOL browserURLSupportsDrop =
      [supportResolver_ URLStringSupportsLocalDropPaths:[self currentURLStringForBrowser:browser]];
  if (!tab && selectedTab && [self tabSupportsLocalDropPaths:selectedTab]) {
    tab = selectedTab;
    [self appendLogLine:[NSString stringWithFormat:
        @"CEF drag enter used selected tab fallback requestedURL=%@",
        tab.requestedURLString ?: tab.urlString ?: @""]];
  }
  if ((!tab || ![self tabSupportsLocalDropPaths:tab]) && !browserURLSupportsDrop) {
    [self appendLogLine:@"CEF drag enter ignored because no drop-aware tab was found."];
    return;
  }

  [self markPendingLocalDropForBrowser:browser];

  NSString* payloadJSON = [payloadBuilder_ payloadJSONForLocalPaths:paths];
  if (payloadJSON.length == 0) {
    return;
  }

  [self installLocalDropBridgeForBrowser:browser payloadJSON:payloadJSON];
}

- (BOOL)tabSupportsLocalDropPaths:(BabelBrowserTab*)tab {
  if (!tab) {
    return NO;
  }

  if ([supportResolver_ URLStringSupportsLocalDropPaths:tab.requestedURLString]) {
    return YES;
  }

  return [supportResolver_ URLStringSupportsLocalDropPaths:tab.urlString];
}

- (void)browserDidFinishLoading:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return;
  }

  BabelBrowserTab* tab = browserTabProvider_ ? browserTabProvider_(browser) : nil;
  if (!tab || ![self tabSupportsLocalDropPaths:tab]) {
    if (tab) {
      [self appendLogLine:[NSString stringWithFormat:
          @"Load end did not install local drop bridge for requestedURL=%@",
          tab.requestedURLString ?: tab.urlString ?: @""]];
    }
    return;
  }

  [self appendLogLine:[NSString stringWithFormat:
      @"Load end installing local drop bridge for requestedURL=%@",
      tab.requestedURLString ?: tab.urlString ?: @""]];
  [self installLocalDropBridgeForBrowser:browser payloadJSON:nil];
}

- (BOOL)shouldSuppressLocalFileNavigationForBrowser:(CefRefPtr<CefBrowser>)browser
                                       selectedTab:(BabelBrowserTab*)selectedTab {
  if (!browser) {
    return NO;
  }

  BabelBrowserTab* tab = browserTabProvider_ ? browserTabProvider_(browser) : nil;
  BOOL tabSupportsDrop = tab && [self tabSupportsLocalDropPaths:tab];
  BOOL browserHasPendingDrop = [self hasPendingLocalDropForBrowser:browser];
  BOOL selectedTabSupportsDrop = selectedTab && [self tabSupportsLocalDropPaths:selectedTab];
  BOOL currentURLSupportsDrop =
      [supportResolver_ URLStringSupportsLocalDropPaths:[self currentURLStringForBrowser:browser]];
  BOOL shouldSuppress = tabSupportsDrop || browserHasPendingDrop || selectedTabSupportsDrop || currentURLSupportsDrop;
  [self appendLogLine:[NSString stringWithFormat:
      @"CEF file navigation suppression requestedURL=%@ tabSupports=%@ pendingDrop=%@ selectedSupports=%@ currentSupports=%@ suppress=%@",
      tab.requestedURLString ?: tab.urlString ?: @"",
      tabSupportsDrop ? @"YES" : @"NO",
      browserHasPendingDrop ? @"YES" : @"NO",
      selectedTabSupportsDrop ? @"YES" : @"NO",
      currentURLSupportsDrop ? @"YES" : @"NO",
      shouldSuppress ? @"YES" : @"NO"]];
  if (shouldSuppress) {
    [self clearPendingLocalDropForBrowser:browser];
  }
  return shouldSuppress;
}

- (void)appendLogLine:(NSString*)line {
  [logWriter_ appendLine:line];
}

- (NSString*)currentURLStringForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (currentURLProvider_) {
    return currentURLProvider_(browser);
  }

  if (!browser || !browser->GetMainFrame()) {
    return @"";
  }

  return [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()];
}

- (NSNumber*)browserIdentifierForBrowser:(CefRefPtr<CefBrowser>)browser {
  if (!browser) {
    return nil;
  }

  return @(browser->GetIdentifier());
}

- (void)markPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  if (!browserIdentifier) {
    return;
  }

  [coordinator_ markPendingLocalDropForBrowserIdentifier:browserIdentifier];
  [self appendLogLine:[NSString stringWithFormat:
      @"Marked pending local drop for browser=%@",
      browserIdentifier]];
}

- (BOOL)hasPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  if (!browserIdentifier) {
    return NO;
  }

  return [coordinator_ hasPendingLocalDropForBrowserIdentifier:browserIdentifier];
}

- (void)clearPendingLocalDropForBrowser:(CefRefPtr<CefBrowser>)browser {
  NSNumber* browserIdentifier = [self browserIdentifierForBrowser:browser];
  [coordinator_ clearPendingLocalDropForBrowserIdentifier:browserIdentifier];
}

- (void)installLocalDropBridgeForBrowser:(CefRefPtr<CefBrowser>)browser payloadJSON:(NSString*)payloadJSON {
  if (!browser) {
    return;
  }

  NSString* script = [bridgeScriptBuilder_ scriptWithPayloadJSON:payloadJSON];
  browser->GetMainFrame()->ExecuteJavaScript(std::string(script.UTF8String),
                                             "babelchrome://local-drop-bridge",
                                             0);
}

@end
