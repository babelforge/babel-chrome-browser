#import "Browser/Modules/Lifecycle/ModuleLifecycleDispatcher.h"

#import "Browser/Modules/Core/ModuleActionService.h"
#import "Browser/Modules/Lifecycle/ProjectLifecycleResponseParser.h"

@implementation BabelModuleLifecycleDispatcher {
  BabelModuleActionService* moduleActionService_;
  BabelProjectLifecycleResponseParser* projectLifecycleResponseParser_;
}

- (instancetype)initWithModuleActionService:(BabelModuleActionService*)moduleActionService
             projectLifecycleResponseParser:
    (BabelProjectLifecycleResponseParser*)projectLifecycleResponseParser {
  self = [super init];
  if (self) {
    moduleActionService_ = moduleActionService;
    projectLifecycleResponseParser_ = projectLifecycleResponseParser;
  }
  return self;
}

- (void)dispatchApplicationDidStartWithRestoredProjectsHandler:
    (BabelModuleLifecycleRestoredProjectsHandler)handler {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    NSError* error = nil;
    NSDictionary* response =
        [moduleActionService_ dispatchModuleLifecycleHook:@"app.did-start" error:&error];
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
  [moduleActionService_ dispatchModuleLifecycleHook:@"app.will-quit" error:&error];
  if (error) {
    NSLog(@"BabelChrome module lifecycle app.will-quit failed: %@", error.localizedDescription);
  }
}

@end
