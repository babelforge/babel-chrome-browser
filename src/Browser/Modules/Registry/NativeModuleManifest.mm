#import "Browser/Modules/Registry/NativeModuleManifest.h"

#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeDefinition.h"
#import "Browser/Modules/Runtime/NativeModuleProcessWebDefinition.h"

static NSString* const kBabelNativeModuleManifestErrorDomain = @"fr.babelforge.babel-chrome.native-module-manifest";

@implementation BabelNativeModuleManifest

@synthesize moduleIdentifier = _moduleIdentifier;
@synthesize name = _name;
@synthesize version = _version;
@synthesize moduleDescription = _moduleDescription;
@synthesize moduleType = _moduleType;
@synthesize enabled = _enabled;
@synthesize runtimeType = _runtimeType;
@synthesize path = _path;
@synthesize routes = _routes;
@synthesize fileTypes = _fileTypes;
@synthesize fileNameContains = _fileNameContains;
@synthesize fileTypeHandlerFileTypes = _fileTypeHandlerFileTypes;
@synthesize hooks = _hooks;
@synthesize permissions = _permissions;
@synthesize menuItems = _menuItems;
@synthesize badge = _badge;
@synthesize settingsRoute = _settingsRoute;
@synthesize defaultGroup = _defaultGroup;
@synthesize readiness = _readiness;
@synthesize setup = _setup;
@synthesize runtime = _runtime;
@synthesize processWeb = _processWeb;
@synthesize processRuntime = _processRuntime;
@synthesize requirements = _requirements;

