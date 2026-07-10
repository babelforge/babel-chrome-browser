#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeManager.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeDefinition.h"
#import "Browser/Modules/Runtime/NativeModulePortAllocator.h"
#import "Browser/Modules/Runtime/NativeModuleProcessWebDefinition.h"
#import "Browser/Modules/Runtime/NativeModuleRuntimeCommand.h"
#import "Browser/Modules/Runtime/NativeModuleRuntimeStatusProvider.h"
#import "Browser/Modules/Settings/NativeModuleRequiredSettingsService.h"

#include <signal.h>
#include <unistd.h>

static NSString* const kBabelNativeModuleProcessRuntimeManagerErrorDomain =
    @"fr.babelforge.babel-chrome.native-module-process-runtime-manager";

@interface BabelNativeModuleProcessWebInstance : NSObject

@property(nonatomic, readonly, copy) NSString* moduleIdentifier;
@property(nonatomic, readonly) NSInteger port;
@property(nonatomic, readonly, copy) NSString* baseURL;
@property(nonatomic, readonly, copy) NSArray<NSString*>* command;
@property(nonatomic, readonly, copy) NSString* cwd;
@property(nonatomic, readonly, copy) NSDictionary<NSString*, NSString*>* environment;
@property(nonatomic, readonly, copy) NSString* readyURL;
@property(nonatomic, readonly, copy) NSString* stopSignal;
@property(nonatomic, readonly) NSInteger stopTimeoutMs;
@property(nonatomic, readonly, copy) NSString* startPolicy;

- (instancetype)initWithModuleIdentifier:(NSString*)moduleIdentifier
                                    port:(NSInteger)port
                                 baseURL:(NSString*)baseURL
                                 command:(NSArray<NSString*>*)command
                                     cwd:(NSString*)cwd
                             environment:(NSDictionary<NSString*, NSString*>*)environment
                                readyURL:(NSString*)readyURL
                              stopSignal:(NSString*)stopSignal
                           stopTimeoutMs:(NSInteger)stopTimeoutMs
                              startPolicy:(NSString*)startPolicy
                                    task:(NSTask*)task
                              stdoutPipe:(NSPipe*)stdoutPipe
                              stderrPipe:(NSPipe*)stderrPipe;
- (void)beginCapturingLogs;
- (BOOL)isRunning;
- (void)stop;
- (NSString*)logs;

@end

@implementation BabelNativeModuleProcessWebInstance {
  NSTask* task_;
  NSPipe* stdoutPipe_;
  NSPipe* stderrPipe_;
  NSMutableString* stdoutLog_;
  NSMutableString* stderrLog_;
}

@synthesize moduleIdentifier = _moduleIdentifier;
@synthesize port = _port;
@synthesize baseURL = _baseURL;
@synthesize command = _command;
@synthesize cwd = _cwd;
@synthesize environment = _environment;
@synthesize readyURL = _readyURL;
@synthesize stopSignal = _stopSignal;
@synthesize stopTimeoutMs = _stopTimeoutMs;
@synthesize startPolicy = _startPolicy;

- (instancetype)initWithModuleIdentifier:(NSString*)moduleIdentifier
                                    port:(NSInteger)port
                                 baseURL:(NSString*)baseURL
                                 command:(NSArray<NSString*>*)command
                                     cwd:(NSString*)cwd
                             environment:(NSDictionary<NSString*, NSString*>*)environment
                                readyURL:(NSString*)readyURL
                              stopSignal:(NSString*)stopSignal
                           stopTimeoutMs:(NSInteger)stopTimeoutMs
                              startPolicy:(NSString*)startPolicy
                                    task:(NSTask*)task
                              stdoutPipe:(NSPipe*)stdoutPipe
                              stderrPipe:(NSPipe*)stderrPipe {
  self = [super init];
  if (self) {
    _moduleIdentifier = [moduleIdentifier copy];
    _port = port;
    _baseURL = [baseURL copy];
    _command = [command copy];
    _cwd = [cwd copy];
    _environment = [environment copy];
    _readyURL = [readyURL copy];
    _stopSignal = [stopSignal copy];
    _stopTimeoutMs = stopTimeoutMs > 0 ? stopTimeoutMs : 3000;
    _startPolicy = [startPolicy copy];
    task_ = task;
    stdoutPipe_ = stdoutPipe;
    stderrPipe_ = stderrPipe;
    stdoutLog_ = [NSMutableString string];
    stderrLog_ = [NSMutableString string];
  }

  return self;
}

- (void)beginCapturingLogs {
  __weak BabelNativeModuleProcessWebInstance* weakSelf = self;
  stdoutPipe_.fileHandleForReading.readabilityHandler = ^(NSFileHandle* handle) {
    NSData* data = handle.availableData;
    if (data.length == 0) {
      handle.readabilityHandler = nil;
      return;
    }
    [weakSelf appendLogData:data stdout:YES];
  };
  stderrPipe_.fileHandleForReading.readabilityHandler = ^(NSFileHandle* handle) {
    NSData* data = handle.availableData;
    if (data.length == 0) {
      handle.readabilityHandler = nil;
      return;
    }
    [weakSelf appendLogData:data stdout:NO];
  };
}

