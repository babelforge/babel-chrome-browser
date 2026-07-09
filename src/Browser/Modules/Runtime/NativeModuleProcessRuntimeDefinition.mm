#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeDefinition.h"

#import "Browser/Modules/Runtime/NativeModuleRuntimeCommand.h"

static NSString* const kBabelNativeModuleProcessRuntimeModeOnDemand = @"on-demand";
static NSString* const kBabelNativeModuleProcessRuntimeModeLongRunning = @"long-running";

@implementation BabelNativeModuleProcessRuntimeDefinition

@synthesize mode = _mode;
@synthesize command = _command;
@synthesize commands = _commands;
@synthesize cwd = _cwd;
@synthesize env = _env;
@synthesize stopSignal = _stopSignal;
@synthesize stopTimeoutMs = _stopTimeoutMs;

+ (instancetype)definitionWithRuntimeDictionary:(NSDictionary*)runtime {
  if (![runtime isKindOfClass:NSDictionary.class]) {
    return nil;
  }

  NSInteger defaultTimeoutMs = [self positiveIntegerFromValue:runtime[@"timeoutMs"] fallback:10000];
  BabelNativeModuleRuntimeCommand* command =
      [BabelNativeModuleRuntimeCommand commandWithDictionary:runtime defaultTimeoutMs:defaultTimeoutMs];
  if (!command) {
    return nil;
  }

  NSDictionary* stop = [runtime[@"stop"] isKindOfClass:NSDictionary.class] ? runtime[@"stop"] : @{};
  return [[self alloc] initWithMode:[self normalizedMode:[self trimmedStringFromValue:runtime[@"mode"]
                                                                            fallback:kBabelNativeModuleProcessRuntimeModeOnDemand]]
                            command:command
                           commands:[self commandsFromValue:runtime[@"commands"] defaultTimeoutMs:command.timeoutMs]
                                cwd:[self trimmedStringFromValue:runtime[@"cwd"] fallback:@"."]
                                env:[self stringMapFromValue:runtime[@"env"]]
                         stopSignal:[self trimmedStringFromValue:stop[@"signal"] fallback:@"TERM"]
                      stopTimeoutMs:[self positiveIntegerFromValue:stop[@"timeoutMs"] fallback:3000]];
}

- (instancetype)initWithMode:(NSString*)mode
                     command:(BabelNativeModuleRuntimeCommand*)command
                    commands:(NSDictionary<NSString*, BabelNativeModuleRuntimeCommand*>*)commands
                         cwd:(NSString*)cwd
                         env:(NSDictionary<NSString*, NSString*>*)env
                  stopSignal:(NSString*)stopSignal
               stopTimeoutMs:(NSInteger)stopTimeoutMs {
  self = [super init];
  if (self) {
    _mode = [mode copy];
    _command = command;
    _commands = [commands copy];
    _cwd = cwd.length > 0 ? [cwd copy] : @".";
    _env = [env copy];
    _stopSignal = stopSignal.length > 0 ? [stopSignal copy] : @"TERM";
    _stopTimeoutMs = stopTimeoutMs > 0 ? stopTimeoutMs : 3000;
  }

  return self;
}

- (BabelNativeModuleRuntimeCommand*)commandForRoute:(NSString*)route {
  BabelNativeModuleRuntimeCommand* routeCommand = self.commands[route ?: @""];
  return routeCommand ?: self.command;
}

- (NSDictionary*)dictionaryRepresentation {
  NSMutableDictionary<NSString*, NSDictionary*>* commands = [NSMutableDictionary dictionary];
  for (NSString* route in self.commands) {
    commands[route] = [self.commands[route] dictionaryRepresentation];
  }

  return @{
    @"mode" : self.mode,
    @"command" : self.command.command,
    @"args" : self.command.args,
    @"timeoutMs" : @(self.command.timeoutMs),
    @"cwd" : self.cwd,
    @"env" : self.env,
    @"commands" : commands,
    @"stop" : @{
      @"signal" : self.stopSignal,
      @"timeoutMs" : @(self.stopTimeoutMs)
    }
  };
}

+ (NSDictionary<NSString*, BabelNativeModuleRuntimeCommand*>*)commandsFromValue:(id)value
                                                               defaultTimeoutMs:(NSInteger)defaultTimeoutMs {
  NSDictionary* dictionary = [value isKindOfClass:NSDictionary.class] ? value : @{};
  NSMutableDictionary<NSString*, BabelNativeModuleRuntimeCommand*>* commands = [NSMutableDictionary dictionary];
  for (id route in dictionary) {
    if (![route isKindOfClass:NSString.class]) {
      continue;
    }

    NSString* trimmedRoute = [route stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmedRoute.length == 0) {
      continue;
    }

    id item = dictionary[route];
    BabelNativeModuleRuntimeCommand* command =
        [BabelNativeModuleRuntimeCommand commandWithDictionary:item defaultTimeoutMs:defaultTimeoutMs];
    if (command) {
      commands[trimmedRoute] = command;
    }
  }

  return commands;
}

+ (NSString*)normalizedMode:(NSString*)mode {
  return [mode isEqualToString:kBabelNativeModuleProcessRuntimeModeLongRunning]
      ? kBabelNativeModuleProcessRuntimeModeLongRunning
      : kBabelNativeModuleProcessRuntimeModeOnDemand;
}

+ (NSString*)trimmedStringFromValue:(id)value fallback:(NSString*)fallback {
  NSString* string = [value isKindOfClass:NSString.class] ? value : fallback;
  return [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

+ (NSInteger)positiveIntegerFromValue:(id)value fallback:(NSInteger)fallback {
  NSInteger integer = [value isKindOfClass:NSNumber.class] ? [value integerValue] : 0;
  return integer > 0 ? integer : fallback;
}

+ (NSDictionary<NSString*, NSString*>*)stringMapFromValue:(id)value {
  NSDictionary* dictionary = [value isKindOfClass:NSDictionary.class] ? value : @{};
  NSMutableDictionary<NSString*, NSString*>* strings = [NSMutableDictionary dictionary];
  for (id key in dictionary) {
    id item = dictionary[key];
    if ([key isKindOfClass:NSString.class] && [item isKindOfClass:NSString.class]) {
      strings[key] = item;
    }
  }

  return strings;
}

@end
