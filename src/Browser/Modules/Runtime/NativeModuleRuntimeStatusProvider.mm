#import "Browser/Modules/Runtime/NativeModuleRuntimeStatusProvider.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeDefinition.h"
#import "Browser/Modules/Runtime/NativeModuleProcessWebDefinition.h"
#import "Browser/Modules/Runtime/NativeModuleRuntimeCommand.h"

@implementation BabelNativeModuleRuntimeStatusProvider

- (NSDictionary*)runtimeStatusForModule:(BabelNativeModuleManifest*)module {
  if (!module) {
    return @{
      @"kind" : @"unknown",
      @"state" : @"unavailable",
      @"running" : @NO,
      @"restartable" : @NO,
      @"source" : @"native"
    };
  }

  if ([module.runtimeType isEqualToString:@"process-web"]) {
    return [self processWebStatusForModule:module];
  }

  if ([module.runtimeType isEqualToString:@"process-runtime"]) {
    return [self processRuntimeStatusForModule:module];
  }

  return @{
    @"kind" : module.runtimeType.length > 0 ? module.runtimeType : @"unknown",
    @"state" : @"static",
    @"running" : @NO,
    @"restartable" : @NO,
    @"source" : @"native"
  };
}

- (NSDictionary*)processWebStatusForModule:(BabelNativeModuleManifest*)module {
  BabelNativeModuleProcessWebDefinition* definition = module.processWeb;
  if (!definition) {
    return [self unavailableStatusWithKind:@"process-web"
                                   message:@"Module does not declare a process-web runtime."];
  }

  return @{
    @"kind" : @"process-web",
    @"state" : @"stopped",
    @"running" : @NO,
    @"restartable" : @YES,
    @"command" : [definition commandLine],
    @"cwd" : definition.cwd,
    @"readyUrl" : definition.readyUrl,
    @"logs" : @"",
    @"source" : @"native"
  };
}

- (NSDictionary*)processRuntimeStatusForModule:(BabelNativeModuleManifest*)module {
  BabelNativeModuleProcessRuntimeDefinition* definition = module.processRuntime;
  if (!definition) {
    return [self unavailableStatusWithKind:@"process-runtime"
                                   message:@"Module does not declare a process-runtime definition."];
  }

  return @{
    @"kind" : @"process-runtime",
    @"mode" : definition.mode,
    @"state" : @"idle",
    @"running" : @NO,
    @"restartable" : @NO,
    @"command" : [[definition commandForRoute:@""] commandLine],
    @"cwd" : definition.cwd,
    @"logs" : @"",
    @"source" : @"native"
  };
}

- (NSDictionary*)unavailableStatusWithKind:(NSString*)kind message:(NSString*)message {
  return @{
    @"kind" : kind,
    @"state" : @"unavailable",
    @"running" : @NO,
    @"restartable" : @NO,
    @"messages" : @[ message ?: @"" ],
    @"source" : @"native"
  };
}

@end