- (BOOL)isRunning {
  return task_.running;
}

- (void)stop {
  if ([self isRunning]) {
    kill(task_.processIdentifier, [self signalNumber:self.stopSignal]);
    NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:self.stopTimeoutMs / 1000.0];
    while ([self isRunning] && [deadline timeIntervalSinceNow] > 0) {
      usleep(50000);
    }

    if ([self isRunning]) {
      kill(task_.processIdentifier, SIGKILL);
    }
  }

  if ([self isRunning]) {
    [task_ waitUntilExit];
  }

  [self closePipes];
}

- (NSString*)logs {
  @synchronized(self) {
    NSMutableArray<NSString*>* parts = [NSMutableArray array];
    NSString* stdoutTrimmed = [stdoutLog_ stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString* stderrTrimmed = [stderrLog_ stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (stdoutTrimmed.length > 0) {
      [parts addObject:[@"stdout: " stringByAppendingString:stdoutTrimmed]];
    }
    if (stderrTrimmed.length > 0) {
      [parts addObject:[@"stderr: " stringByAppendingString:stderrTrimmed]];
    }
    return [parts componentsJoinedByString:@"\n"];
  }
}

- (void)appendLogData:(NSData*)data stdout:(BOOL)stdout {
  if (data.length == 0) {
    return;
  }

  NSString* text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (!text) {
    text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding] ?: @"";
  }

  @synchronized(self) {
    NSMutableString* target = stdout ? stdoutLog_ : stderrLog_;
    [target appendString:text];
    if (target.length > 16384) {
      [target deleteCharactersInRange:NSMakeRange(0, target.length - 16384)];
    }
  }
}

- (void)closePipes {
  stdoutPipe_.fileHandleForReading.readabilityHandler = nil;
  stderrPipe_.fileHandleForReading.readabilityHandler = nil;
  @try {
    [stdoutPipe_.fileHandleForReading closeFile];
  } @catch (NSException* exception) {
    (void)exception;
  }
  @try {
    [stderrPipe_.fileHandleForReading closeFile];
  } @catch (NSException* exception) {
    (void)exception;
  }
}

- (int)signalNumber:(NSString*)signal {
  NSString* normalized = [[signal ?: @"TERM" uppercaseString] stringByReplacingOccurrencesOfString:@"SIG" withString:@""];
  if ([normalized isEqualToString:@"INT"]) {
    return SIGINT;
  }
  if ([normalized isEqualToString:@"KILL"]) {
    return SIGKILL;
  }
  return SIGTERM;
}

@end

@implementation BabelNativeModuleProcessRuntimeManager {
  BabelNativeModulePortAllocator* portAllocator_;
  BabelNativeModuleRuntimeStatusProvider* statusProvider_;
  BabelNativeModuleRequiredSettingsService* requiredSettingsService_;
  NSMutableDictionary<NSString*, BabelNativeModuleProcessWebInstance*>* processWebInstances_;
}

- (instancetype)init {
  return [self initWithRequiredSettingsService:nil];
}

- (instancetype)initWithRequiredSettingsService:(BabelNativeModuleRequiredSettingsService*)requiredSettingsService {
  self = [super init];
  if (self) {
    portAllocator_ = [[BabelNativeModulePortAllocator alloc] init];
    statusProvider_ = [[BabelNativeModuleRuntimeStatusProvider alloc] init];
    requiredSettingsService_ =
        requiredSettingsService ?: [[BabelNativeModuleRequiredSettingsService alloc] initWithUserDefaults:nil];
    processWebInstances_ = [NSMutableDictionary dictionary];
  }

  return self;
}

- (NSDictionary*)runtimeStatusForModule:(BabelNativeModuleManifest*)module {
  @synchronized(self) {
    if ([module.runtimeType isEqualToString:@"process-web"]) {
      BabelNativeModuleProcessWebInstance* instance = processWebInstances_[module.moduleIdentifier ?: @""];
      if (instance) {
        return [self processWebStatusForInstance:instance];
      }
    }

    return [statusProvider_ runtimeStatusForModule:module];
  }
}

- (NSDictionary*)restartProcessWebRuntimeForModule:(BabelNativeModuleManifest*)module
                                             error:(NSError**)error {
  return [self restartProcessWebRuntimeForModule:module additionalEnvironment:@{} error:error];
}

- (NSDictionary*)restartProcessWebRuntimeForModule:(BabelNativeModuleManifest*)module
                            additionalEnvironment:(NSDictionary<NSString*, NSString*>*)additionalEnvironment
                                            error:(NSError**)error {
  @synchronized(self) {
    if (![module.runtimeType isEqualToString:@"process-web"] || !module.processWeb) {
      [self assignError:error
            description:[NSString stringWithFormat:@"Module \"%@\" does not declare a process-web runtime.",
                                                   module.moduleIdentifier ?: @""]];
      return nil;
    }

    if (![self requiredSettingsAreSatisfiedForModule:module error:error]) {
      return nil;
    }

    [self stopRuntimeForModuleIdentifier:module.moduleIdentifier];

    NSNumber* portNumber = [self allocateProcessWebPortWithError:error];
    if (!portNumber) {
      return nil;
    }

    NSInteger port = portNumber.integerValue;
    NSString* cwd = [self resolvedWorkingDirectoryForModule:module cwd:module.processWeb.cwd error:error];
    if (cwd.length == 0) {
      return nil;
    }

    NSArray<NSString*>* commandLine = [self resolvedProcessWebCommandForModule:module port:port];
    if (commandLine.count == 0) {
      [self assignError:error
            description:[NSString stringWithFormat:@"Module \"%@\" process-web command is empty.",
                                                   module.moduleIdentifier ?: @""]];
      return nil;
    }

    NSString* readyURL = [self resolvedProcessWebReadyURLForModule:module port:port];
    NSString* baseURL = [NSString stringWithFormat:@"http://127.0.0.1:%ld", static_cast<long>(port)];
    NSDictionary<NSString*, NSString*>* environment = [self resolvedProcessWebEnvironmentForModule:module
                                                                                              port:port
                                                                             additionalEnvironment:additionalEnvironment];

    NSTask* task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/env"];
    task.arguments = commandLine;
    task.currentDirectoryURL = [NSURL fileURLWithPath:cwd isDirectory:YES];
    task.environment = environment;

    NSPipe* stdoutPipe = [NSPipe pipe];
    NSPipe* stderrPipe = [NSPipe pipe];
    task.standardOutput = stdoutPipe;
    task.standardError = stderrPipe;

    BabelNativeModuleProcessWebInstance* instance =
        [[BabelNativeModuleProcessWebInstance alloc] initWithModuleIdentifier:module.moduleIdentifier
                                                                         port:port
                                                                      baseURL:baseURL
                                                                      command:commandLine
                                                                          cwd:cwd
                                                                  environment:environment
                                                                     readyURL:readyURL
                                                                   stopSignal:module.processWeb.stopSignal
                                                                stopTimeoutMs:module.processWeb.stopTimeoutMs
                                                                  startPolicy:module.processWeb.startPolicy
                                                                         task:task
                                                                   stdoutPipe:stdoutPipe
                                                                   stderrPipe:stderrPipe];
    [instance beginCapturingLogs];

    NSError* launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
      [self assignError:error
            description:[NSString stringWithFormat:@"Module \"%@\" process could not be started: %@",
                                                   module.moduleIdentifier ?: @"",
                                                   launchError.localizedDescription ?: @"unknown error"]];
      return nil;
    }

    if (![self waitUntilProcessWebInstanceIsReady:instance timeoutMs:module.processWeb.timeoutMs error:error]) {
      NSString* logs = [instance logs];
      [instance stop];
      [self assignError:error
            description:[NSString stringWithFormat:@"Module \"%@\" process did not become ready at \"%@\".%@",
                                                   module.moduleIdentifier ?: @"",
                                                   readyURL,
                                                   logs.length > 0 ? [@"\nProcess log:\n" stringByAppendingString:logs] : @""]];
      return nil;
    }

    processWebInstances_[module.moduleIdentifier ?: @""] = instance;
    return [self processWebStatusForInstance:instance];
  }
}

