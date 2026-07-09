#import "Browser/Modules/Runtime/NativeModuleRuntimeCommand.h"

@implementation BabelNativeModuleRuntimeCommand

@synthesize command = _command;
@synthesize args = _args;
@synthesize timeoutMs = _timeoutMs;

+ (instancetype)commandWithDictionary:(NSDictionary*)data
                     defaultTimeoutMs:(NSInteger)defaultTimeoutMs {
  if (![data isKindOfClass:NSDictionary.class]) {
    return nil;
  }

  NSString* command = [data[@"command"] isKindOfClass:NSString.class]
      ? [data[@"command"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
      : @"";
  if (command.length == 0) {
    return nil;
  }

  NSInteger timeoutMs = [data[@"timeoutMs"] isKindOfClass:NSNumber.class] ? [data[@"timeoutMs"] integerValue] : 0;
  if (timeoutMs <= 0) {
    timeoutMs = defaultTimeoutMs > 0 ? defaultTimeoutMs : 10000;
  }

  return [[self alloc] initWithCommand:command
                                  args:[self stringListFromValue:data[@"args"]]
                             timeoutMs:timeoutMs];
}

- (instancetype)initWithCommand:(NSString*)command
                           args:(NSArray<NSString*>*)args
                      timeoutMs:(NSInteger)timeoutMs {
  self = [super init];
  if (self) {
    _command = [command copy];
    _args = [args copy];
    _timeoutMs = timeoutMs > 0 ? timeoutMs : 10000;
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
    @"timeoutMs" : @(self.timeoutMs)
  };
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

@end
