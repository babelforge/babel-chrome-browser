#import "Browser/Modules/Navigation/ModuleSettingsRouteResolver.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Registry/NativeModuleRegistry.h"

@implementation BabelModuleSettingsRouteResolver

- (NSString*)moduleIdentifierFromSettingsComponents:(NSURLComponents*)components {
  NSString* path = components.path ?: @"";
  if ([path hasPrefix:@"/"]) {
    path = [path substringFromIndex:1];
  }
  if (path.length > 0) {
    return path;
  }

  NSString* fragment = components.fragment ?: @"";
  if (fragment.length > 0) {
    return fragment;
  }

  return @"";
}

- (NSString*)normalizedModuleIdentifier:(NSString*)moduleIdentifier {
  NSString* normalizedIdentifier =
      [moduleIdentifier stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
  if (normalizedIdentifier.length == 0) {
    return @"";
  }

  if ([normalizedIdentifier containsString:@"."]) {
    return normalizedIdentifier;
  }

  return [@"babelforge." stringByAppendingString:normalizedIdentifier];
}

- (NSString*)moduleNameForIdentifier:(NSString*)moduleIdentifier {
  NSError* error = nil;
  BabelNativeModuleRegistry* registry = [[BabelNativeModuleRegistry alloc] init];
  BabelNativeModuleManifest* module = [registry moduleWithIdentifier:moduleIdentifier ?: @"" error:&error];
  if (!module || error) {
    return nil;
  }

  return module.name.length > 0 ? module.name : module.moduleIdentifier;
}

@end