- (NSDictionary*)startProcessWebRuntimeIfNeededForModule:(BabelNativeModuleManifest*)module
                                                   error:(NSError**)error {
  return [self startProcessWebRuntimeIfNeededForModule:module additionalEnvironment:@{} error:error];
}

- (NSDictionary*)startProcessWebRuntimeIfNeededForModule:(BabelNativeModuleManifest*)module
                                   additionalEnvironment:(NSDictionary<NSString*, NSString*>*)additionalEnvironment
                                                   error:(NSError**)error {
  @synchronized(self) {
    BabelNativeModuleProcessWebInstance* instance = processWebInstances_[module.moduleIdentifier ?: @""];
    if (instance && [instance isRunning]) {
      BOOL environmentMatches = YES;
      for (NSString* key in additionalEnvironment ?: @{}) {
        NSString* expected = additionalEnvironment[key] ?: @"";
        NSString* current = instance.environment[key] ?: @"";
        if (![current isEqualToString:expected]) {
          environmentMatches = NO;
          break;
        }
      }

      if (environmentMatches) {
        return [self processWebStatusForInstance:instance];
      }
    }

    if (instance) {
      [instance stop];
      [processWebInstances_ removeObjectForKey:module.moduleIdentifier ?: @""];
    }

    return [self restartProcessWebRuntimeForModule:module additionalEnvironment:additionalEnvironment ?: @{} error:error];
  }
}

