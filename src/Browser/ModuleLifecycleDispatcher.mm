#import "Browser/ModuleLifecycleDispatcher.h"

#import "Browser/ProjectLifecycleResponseParser.h"
#import "LocalServices/LocalServiceHost.h"

@implementation BabelModuleLifecycleDispatcher {
  BabelProjectLifecycleResponseParser* projectLifecycleResponseParser_;
}

- (instancetype)initWithProjectLifecycleResponseParser:
    (BabelProjectLifecycleResponseParser*)projectLifecycleResponseParser {
  self = [super init];
  if (self) {
    projectLifecycleResponseParser_ = projectLifecycleResponseParser;
  }
  return self;
}

- (void)dispatchApplicationDidStartWithRestoredProjectsHandler:
    (BabelModuleLifecycleRestoredProjectsHandler)handler {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    NSError* error = nil;
    NSDictionary* response =
        [BabelLocalServiceHost.sharedHost dispatchModuleLifecycleHook:@"app.did-start" error:&error];
    if (error) {
      NSLog(@"BabelChrome module lifecycle app.did-start failed: %@", error.localizedDescription);
    }

    NSArray<NSString*>* restoredProjectIdentifiers =
        [projectLifecycleResponseParser_ restoredProjectIdentifiersFromLifecycleResponse:response];
    if (restoredProjectIdentifiers.count == 0 || !handler) {
      return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      handler(restoredProjectIdentifiers);
    });
  });
}

- (void)dispatchApplicationWillQuit {
  NSError* error = nil;
  [BabelLocalServiceHost.sharedHost dispatchModuleLifecycleHook:@"app.will-quit" error:&error];
  if (error) {
    NSLog(@"BabelChrome module lifecycle app.will-quit failed: %@", error.localizedDescription);
  }
}

@end
