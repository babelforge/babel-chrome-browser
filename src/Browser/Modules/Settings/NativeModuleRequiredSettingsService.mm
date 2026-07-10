#import "Browser/Modules/Settings/NativeModuleRequiredSettingsService.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"

#include <ctype.h>

static NSString* const kBabelNativeModuleRequiredSettingsErrorDomain =
    @"fr.babelforge.babel-chrome.native-module-required-settings";

@implementation BabelNativeModuleRequiredSettingsService {
  NSUserDefaults* userDefaults_;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults {
  self = [super init];
  if (self) {
    userDefaults_ = userDefaults ?: NSUserDefaults.standardUserDefaults;
  }
  return self;
}

- (NSDictionary*)statusForModule:(BabelNativeModuleManifest*)module {
  NSDictionary* definitions = [self requiredSettingDefinitionsForModule:module];
  if (definitions.count == 0) {
    return @{
      @"ready" : @YES,
      @"state" : @"ready",
      @"settings" : @[],
      @"messages" : @[]
    };
  }

  NSMutableArray<NSDictionary*>* rows = [NSMutableArray array];
  NSMutableArray<NSString*>* messages = [NSMutableArray array];
  BOOL ready = YES;
  for (NSString* key in [[definitions allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
    NSDictionary* definition = [definitions[key] isKindOfClass:NSDictionary.class] ? definitions[key] : @{};
    NSDictionary* row = [self statusForSettingKey:key definition:definition module:module];
    [rows addObject:row];
    if (![row[@"valid"] boolValue]) {
      ready = NO;
    }
    NSArray* rowMessages = [row[@"messages"] isKindOfClass:NSArray.class] ? row[@"messages"] : @[];
    for (id item in rowMessages) {
      if ([item isKindOfClass:NSString.class] && [item length] > 0) {
        [messages addObject:item];
      }
    }
  }

  return @{
    @"ready" : @(ready),
    @"state" : ready ? @"ready" : @"configuration-required",
    @"settings" : rows,
    @"messages" : messages
  };
}

- (BOOL)requiredSettingsAreSatisfiedForModule:(BabelNativeModuleManifest*)module {
  return [[self statusForModule:module][@"ready"] boolValue];
}

- (BOOL)setValue:(NSString*)value
          forKey:(NSString*)key
          module:(BabelNativeModuleManifest*)module
           error:(NSError**)error {
  NSDictionary* definition = [self requiredSettingDefinitionsForModule:module][key ?: @""];
  if (![definition isKindOfClass:NSDictionary.class]) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" does not declare required setting \"%@\".",
                                                 module.moduleIdentifier ?: @"",
                                                 key ?: @""]];
    return NO;
  }

  NSDictionary* validation = [self validationForValue:value definition:definition];
  if (![validation[@"valid"] boolValue]) {
    NSArray* messages = [validation[@"messages"] isKindOfClass:NSArray.class] ? validation[@"messages"] : @[];
    [self assignError:error
          description:messages.count > 0 ? [messages componentsJoinedByString:@"\n"] : @"Invalid required setting."];
    return NO;
  }

  [userDefaults_ setObject:value ?: @"" forKey:[self defaultsKeyForModule:module.moduleIdentifier key:key]];
  [userDefaults_ synchronize];
  return YES;
}

- (NSDictionary<NSString*, NSString*>*)resolvedValuesForModule:(BabelNativeModuleManifest*)module {
  NSDictionary* definitions = [self requiredSettingDefinitionsForModule:module];
  NSMutableDictionary<NSString*, NSString*>* values = [NSMutableDictionary dictionary];
  for (NSString* key in definitions) {
    NSDictionary* row = [self statusForSettingKey:key definition:definitions[key] module:module];
    if ([row[@"valid"] boolValue] && [row[@"value"] isKindOfClass:NSString.class]) {
      values[key] = row[@"value"];
    }
  }
  return values;
}

- (NSDictionary<NSString*, NSString*>*)runtimeEnvironmentForModule:(BabelNativeModuleManifest*)module {
  NSDictionary<NSString*, NSString*>* values = [self resolvedValuesForModule:module];
  NSMutableDictionary<NSString*, NSString*>* environment = [NSMutableDictionary dictionary];
  for (NSString* key in values) {
    NSString* environmentKey =
        [@"BABELCHROME_SETTING_" stringByAppendingString:[self environmentNameForSettingKey:key]];
    environment[environmentKey] = values[key] ?: @"";
  }
  return environment;
}

- (NSURL*)settingsURLForModule:(BabelNativeModuleManifest*)module {
  NSString* escapedIdentifier =
      [module.moduleIdentifier stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet] ?:
      module.moduleIdentifier ?: @"";
  NSString* urlString = [NSString stringWithFormat:@"babelchrome://settings/%@?runtimeSettings=1",
                                                   escapedIdentifier];
  return [NSURL URLWithString:urlString];
}