- (NSDictionary*)executeProcessRuntimeForModule:(BabelNativeModuleManifest*)module
                                          route:(NSString*)route
                                      sourceURL:(NSString*)sourceURL
                            localServiceBaseURL:(NSString*)localServiceBaseURL
                              localServiceToken:(NSString*)localServiceToken
                                     queryItems:(NSArray<NSURLQueryItem*>*)queryItems
                                      fileTypes:(NSString*)fileTypes
                                           hook:(NSString*)hook
                                          error:(NSError**)error {
  if (![module.runtimeType isEqualToString:@"process-runtime"] || !module.processRuntime) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" does not declare a process-runtime runtime.",
                                                 module.moduleIdentifier ?: @""]];
    return nil;
  }

  if (![self requiredSettingsAreSatisfiedForModule:module error:error]) {
    return nil;
  }

  if (![module.processRuntime.mode isEqualToString:@"on-demand"]) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" process-runtime mode \"%@\" is not native yet.",
                                                 module.moduleIdentifier ?: @"",
                                                 module.processRuntime.mode ?: @""]];
    return nil;
  }

  BabelNativeModuleRuntimeCommand* command = [module.processRuntime commandForRoute:route ?: @""];
  if (!command) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" process-runtime route \"%@\" does not declare a command.",
                                                 module.moduleIdentifier ?: @"",
                                                 route ?: @""]];
    return nil;
  }

  NSString* cwd = [self resolvedWorkingDirectoryForModule:module cwd:module.processRuntime.cwd error:error];
  if (cwd.length == 0) {
    return nil;
  }

  NSArray<NSString*>* commandLine = [self resolvedProcessRuntimeCommand:command
                                                                  module:module
                                                                   route:route
                                                               sourceURL:sourceURL
                                                                    hook:hook];
  NSDictionary<NSString*, NSString*>* environment = [self resolvedProcessRuntimeEnvironmentForModule:module
                                                                                               route:route
                                                                                           sourceURL:sourceURL
                                                                                 localServiceBaseURL:localServiceBaseURL
                                                                                   localServiceToken:localServiceToken
                                                                                           fileTypes:fileTypes
                                                                                                hook:hook];
  NSDictionary* payload = [self processRuntimePayloadForModule:module
                                                         route:route
                                                     sourceURL:sourceURL
                                           localServiceBaseURL:localServiceBaseURL
                                                    queryItems:queryItems
                                                     fileTypes:fileTypes
                                                          hook:hook];

  NSDictionary* execution = [self runProcessRuntimeCommandLine:commandLine
                                                           cwd:cwd
                                                   environment:environment
                                                       payload:payload
                                                     timeoutMs:command.timeoutMs
                                                         error:error];
  if (!execution) {
    return nil;
  }

  if ([execution[@"timedOut"] boolValue]) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" process-runtime route \"%@\" timed out.%@",
                                                 module.moduleIdentifier ?: @"",
                                                 route ?: @"",
                                                 [self logsSuffixForExecution:execution]]];
    return nil;
  }

  NSInteger exitCode = [execution[@"exitCode"] isKindOfClass:NSNumber.class] ? [execution[@"exitCode"] integerValue] : -1;
  if (exitCode != 0) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" process-runtime route \"%@\" failed with exit code %ld.%@",
                                                 module.moduleIdentifier ?: @"",
                                                 route ?: @"",
                                                 static_cast<long>(exitCode),
                                                 [self logsSuffixForExecution:execution]]];
    return nil;
  }

  NSString* stdoutText = [execution[@"stdout"] isKindOfClass:NSString.class] ? execution[@"stdout"] : @"";
  return [self responseFromProcessRuntimeStdout:stdoutText];
}

- (NSDictionary*)stopRuntimeForModule:(BabelNativeModuleManifest*)module
                                error:(NSError**)error {
  @synchronized(self) {
    if ([module.runtimeType isEqualToString:@"process-web"]) {
      [self stopRuntimeForModuleIdentifier:module.moduleIdentifier];
      return [statusProvider_ runtimeStatusForModule:module];
    }

    if ([module.runtimeType isEqualToString:@"process-runtime"]) {
      return [statusProvider_ runtimeStatusForModule:module];
    }

    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" runtime \"%@\" cannot be stopped natively yet.",
                                                 module.moduleIdentifier ?: @"",
                                                 module.runtimeType ?: @""]];
    return nil;
  }
}

- (void)stopRuntimeForModuleIdentifier:(NSString*)moduleIdentifier {
  @synchronized(self) {
    BabelNativeModuleProcessWebInstance* instance = processWebInstances_[moduleIdentifier ?: @""];
    if (!instance) {
      return;
    }

    [instance stop];
    [processWebInstances_ removeObjectForKey:moduleIdentifier ?: @""];
  }
}

- (void)stopAllRuntimes {
  @synchronized(self) {
    NSArray<NSString*>* moduleIdentifiers = [processWebInstances_.allKeys copy];
    for (NSString* moduleIdentifier in moduleIdentifiers) {
      [self stopRuntimeForModuleIdentifier:moduleIdentifier];
    }
  }
}

- (NSNumber*)allocateProcessWebPortWithError:(NSError**)error {
  return [portAllocator_ availableLocalPortWithError:error];
}

