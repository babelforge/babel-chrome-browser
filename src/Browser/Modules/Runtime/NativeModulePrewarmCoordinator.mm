#import "Browser/Modules/Runtime/NativeModulePrewarmCoordinator.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeManager.h"

@implementation BabelNativeModulePrewarmCoordinator {
  BabelNativeModuleProcessRuntimeManager* runtimeManager_;
  dispatch_queue_t prewarmQueue_;
  NSMutableDictionary<NSString*, NSDictionary*>* statusesByIdentifier_;
  NSMutableSet<NSString*>* scheduledIdentifiers_;
}

- (instancetype)initWithRuntimeManager:(BabelNativeModuleProcessRuntimeManager*)runtimeManager {
  self = [super init];
  if (self) {
    runtimeManager_ = runtimeManager;
    prewarmQueue_ = dispatch_queue_create("fr.babelforge.babel-chrome.module-prewarm",
                                          DISPATCH_QUEUE_SERIAL);
    statusesByIdentifier_ = [NSMutableDictionary dictionary];
    scheduledIdentifiers_ = [NSMutableSet set];
  }

  return self;
}

- (NSDictionary*)prewarmModule:(BabelNativeModuleManifest*)module error:(NSError**)error {
  NSString* moduleIdentifier = module.moduleIdentifier ?: @"";
  if (moduleIdentifier.length == 0 || !module.enabled ||
      ![module.runtimeType isEqualToString:@"process-web"]) {
    return nil;
  }

  [self setPrewarmStatus:@{
    @"state" : @"prewarming",
    @"moduleIdentifier" : moduleIdentifier
  } moduleIdentifier:moduleIdentifier];

  NSError* startError = nil;
  NSDictionary* runtimeStatus = [runtimeManager_ startProcessWebRuntimeIfNeededForModule:module
                                                                                   error:&startError];
  if (!runtimeStatus) {
    NSString* message = startError.localizedDescription ?: @"Module runtime prewarm failed.";
    [self setPrewarmStatus:@{
      @"state" : @"failed",
      @"moduleIdentifier" : moduleIdentifier,
      @"message" : message
    } moduleIdentifier:moduleIdentifier];
    if (error) {
      *error = startError;
    }
    return nil;
  }

  [self setPrewarmStatus:@{
    @"state" : @"ready",
    @"moduleIdentifier" : moduleIdentifier
  } moduleIdentifier:moduleIdentifier];
  return runtimeStatus;
}

- (void)schedulePrewarmModules:(NSArray<BabelNativeModuleManifest*>*)modules
           excludingIdentifiers:(NSSet<NSString*>*)excludedIdentifiers {
  NSMutableArray<BabelNativeModuleManifest*>* modulesToSchedule = [NSMutableArray array];
  @synchronized(self) {
    for (BabelNativeModuleManifest* module in modules ?: @[]) {
      NSString* moduleIdentifier = module.moduleIdentifier ?: @"";
      if (moduleIdentifier.length == 0 ||
          [excludedIdentifiers containsObject:moduleIdentifier] ||
          [scheduledIdentifiers_ containsObject:moduleIdentifier]) {
        continue;
      }

      [scheduledIdentifiers_ addObject:moduleIdentifier];
      [modulesToSchedule addObject:module];
    }
  }

  if (modulesToSchedule.count == 0) {
    return;
  }

  dispatch_async(prewarmQueue_, ^{
    for (BabelNativeModuleManifest* module in modulesToSchedule) {
      @autoreleasepool {
        NSError* error = nil;
        [self prewarmModule:module error:&error];
        if (error) {
          NSLog(@"BabelChrome module prewarm failed for %@: %@",
                module.moduleIdentifier ?: @"",
                error.localizedDescription ?: @"unknown error");
        }
      }
    }
  });
}

- (NSDictionary*)prewarmStatusForModuleIdentifier:(NSString*)moduleIdentifier {
  if (moduleIdentifier.length == 0) {
    return nil;
  }

  @synchronized(self) {
    return statusesByIdentifier_[moduleIdentifier];
  }
}

- (void)setPrewarmStatus:(NSDictionary*)status moduleIdentifier:(NSString*)moduleIdentifier {
  if (moduleIdentifier.length == 0 || !status) {
    return;
  }

  @synchronized(self) {
    statusesByIdentifier_[moduleIdentifier] = status;
  }
}

@end