- (NSDictionary*)statusForSettingKey:(NSString*)key
                           definition:(NSDictionary*)definition
                                module:(BabelNativeModuleManifest*)module {
  NSString* storedValue = [userDefaults_ stringForKey:[self defaultsKeyForModule:module.moduleIdentifier key:key]];
  NSString* value = storedValue.length > 0 ? storedValue : [self autoDetectedValueForDefinition:definition];
  if (storedValue.length == 0 && value.length > 0) {
    [userDefaults_ setObject:value forKey:[self defaultsKeyForModule:module.moduleIdentifier key:key]];
    [userDefaults_ synchronize];
  }

  NSDictionary* validation = [self validationForValue:value definition:definition];
  NSString* label = [definition[@"label"] isKindOfClass:NSString.class] ? definition[@"label"] : key ?: @"";
  NSString* type = [definition[@"type"] isKindOfClass:NSString.class] ? definition[@"type"] : @"";
  NSMutableDictionary* row = [@{
    @"key" : key ?: @"",
    @"label" : label ?: @"",
    @"type" : type ?: @"",
    @"value" : value ?: @"",
    @"valid" : validation[@"valid"] ?: @NO,
    @"state" : [validation[@"valid"] boolValue] ? @"valid" : @"invalid",
    @"messages" : validation[@"messages"] ?: @[]
  } mutableCopy];

  NSString* version = [validation[@"version"] isKindOfClass:NSString.class] ? validation[@"version"] : @"";
  if (version.length > 0) {
    row[@"version"] = version;
  }
  return row;
}

- (NSDictionary*)validationForValue:(NSString*)value definition:(NSDictionary*)definition {
  NSString* type = [definition[@"type"] isKindOfClass:NSString.class] ? definition[@"type"] : @"";
  if (![type isEqualToString:@"executable"]) {
    return @{
      @"valid" : @NO,
      @"messages" : @[ [NSString stringWithFormat:@"Unsupported required setting type \"%@\".", type ?: @""] ]
    };
  }

  NSString* path = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (path.length == 0) {
    return @{
      @"valid" : @NO,
      @"messages" : @[ @"Executable path is not configured." ]
    };
  }

  BOOL isDirectory = NO;
  NSFileManager* fileManager = NSFileManager.defaultManager;
  if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory] || isDirectory) {
    return @{
      @"valid" : @NO,
      @"messages" : @[ [NSString stringWithFormat:@"Executable was not found at \"%@\".", path] ]
    };
  }

  if (![fileManager isExecutableFileAtPath:path]) {
    return @{
      @"valid" : @NO,
      @"messages" : @[ [NSString stringWithFormat:@"File is not executable: \"%@\".", path] ]
    };
  }

  NSString* minimumVersion = [definition[@"minVersion"] isKindOfClass:NSString.class] ? definition[@"minVersion"] : @"";
  if (minimumVersion.length == 0) {
    return @{@"valid" : @YES, @"messages" : @[]};
  }

  NSString* versionOutput = [self versionOutputForExecutable:path definition:definition];
  NSString* detectedVersion = [self firstVersionInString:versionOutput];
  if (detectedVersion.length == 0) {
    return @{
      @"valid" : @NO,
      @"messages" : @[ [NSString stringWithFormat:@"Unable to read version for \"%@\".", path] ]
    };
  }

  if (![self version:detectedVersion isAtLeastVersion:minimumVersion]) {
    return @{
      @"valid" : @NO,
      @"version" : detectedVersion,
      @"messages" : @[ [NSString stringWithFormat:@"Version %@ is lower than required version %@.",
                                                  detectedVersion,
                                                  minimumVersion] ]
    };
  }

  return @{
    @"valid" : @YES,
    @"version" : detectedVersion,
    @"messages" : @[ [NSString stringWithFormat:@"Detected version %@.", detectedVersion] ]
  };
}

- (NSString*)autoDetectedValueForDefinition:(NSDictionary*)definition {
  for (NSString* path in [self autoDetectPathsForDefinition:definition]) {
    NSDictionary* validation = [self validationForValue:path definition:definition];
    if ([validation[@"valid"] boolValue]) {
      return path;
    }
  }
  return @"";
}