- (NSArray<NSString*>*)resolvedProcessWebCommandForModule:(BabelNativeModuleManifest*)module
                                                     port:(NSInteger)port {
  BabelNativeModuleProcessWebDefinition* definition = module.processWeb;
  if (!definition) {
    return @[];
  }

  NSMutableArray<NSString*>* commandLine = [NSMutableArray array];
  for (NSString* item in [definition commandLine]) {
    [commandLine addObject:[self interpolate:item module:module port:port]];
  }

  return commandLine;
}

- (NSString*)resolvedProcessWebReadyURLForModule:(BabelNativeModuleManifest*)module
                                            port:(NSInteger)port {
  BabelNativeModuleProcessWebDefinition* definition = module.processWeb;
  if (!definition) {
    return @"";
  }

  return [self interpolate:definition.readyUrl module:module port:port];
}

- (NSString*)resolvedWorkingDirectoryForModule:(BabelNativeModuleManifest*)module
                                           cwd:(NSString*)cwd
                                         error:(NSError**)error {
  if (!module || module.path.length == 0) {
    [self assignError:error description:@"Module path is missing."];
    return nil;
  }

  NSString* candidate = [cwd hasPrefix:@"/"] ? cwd : [module.path stringByAppendingPathComponent:cwd ?: @"."];
  NSString* standardizedPath = candidate.stringByStandardizingPath;
  BOOL isDirectory = NO;
  if (![NSFileManager.defaultManager fileExistsAtPath:standardizedPath isDirectory:&isDirectory] || !isDirectory) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" process cwd \"%@\" was not found.",
                                                 module.moduleIdentifier ?: @"",
                                                 cwd ?: @""]];
    return nil;
  }

  return standardizedPath;
}

- (NSDictionary<NSString*, NSString*>*)resolvedProcessWebEnvironmentForModule:(BabelNativeModuleManifest*)module
                                                                         port:(NSInteger)port
                                                        additionalEnvironment:(NSDictionary<NSString*, NSString*>*)additionalEnvironment {
  NSMutableDictionary<NSString*, NSString*>* environment = [NSProcessInfo.processInfo.environment mutableCopy];
  if (!environment) {
    environment = [NSMutableDictionary dictionary];
  }

  NSDictionary<NSString*, NSString*>* declaredEnvironment = module.processWeb.env ?: @{};
  for (NSString* key in declaredEnvironment) {
    environment[key] = [self interpolate:declaredEnvironment[key] module:module port:port];
  }

  environment[@"BABELCHROME_MODULE_ID"] = module.moduleIdentifier ?: @"";
  environment[@"BABELCHROME_MODULE_NAME"] = module.name ?: @"";
  environment[@"BABELCHROME_MODULE_VERSION"] = module.version ?: @"";
  environment[@"BABELCHROME_MODULE_DIR"] = module.path ?: @"";
  environment[@"BABELCHROME_PORT"] = [NSString stringWithFormat:@"%ld", static_cast<long>(port)];
  environment[@"PORT"] = [NSString stringWithFormat:@"%ld", static_cast<long>(port)];
  for (NSString* key in additionalEnvironment ?: @{}) {
    environment[key] = additionalEnvironment[key] ?: @"";
  }
  [environment addEntriesFromDictionary:[requiredSettingsService_ runtimeEnvironmentForModule:module]];

  return environment;
}

- (NSArray<NSString*>*)resolvedProcessRuntimeCommand:(BabelNativeModuleRuntimeCommand*)command
                                               module:(BabelNativeModuleManifest*)module
                                                route:(NSString*)route
                                            sourceURL:(NSString*)sourceURL
                                                 hook:(NSString*)hook {
  NSMutableArray<NSString*>* commandLine = [NSMutableArray array];
  for (NSString* item in [command commandLine]) {
    [commandLine addObject:[self interpolate:item
                                      module:module
                                       route:route
                                   sourceURL:sourceURL
                                        hook:hook]];
  }

  return commandLine;
}

- (NSDictionary<NSString*, NSString*>*)resolvedProcessRuntimeEnvironmentForModule:(BabelNativeModuleManifest*)module
                                                                            route:(NSString*)route
                                                                        sourceURL:(NSString*)sourceURL
                                                              localServiceBaseURL:(NSString*)localServiceBaseURL
                                                                localServiceToken:(NSString*)localServiceToken
                                                                        fileTypes:(NSString*)fileTypes
                                                                             hook:(NSString*)hook {
  NSMutableDictionary<NSString*, NSString*>* environment = [NSMutableDictionary dictionary];
  NSDictionary<NSString*, NSString*>* currentEnvironment = NSProcessInfo.processInfo.environment;
  for (NSString* key in @[ @"PATH", @"HOME", @"TMPDIR", @"TMP", @"TEMP", @"SHELL" ]) {
    NSString* value = currentEnvironment[key];
    if (value.length > 0) {
      environment[key] = value;
    }
  }

  for (NSString* key in module.processRuntime.env ?: @{}) {
    environment[key] = [self interpolate:module.processRuntime.env[key]
                                  module:module
                                   route:route
                               sourceURL:sourceURL
                                    hook:hook];
  }

  environment[@"BABELCHROME_MODULE_ID"] = module.moduleIdentifier ?: @"";
  environment[@"BABELCHROME_MODULE_NAME"] = module.name ?: @"";
  environment[@"BABELCHROME_MODULE_VERSION"] = module.version ?: @"";
  environment[@"BABELCHROME_MODULE_DIR"] = module.path ?: @"";
  environment[@"BABELCHROME_MODULE_ROUTE"] = route ?: @"";
  environment[@"BABELCHROME_HOOK"] = hook ?: @"";
  environment[@"BABELCHROME_SOURCE_URL"] = sourceURL ?: @"";
  environment[@"BABELCHROME_FILE_TYPES"] = fileTypes ?: @"";
  environment[@"BABELCHROME_LOCAL_SERVICE_BASE_URL"] = localServiceBaseURL ?: @"";
  environment[@"BABELCHROME_LOCAL_SERVICE_TOKEN"] = localServiceToken ?: @"";
  [environment addEntriesFromDictionary:[requiredSettingsService_ runtimeEnvironmentForModule:module]];

  return environment;
}

