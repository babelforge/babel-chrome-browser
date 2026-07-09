#import "Browser/Modules/Runtime/NativeModuleProcessWebDefinition.h"

@implementation BabelNativeModuleProcessWebDefinition

@synthesize command = _command;
@synthesize args = _args;
@synthesize cwd = _cwd;
@synthesize env = _env;
@synthesize readyUrl = _readyUrl;
@synthesize timeoutMs = _timeoutMs;
@synthesize stopSignal = _stopSignal;
@synthesize stopTimeoutMs = _stopTimeoutMs;

+ (instancetype)definitionWithRuntimeDictionary:(NSDictionary*)runtime {
  if (![runtime isKindOfClass:NSDictionary.class]) {
    return nil;
  }

  NSString* command = [self trimmedStringFromValue:runtime[@"command"] fallback:@""];
  if (command.length == 0) {
    return nil;
  }

  NSDictionary* stop = [runtime[@"stop"] isKindOfClass:NSDictionary.class] ? runtime[@"stop"] : @{};
  return [[self alloc] initWithCommand:command
                                  args:[self stringListFromValue:runtime[@"args"]]
                                   cwd:[self trimmedStringFromValue:runtime[@"cwd"] fallback:@"."]
                                   env:[self stringMapFromValue:runtime[@"env"]]
                              readyUrl:[self trimmedStringFromValue:runtime[@"readyUrl"]
                                                          fallback:@"http://127.0.0.1:{{ port }}"]
                             timeoutMs:[self positiveIntegerFromValue:runtime[@"timeoutMs"] fallback:10000]
                            stopSignal:[self trimmedStringFromValue:stop[@"signal"] fallback:@"TERM"]
                         stopTimeoutMs:[self positiveIntegerFromValue:stop[@"timeoutMs"] fallback:3000]];
}

- (instancetype)initWithCommand:(NSString*)command
                           args:(NSArray<NSString*>*)args
                            cwd:(NSString*)cwd
                            env:(NSDictionary<NSString*, NSString*>*)env
                       readyUrl:(NSString*)readyUrl
                      timeoutMs:(NSInteger)timeoutMs
                     stopSignal:(NSString*)stopSignal
                  stopTimeoutMs:(NSInteger)stopTimeoutMs {
  self = [super init];
  if (self) {
    _command = [command copy];
    _args = [args copy];
    _cwd = cwd.length > 0 ? [cwd copy] : @".";
    _env = [env copy];
    _readyUrl = readyUrl.length > 0 ? [readyUrl copy] : @"http://127.0.0.1:{{ port }}";
    _timeoutMs = timeoutMs > 0 ? timeoutMs : 10000;
    _stopSignal = stopSignal.length > 0 ? [stopSignal copy] : @"TERM";
    _stopTimeoutMs = stopTimeoutMs > 0 ? stopTimeoutMs : 3000;
  }

  return self;
}

- (NSArray<NSString*>*)commandLine {
  NSMutableArray<NSString*>* commandLine = [NSMutableArray arrayWithObject:self.command];
  [commandLine addObjectsFromArray:self.args];
  return commandLine;
}

- (NSDictionary*)dictionaryRepresentation {
  return @{
    @"command" : self.command,
    @"args" : self.args,
    @"cwd" : self.cwd,
    @"env" : self.env,
    @"readyUrl" : self.readyUrl,
    @"timeoutMs" : @(self.timeoutMs),
    @"stop" : @{
      @"signal" : self.stopSignal,
      @"timeoutMs" : @(self.stopTimeoutMs)
    }
  };
}

+ (NSString*)trimmedStringFromValue:(id)value fallback:(NSString*)fallback {
  NSString* string = [value isKindOfClass:NSString.class] ? value : fallback;
  return [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

+ (NSInteger)positiveIntegerFromValue:(id)value fallback:(NSInteger)fallback {
  NSInteger integer = [value isKindOfClass:NSNumber.class] ? [value integerValue] : 0;
  return integer > 0 ? integer : fallback;
}

+ (NSArray<NSString*>*)stringListFromValue:(id)value {
  NSArray* items = [value isKindOfClass:NSArray.class] ? value : @[];
  NSMutableArray<NSString*>* strings = [NSMutableArray array];
  for (id item in items) {
    if ([item isKindOfClass:NSString.class]) {
      [strings addObject:item];
    }
  }

  return strings;
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
