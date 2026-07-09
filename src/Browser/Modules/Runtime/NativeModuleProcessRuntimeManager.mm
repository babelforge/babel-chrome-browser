#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeManager.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Runtime/NativeModulePortAllocator.h"
#import "Browser/Modules/Runtime/NativeModuleProcessWebDefinition.h"
#import "Browser/Modules/Runtime/NativeModuleRuntimeStatusProvider.h"

static NSString* const kBabelNativeModuleProcessRuntimeManagerErrorDomain =
    @"fr.babelforge.babel-chrome.native-module-process-runtime-manager";

@implementation BabelNativeModuleProcessRuntimeManager {
  BabelNativeModulePortAllocator* portAllocator_;
  BabelNativeModuleRuntimeStatusProvider* statusProvider_;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    portAllocator_ = [[BabelNativeModulePortAllocator alloc] init];
    statusProvider_ = [[BabelNativeModuleRuntimeStatusProvider alloc] init];
  }

  return self;
}

- (NSDictionary*)runtimeStatusForModule:(BabelNativeModuleManifest*)module {
  return [statusProvider_ runtimeStatusForModule:module];
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

  return interpolated;
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