- (NSDictionary*)processRuntimePayloadForModule:(BabelNativeModuleManifest*)module
                                          route:(NSString*)route
                                      sourceURL:(NSString*)sourceURL
                            localServiceBaseURL:(NSString*)localServiceBaseURL
                                     queryItems:(NSArray<NSURLQueryItem*>*)queryItems
                                      fileTypes:(NSString*)fileTypes
                                           hook:(NSString*)hook {
  return @{
    @"module" : @{
      @"id" : module.moduleIdentifier ?: @"",
      @"name" : module.name ?: @"",
      @"version" : module.version ?: @"",
      @"path" : module.path ?: @""
    },
    @"route" : route ?: @"",
    @"hook" : hook ?: @"",
    @"sourceUrl" : sourceURL ?: @"",
    @"localServiceBaseUrl" : localServiceBaseURL ?: @"",
    @"query" : [self queryDictionaryFromItems:queryItems],
    @"fileTypes" : fileTypes ?: @""
  };
}

- (NSDictionary<NSString*, NSString*>*)queryDictionaryFromItems:(NSArray<NSURLQueryItem*>*)queryItems {
  NSMutableDictionary<NSString*, NSString*>* query = [NSMutableDictionary dictionary];
  for (NSURLQueryItem* item in queryItems ?: @[]) {
    if (item.name.length == 0 || [item.name isEqualToString:@"token"]) {
      continue;
    }
    query[item.name] = item.value ?: @"";
  }

  return query;
}

- (NSDictionary*)runProcessRuntimeCommandLine:(NSArray<NSString*>*)commandLine
                                          cwd:(NSString*)cwd
                                  environment:(NSDictionary<NSString*, NSString*>*)environment
                                      payload:(NSDictionary*)payload
                                    timeoutMs:(NSInteger)timeoutMs
                                        error:(NSError**)error {
  if (commandLine.count == 0) {
    [self assignError:error description:@"Process-runtime command is empty."];
    return nil;
  }

  NSData* payloadData = [NSJSONSerialization dataWithJSONObject:payload ?: @{}
                                                       options:0
                                                         error:error];
  if (!payloadData) {
    return nil;
  }

  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/env"];
  task.arguments = commandLine;
  task.currentDirectoryURL = [NSURL fileURLWithPath:cwd isDirectory:YES];
  task.environment = environment;

  NSPipe* stdinPipe = [NSPipe pipe];
  NSPipe* stdoutPipe = [NSPipe pipe];
  NSPipe* stderrPipe = [NSPipe pipe];
  task.standardInput = stdinPipe;
  task.standardOutput = stdoutPipe;
  task.standardError = stderrPipe;

  NSMutableData* stdoutData = [NSMutableData data];
  NSMutableData* stderrData = [NSMutableData data];
  stdoutPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle* handle) {
    NSData* data = handle.availableData;
    if (data.length == 0) {
      handle.readabilityHandler = nil;
      return;
    }
    @synchronized(stdoutData) {
      [stdoutData appendData:data];
    }
  };
  stderrPipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle* handle) {
    NSData* data = handle.availableData;
    if (data.length == 0) {
      handle.readabilityHandler = nil;
      return;
    }
    @synchronized(stderrData) {
      [stderrData appendData:data];
    }
  };

  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  task.terminationHandler = ^(NSTask* finishedTask) {
    (void)finishedTask;
    dispatch_semaphore_signal(semaphore);
  };

  NSError* launchError = nil;
  if (![task launchAndReturnError:&launchError]) {
    stdoutPipe.fileHandleForReading.readabilityHandler = nil;
    stderrPipe.fileHandleForReading.readabilityHandler = nil;
    [self assignError:error
          description:[NSString stringWithFormat:@"Process-runtime command could not be started: %@",
                                                 launchError.localizedDescription ?: @"unknown error"]];
    return nil;
  }

  [stdinPipe.fileHandleForWriting writeData:payloadData];
  [stdinPipe.fileHandleForWriting closeFile];

  NSInteger timeout = timeoutMs > 0 ? timeoutMs : 10000;
  dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(timeout) * NSEC_PER_MSEC);
  BOOL timedOut = dispatch_semaphore_wait(semaphore, deadline) != 0;
  if (timedOut) {
    [task terminate];
    NSDate* killDeadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (task.running && [killDeadline timeIntervalSinceNow] > 0) {
      usleep(20000);
    }
    if (task.running) {
      kill(task.processIdentifier, SIGKILL);
    }
  }

  [task waitUntilExit];
  stdoutPipe.fileHandleForReading.readabilityHandler = nil;
  stderrPipe.fileHandleForReading.readabilityHandler = nil;

  NSString* stdoutText = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] ?: @"";
  NSString* stderrText = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] ?: @"";
  return @{
    @"exitCode" : @(task.terminationStatus),
    @"stdout" : stdoutText,
    @"stderr" : stderrText,
    @"timedOut" : @(timedOut)
  };
}