+ (instancetype)manifestWithDictionary:(NSDictionary*)data
                            modulePath:(NSString*)modulePath
                                 error:(NSError**)error {
  NSString* moduleIdentifier = [self requiredStringForKey:@"id" dictionary:data error:error];
  if (!moduleIdentifier) {
    return nil;
  }

  if (![self isValidModuleIdentifier:moduleIdentifier]) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module id \"%@\" is invalid.", moduleIdentifier]];
    return nil;
  }

  NSString* name = [self requiredStringForKey:@"name" dictionary:data error:error];
  if (!name) {
    return nil;
  }

  NSString* version = [self requiredStringForKey:@"version" dictionary:data error:error];
  if (!version) {
    return nil;
  }

  NSDictionary* runtime = [data[@"runtime"] isKindOfClass:NSDictionary.class] ? data[@"runtime"] : nil;
  if (!runtime) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" must declare runtime.type.", moduleIdentifier]];
    return nil;
  }

  NSString* runtimeType = [runtime[@"type"] isKindOfClass:NSString.class]
      ? [runtime[@"type"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
      : @"";
  if (runtimeType.length == 0) {
    [self assignError:error
          description:[NSString stringWithFormat:@"Module \"%@\" must declare runtime.type.", moduleIdentifier]];
    return nil;
  }

  BabelNativeModuleProcessWebDefinition* processWeb = nil;
  BabelNativeModuleProcessRuntimeDefinition* processRuntime = nil;
  if ([runtimeType isEqualToString:@"process-web"]) {
    processWeb = [BabelNativeModuleProcessWebDefinition definitionWithRuntimeDictionary:runtime];
    if (!processWeb) {
      [self assignError:error
            description:[NSString stringWithFormat:@"Module \"%@\" must declare runtime.command for process-web.",
                                                       moduleIdentifier]];
      return nil;
    }
  }

  if ([runtimeType isEqualToString:@"process-runtime"]) {
    processRuntime = [BabelNativeModuleProcessRuntimeDefinition definitionWithRuntimeDictionary:runtime];
    if (!processRuntime) {
      [self assignError:error
            description:[NSString stringWithFormat:@"Module \"%@\" must declare runtime.command for process-runtime.",
                                                       moduleIdentifier]];
      return nil;
    }
  }

  NSString* settingsRoute = [self settingsRouteFromDictionary:data];

  return [[self alloc] initWithModuleIdentifier:moduleIdentifier
                                           name:name
                                        version:version
                              moduleDescription:[self optionalStringForKey:@"description" dictionary:data fallback:@""]
                                     moduleType:[self optionalStringForKey:@"type" dictionary:data fallback:@"module"]
                                        enabled:[self optionalBoolForKey:@"enabled" dictionary:data fallback:YES]
                                    runtimeType:runtimeType
                                           path:modulePath ?: @""
                                         routes:[self dictionaryListForKey:@"routes" dictionary:data]
                                      fileTypes:[self stringListForKey:@"fileTypes" dictionary:data lowercase:YES]
                               fileNameContains:[self stringListForKey:@"fileNameContains" dictionary:data lowercase:YES]
                    fileTypeHandlerFileTypes:[self fileTypeHandlerFileTypesFromDictionary:data]
                                          hooks:[self stringListForKey:@"hooks" dictionary:data lowercase:NO]
                                    permissions:[self stringListForKey:@"permissions" dictionary:data lowercase:NO]
                                      menuItems:[self dictionaryListForKey:@"menuItems" dictionary:data]
                                          badge:[data[@"badge"] isKindOfClass:NSDictionary.class] ? data[@"badge"] : @{}
                                  settingsRoute:settingsRoute
                                   defaultGroup:[self trimmedOptionalStringForKey:@"defaultGroup" dictionary:data]
                                      readiness:[data[@"readiness"] isKindOfClass:NSDictionary.class] ? data[@"readiness"] : @{}
                                        setup:[data[@"setup"] isKindOfClass:NSDictionary.class] ? data[@"setup"] : @{}
                                        runtime:runtime
                                     processWeb:processWeb
                                 processRuntime:processRuntime
                                   requirements:[data[@"requirements"] isKindOfClass:NSDictionary.class] ? data[@"requirements"] : @{}];
}

- (NSDictionary*)dictionaryRepresentation {
  return @{
    @"id" : self.moduleIdentifier,
    @"name" : self.name,
    @"version" : self.version,
    @"description" : self.moduleDescription,
    @"type" : self.moduleType,
    @"enabled" : @(self.enabled),
    @"runtimeType" : self.runtimeType,
    @"runtime" : self.runtime,
    @"requirements" : self.requirements,
    @"currentPhpVersion" : @"",
    @"path" : self.path,
    @"routes" : self.routes,
    @"fileTypes" : self.fileTypes,
    @"fileNameContains" : self.fileNameContains,
    @"fileTypeHandler" : @{@"fileTypes" : self.fileTypeHandlerFileTypes},
    @"hooks" : self.hooks,
    @"permissions" : self.permissions,
    @"menuItems" : self.menuItems,
    @"badge" : self.badge.count > 0 ? self.badge : [NSNull null],
    @"settingsRoute" : self.settingsRoute.length > 0 ? self.settingsRoute : [NSNull null],
    @"defaultGroup" : self.defaultGroup.length > 0 ? self.defaultGroup : [NSNull null],
    @"readiness" : self.readiness.count > 0 ? self.readiness : [NSNull null],
    @"setup" : self.setup.count > 0 ? self.setup : [NSNull null],
    @"processWeb" : self.processWeb ? [self.processWeb dictionaryRepresentation] : [NSNull null],
    @"processRuntime" : self.processRuntime ? [self.processRuntime dictionaryRepresentation] : [NSNull null],
    @"hasIsolatedVendor" : @([self hasIsolatedVendor])
  };
}

- (BOOL)hasIsolatedVendor {
  NSString* autoloadPath = [[self.path stringByAppendingPathComponent:@"vendor"] stringByAppendingPathComponent:@"autoload.php"];
  return [NSFileManager.defaultManager fileExistsAtPath:autoloadPath];
}

- (instancetype)initWithModuleIdentifier:(NSString*)moduleIdentifier
                                    name:(NSString*)name
                                 version:(NSString*)version
                       moduleDescription:(NSString*)moduleDescription
                              moduleType:(NSString*)moduleType
                                 enabled:(BOOL)enabled
                             runtimeType:(NSString*)runtimeType
                                    path:(NSString*)path
                                  routes:(NSArray<NSDictionary*>*)routes
                               fileTypes:(NSArray<NSString*>*)fileTypes
                        fileNameContains:(NSArray<NSString*>*)fileNameContains
             fileTypeHandlerFileTypes:(NSArray<NSString*>*)fileTypeHandlerFileTypes
                                   hooks:(NSArray<NSString*>*)hooks
                             permissions:(NSArray<NSString*>*)permissions
                               menuItems:(NSArray<NSDictionary*>*)menuItems
                                   badge:(NSDictionary*)badge
                           settingsRoute:(NSString*)settingsRoute
                            defaultGroup:(NSString*)defaultGroup
                               readiness:(NSDictionary*)readiness
                                   setup:(NSDictionary*)setup
                                 runtime:(NSDictionary*)runtime
                              processWeb:(BabelNativeModuleProcessWebDefinition*)processWeb
                          processRuntime:(BabelNativeModuleProcessRuntimeDefinition*)processRuntime
                            requirements:(NSDictionary*)requirements {
  self = [super init];
  if (self) {
    _moduleIdentifier = [moduleIdentifier copy];
    _name = [name copy];
    _version = [version copy];
    _moduleDescription = [moduleDescription copy];
    _moduleType = [moduleType copy];
    _enabled = enabled;
    _runtimeType = [runtimeType copy];
    _path = [path copy];
    _routes = [routes copy];
    _fileTypes = [fileTypes copy];
    _fileNameContains = [fileNameContains copy];
    _fileTypeHandlerFileTypes = [fileTypeHandlerFileTypes copy];
    _hooks = [hooks copy];
    _permissions = [permissions copy];
    _menuItems = [menuItems copy];
    _badge = [badge copy];
    _settingsRoute = [settingsRoute copy];
    _defaultGroup = [defaultGroup copy];
    _readiness = [readiness copy];
    _setup = [setup copy];
    _runtime = [runtime copy];
    _processWeb = processWeb;
    _processRuntime = processRuntime;
    _requirements = [requirements copy];
  }

  return self;
}

+ (NSString*)requiredStringForKey:(NSString*)key dictionary:(NSDictionary*)dictionary error:(NSError**)error {
  NSString* value = [self optionalStringForKey:key dictionary:dictionary fallback:@""];
  if (value.length == 0) {
    [self assignError:error description:[NSString stringWithFormat:@"Module manifest must declare %@.", key]];
    return nil;
  }

  return value;
}

+ (NSString*)optionalStringForKey:(NSString*)key dictionary:(NSDictionary*)dictionary fallback:(NSString*)fallback {
  NSString* value = [dictionary[key] isKindOfClass:NSString.class] ? dictionary[key] : fallback;
  return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

+ (NSString*)trimmedOptionalStringForKey:(NSString*)key dictionary:(NSDictionary*)dictionary {
  return [self optionalStringForKey:key dictionary:dictionary fallback:@""];
}

+ (BOOL)optionalBoolForKey:(NSString*)key dictionary:(NSDictionary*)dictionary fallback:(BOOL)fallback {
  return [dictionary[key] isKindOfClass:NSNumber.class] ? [dictionary[key] boolValue] : fallback;
}

+ (NSArray<NSString*>*)stringListForKey:(NSString*)key dictionary:(NSDictionary*)dictionary lowercase:(BOOL)lowercase {
  NSArray* value = [dictionary[key] isKindOfClass:NSArray.class] ? dictionary[key] : @[];
  NSMutableArray<NSString*>* strings = [NSMutableArray array];
  for (id item in value) {
    if (![item isKindOfClass:NSString.class]) {
      continue;
    }

    NSString* string = [item stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (string.length == 0) {
      continue;
    }

    [strings addObject:lowercase ? string.lowercaseString : string];
  }

  return strings;
}

+ (NSArray<NSDictionary*>*)dictionaryListForKey:(NSString*)key dictionary:(NSDictionary*)dictionary {
  NSArray* value = [dictionary[key] isKindOfClass:NSArray.class] ? dictionary[key] : @[];
  NSMutableArray<NSDictionary*>* dictionaries = [NSMutableArray array];
  for (id item in value) {
    if ([item isKindOfClass:NSDictionary.class]) {
      [dictionaries addObject:item];
    }
  }

  return dictionaries;
}

+ (NSArray<NSString*>*)fileTypeHandlerFileTypesFromDictionary:(NSDictionary*)dictionary {
  NSDictionary* handler = [dictionary[@"file-type-handler"] isKindOfClass:NSDictionary.class]
      ? dictionary[@"file-type-handler"]
      : @{};
  return [self stringListForKey:@"fileTypes" dictionary:handler lowercase:YES];
}

+ (NSString*)settingsRouteFromDictionary:(NSDictionary*)dictionary {
  NSDictionary* settings = [dictionary[@"settings"] isKindOfClass:NSDictionary.class] ? dictionary[@"settings"] : @{};
  return [self trimmedOptionalStringForKey:@"route" dictionary:settings];
}

+ (BOOL)isValidModuleIdentifier:(NSString*)moduleIdentifier {
  NSRegularExpression* expression =
      [NSRegularExpression regularExpressionWithPattern:@"^[a-z0-9][a-z0-9.-]*[a-z0-9]$"
                                                options:0
                                                  error:nil];
  NSRange range = NSMakeRange(0, moduleIdentifier.length);
  return [expression numberOfMatchesInString:moduleIdentifier options:0 range:range] == 1;
}

+ (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelNativeModuleManifestErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Invalid module manifest."}];
}

@end