- (NSArray<NSString*>*)autoDetectPathsForDefinition:(NSDictionary*)definition {
  NSArray* declaredPaths = [definition[@"autoDetectPaths"] isKindOfClass:NSArray.class]
      ? definition[@"autoDetectPaths"]
      : @[];
  NSMutableArray<NSString*>* paths = [NSMutableArray array];
  for (id item in declaredPaths) {
    if ([item isKindOfClass:NSString.class] && [item length] > 0) {
      [paths addObject:item];
    }
  }

  NSString* binary = [definition[@"binary"] isKindOfClass:NSString.class] ? definition[@"binary"] : @"";
  if (binary.length > 0) {
    NSArray<NSString*>* prefixes = @[
      @"/opt/homebrew/bin",
      @"/opt/homebrew/sbin",
      @"/usr/local/bin",
      @"/usr/local/sbin",
      @"/opt/local/bin",
      @"/usr/bin",
      @"/bin",
      @"/usr/sbin",
      @"/sbin"
    ];
    for (NSString* prefix in prefixes) {
      [paths addObject:[prefix stringByAppendingPathComponent:binary]];
    }
  }

  NSMutableArray<NSString*>* uniquePaths = [NSMutableArray array];
  NSMutableSet<NSString*>* seen = [NSMutableSet set];
  for (NSString* path in paths) {
    if (path.length == 0 || [seen containsObject:path]) {
      continue;
    }
    [seen addObject:path];
    [uniquePaths addObject:path];
  }
  return uniquePaths;
}

- (NSString*)versionOutputForExecutable:(NSString*)executable definition:(NSDictionary*)definition {
  NSArray* declaredArgs = [definition[@"versionArgs"] isKindOfClass:NSArray.class] ? definition[@"versionArgs"] : @[ @"--version" ];
  NSMutableArray<NSString*>* args = [NSMutableArray array];
  for (id item in declaredArgs) {
    if ([item isKindOfClass:NSString.class]) {
      [args addObject:item];
    }
  }

  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:executable];
  task.arguments = args;
  NSPipe* stdoutPipe = [NSPipe pipe];
  NSPipe* stderrPipe = [NSPipe pipe];
  task.standardOutput = stdoutPipe;
  task.standardError = stderrPipe;

  NSError* error = nil;
  if (![task launchAndReturnError:&error]) {
    return @"";
  }

  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:2.0];
  while (task.running && [deadline timeIntervalSinceNow] > 0) {
    usleep(20000);
  }
  if (task.running) {
    [task terminate];
  }
  [task waitUntilExit];

  NSData* stdoutData = [stdoutPipe.fileHandleForReading readDataToEndOfFile];
  NSData* stderrData = [stderrPipe.fileHandleForReading readDataToEndOfFile];
  NSString* stdoutText = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] ?: @"";
  NSString* stderrText = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] ?: @"";
  return [stdoutText stringByAppendingString:stderrText];
}

- (NSString*)firstVersionInString:(NSString*)string {
  NSRegularExpression* expression =
      [NSRegularExpression regularExpressionWithPattern:@"([0-9]+(?:\\.[0-9]+){0,3})"
                                                options:0
                                                  error:nil];
  NSTextCheckingResult* match = [expression firstMatchInString:string ?: @""
                                                       options:0
                                                         range:NSMakeRange(0, string.length)];
  if (!match || match.numberOfRanges < 2) {
    return @"";
  }
  return [string substringWithRange:[match rangeAtIndex:1]];
}

- (BOOL)version:(NSString*)version isAtLeastVersion:(NSString*)minimumVersion {
  NSArray<NSString*>* left = [version componentsSeparatedByString:@"."];
  NSArray<NSString*>* right = [minimumVersion componentsSeparatedByString:@"."];
  NSUInteger count = MAX(left.count, right.count);
  for (NSUInteger index = 0; index < count; ++index) {
    NSInteger leftPart = index < left.count ? left[index].integerValue : 0;
    NSInteger rightPart = index < right.count ? right[index].integerValue : 0;
    if (leftPart > rightPart) {
      return YES;
    }
    if (leftPart < rightPart) {
      return NO;
    }
  }
  return YES;
}

- (NSDictionary*)requiredSettingDefinitionsForModule:(BabelNativeModuleManifest*)module {
  return [module.requiredSettings isKindOfClass:NSDictionary.class] ? module.requiredSettings : @{};
}

- (NSString*)defaultsKeyForModule:(NSString*)moduleIdentifier key:(NSString*)key {
  return [NSString stringWithFormat:@"ModuleRequiredSettings.%@.%@",
                                    moduleIdentifier ?: @"",
                                    key ?: @""];
}

- (NSString*)environmentNameForSettingKey:(NSString*)key {
  NSMutableString* name = [NSMutableString string];
  NSCharacterSet* alphanumeric = NSCharacterSet.alphanumericCharacterSet;
  for (NSUInteger index = 0; index < key.length; ++index) {
    unichar character = [key characterAtIndex:index];
    if ([alphanumeric characterIsMember:character]) {
      [name appendFormat:@"%C", static_cast<unichar>(toupper(character))];
    } else {
      [name appendString:@"_"];
    }
  }
  return name;
}

- (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelNativeModuleRequiredSettingsErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Invalid module runtime settings."}];
}

@end