- (NSDictionary*)responseFromProcessRuntimeStdout:(NSString*)stdoutText {
  NSString* trimmed = [stdoutText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmed.length == 0) {
    return @{
      @"statusCode" : @204,
      @"headers" : @{},
      @"contentType" : @"text/plain; charset=utf-8",
      @"body" : [NSData data]
    };
  }

  NSData* jsonData = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
  id decoded = jsonData ? [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil] : nil;
  if ([decoded isKindOfClass:NSDictionary.class]) {
    return [self responseFromProcessRuntimeJSONOutput:decoded];
  }

  return @{
    @"statusCode" : @200,
    @"headers" : @{},
    @"contentType" : @"text/plain; charset=utf-8",
    @"body" : [stdoutText dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data]
  };
}

- (NSDictionary*)responseFromProcessRuntimeJSONOutput:(NSDictionary*)output {
  NSNumber* declaredStatus = [output[@"statusCode"] isKindOfClass:NSNumber.class] ? output[@"statusCode"] : @200;
  NSMutableDictionary<NSString*, NSString*>* headers = [NSMutableDictionary dictionary];
  NSDictionary* declaredHeaders = [output[@"headers"] isKindOfClass:NSDictionary.class] ? output[@"headers"] : @{};
  for (id key in declaredHeaders) {
    id value = declaredHeaders[key];
    if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class]) {
      headers[key] = value;
    }
  }

  NSString* contentType = [output[@"contentType"] isKindOfClass:NSString.class] ? output[@"contentType"] : @"";
  id body = output[@"body"] ?: output;
  NSData* bodyData = nil;
  if ([body isKindOfClass:NSString.class]) {
    bodyData = [body dataUsingEncoding:NSUTF8StringEncoding];
    if (contentType.length == 0) {
      contentType = headers[@"Content-Type"] ?: @"text/plain; charset=utf-8";
    }
  } else if ([NSJSONSerialization isValidJSONObject:body]) {
    bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (contentType.length == 0) {
      contentType = headers[@"Content-Type"] ?: @"application/json; charset=utf-8";
    }
  }

  if (!bodyData) {
    bodyData = [NSData data];
  }
  if (contentType.length == 0) {
    contentType = @"application/octet-stream";
  }

  [headers removeObjectForKey:@"Content-Type"];
  return @{
    @"statusCode" : declaredStatus,
    @"headers" : headers,
    @"contentType" : contentType,
    @"body" : bodyData
  };
}

- (NSString*)logsSuffixForExecution:(NSDictionary*)execution {
  NSMutableArray<NSString*>* parts = [NSMutableArray array];
  NSString* stdoutText = [execution[@"stdout"] isKindOfClass:NSString.class] ? execution[@"stdout"] : @"";
  NSString* stderrText = [execution[@"stderr"] isKindOfClass:NSString.class] ? execution[@"stderr"] : @"";
  NSString* trimmedStdout = [stdoutText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSString* trimmedStderr = [stderrText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedStdout.length > 0) {
    [parts addObject:[@"stdout: " stringByAppendingString:trimmedStdout]];
  }
  if (trimmedStderr.length > 0) {
    [parts addObject:[@"stderr: " stringByAppendingString:trimmedStderr]];
  }

  return parts.count == 0 ? @"" : [@"\nProcess log:\n" stringByAppendingString:[parts componentsJoinedByString:@"\n"]];
}

- (NSDictionary*)processWebStatusForInstance:(BabelNativeModuleProcessWebInstance*)instance {
  BOOL running = [instance isRunning];
  return @{
    @"kind" : @"process-web",
    @"state" : running ? @"running" : @"exited",
    @"running" : @(running),
    @"restartable" : @YES,
    @"port" : @(instance.port),
    @"baseUrl" : instance.baseURL,
    @"command" : instance.command,
    @"cwd" : instance.cwd,
    @"readyUrl" : instance.readyURL,
    @"startPolicy" : instance.startPolicy ?: @"lazy",
    @"logs" : [instance logs],
    @"source" : @"native"
  };
}

- (BOOL)waitUntilProcessWebInstanceIsReady:(BabelNativeModuleProcessWebInstance*)instance
                                 timeoutMs:(NSInteger)timeoutMs
                                     error:(NSError**)error {
  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:(timeoutMs > 0 ? timeoutMs : 10000) / 1000.0];
  while ([deadline timeIntervalSinceNow] > 0) {
    if (![instance isRunning]) {
      [self assignError:error
            description:[NSString stringWithFormat:@"Module \"%@\" process exited before becoming ready.",
                                                   instance.moduleIdentifier ?: @""]];
      return NO;
    }

    if ([self urlResponds:instance.readyURL]) {
      return YES;
    }

    usleep(100000);
  }

  [self assignError:error
        description:[NSString stringWithFormat:@"Module \"%@\" process did not become ready at \"%@\".",
                                               instance.moduleIdentifier ?: @"",
                                               instance.readyURL ?: @""]];
  return NO;
}

- (BOOL)urlResponds:(NSString*)urlString {
  NSURL* url = [NSURL URLWithString:urlString ?: @""];
  if (!url) {
    return NO;
  }

  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"GET";
  request.timeoutInterval = 0.5;

  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block NSInteger statusCode = 0;
  NSURLSessionConfiguration* configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  configuration.timeoutIntervalForRequest = 0.5;
  configuration.timeoutIntervalForResource = 0.5;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:configuration];
  NSURLSessionDataTask* task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                                            (void)data;
                                            (void)error;
                                            if ([response isKindOfClass:NSHTTPURLResponse.class]) {
                                              statusCode = [(NSHTTPURLResponse*)response statusCode];
                                            }
                                            dispatch_semaphore_signal(semaphore);
                                          }];
  [task resume];
  dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, static_cast<int64_t>(NSEC_PER_SEC));
  dispatch_semaphore_wait(semaphore, timeout);
  [session finishTasksAndInvalidate];

  return statusCode > 0 && statusCode < 500;
}

- (NSString*)interpolate:(NSString*)value
                  module:(BabelNativeModuleManifest*)module
                    port:(NSInteger)port {
  NSDictionary<NSString*, NSString*>* replacements = @{
    @"{{ port }}" : [NSString stringWithFormat:@"%ld", static_cast<long>(port)],
    @"{{ moduleId }}" : module.moduleIdentifier ?: @"",
    @"{{ moduleDir }}" : module.path ?: @""
  };

  NSString* interpolated = value ?: @"";
  for (NSString* token in replacements) {
    interpolated = [interpolated stringByReplacingOccurrencesOfString:token withString:replacements[token]];
  }

  return [self stringByInterpolatingRequiredSettingsInString:interpolated module:module];
}

- (NSString*)interpolate:(NSString*)value
                  module:(BabelNativeModuleManifest*)module
                   route:(NSString*)route
               sourceURL:(NSString*)sourceURL
                    hook:(NSString*)hook {
  NSDictionary<NSString*, NSString*>* replacements = @{
    @"{{ moduleId }}" : module.moduleIdentifier ?: @"",
    @"{{ moduleDir }}" : module.path ?: @"",
    @"{{ route }}" : route ?: @"",
    @"{{ hook }}" : hook ?: @"",
    @"{{ sourceUrl }}" : sourceURL ?: @""
  };

  NSString* interpolated = value ?: @"";
  for (NSString* token in replacements) {
    interpolated = [interpolated stringByReplacingOccurrencesOfString:token withString:replacements[token]];
  }

  return [self stringByInterpolatingRequiredSettingsInString:interpolated module:module];
}

- (NSString*)stringByInterpolatingRequiredSettingsInString:(NSString*)value
                                                    module:(BabelNativeModuleManifest*)module {
  NSString* interpolated = value ?: @"";
  NSDictionary<NSString*, NSString*>* settings = [requiredSettingsService_ resolvedValuesForModule:module];
  for (NSString* key in settings) {
    NSString* token = [NSString stringWithFormat:@"{{ settings.%@ }}", key];
    interpolated = [interpolated stringByReplacingOccurrencesOfString:token
                                                           withString:settings[key] ?: @""];
  }
  return interpolated;
}

- (BOOL)requiredSettingsAreSatisfiedForModule:(BabelNativeModuleManifest*)module error:(NSError**)error {
  NSDictionary* status = [requiredSettingsService_ statusForModule:module];
  if ([status[@"ready"] boolValue]) {
    return YES;
  }

  NSArray* messages = [status[@"messages"] isKindOfClass:NSArray.class] ? status[@"messages"] : @[];
  NSString* message = messages.count > 0
      ? [messages componentsJoinedByString:@"\n"]
      : @"Module runtime settings are incomplete.";
  [self assignError:error
        description:[NSString stringWithFormat:@"Module \"%@\" requires runtime settings before it can start.\n%@",
                                               module.moduleIdentifier ?: @"",
                                               message]];
  return NO;
}

- (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelNativeModuleProcessRuntimeManagerErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Unable to prepare module process."}];
}

@end
