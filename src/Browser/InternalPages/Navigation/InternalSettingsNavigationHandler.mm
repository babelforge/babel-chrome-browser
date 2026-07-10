#import "Browser/InternalPages/Navigation/InternalSettingsNavigationHandler.h"

#import "Browser/Modules/Core/ModuleActionService.h"
#import "Browser/State/Settings/BrowserSettingsStore.h"
#import "Browser/UI/Theme/BrowserTheme.h"

@implementation BabelInternalSettingsNavigationResult

@synthesize markdownThemeDidChange;
@synthesize appearanceThemeDidChange;

@end

@implementation BabelInternalSettingsNavigationHandler {
  BabelBrowserSettingsStore* settingsStore_;
  BabelModuleActionService* moduleActionService_;
  NSUserDefaults* userDefaults_;
}

- (instancetype)initWithSettingsStore:(BabelBrowserSettingsStore*)settingsStore
                   moduleActionService:(BabelModuleActionService*)moduleActionService
                         userDefaults:(NSUserDefaults*)userDefaults {
  self = [super init];
  if (self) {
    settingsStore_ = settingsStore;
    moduleActionService_ = moduleActionService;
    userDefaults_ = userDefaults ?: NSUserDefaults.standardUserDefaults;
  }
  return self;
}

- (BabelInternalSettingsNavigationResult*)applyModuleSettingsComponents:(NSURLComponents*)components
                                                       moduleIdentifier:(NSString*)moduleIdentifier {
  BabelInternalSettingsNavigationResult* result = [[BabelInternalSettingsNavigationResult alloc] init];
  [self applyRequiredRuntimeSettingComponents:components moduleIdentifier:moduleIdentifier];

  if (![moduleIdentifier isEqualToString:@"babelforge.markdown-viewer"]) {
    return result;
  }

  for (NSURLQueryItem* item in components.queryItems) {
    if (![item.name isEqualToString:@"markdownTheme"]) {
      continue;
    }

    NSString* previousTheme = [settingsStore_ markdownTheme];
    if ([settingsStore_ setMarkdownTheme:item.value]) {
      result.markdownThemeDidChange = ![previousTheme isEqualToString:item.value];
      break;
    }
  }

  return result;
}

- (void)applyRequiredRuntimeSettingComponents:(NSURLComponents*)components
                             moduleIdentifier:(NSString*)moduleIdentifier {
  NSString* settingKey = @"";
  NSString* settingValue = nil;
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:@"runtimeSettingKey"]) {
      settingKey = item.value ?: @"";
    }
    if ([item.name isEqualToString:@"runtimeSettingValue"]) {
      settingValue = item.value ?: @"";
    }
  }

  if (settingKey.length == 0 || !settingValue) {
    return;
  }

  NSError* error = nil;
  [moduleActionService_ setRequiredSettingValue:settingValue
                                         forKey:settingKey
                           moduleWithIdentifier:moduleIdentifier
                                          error:&error];
}

- (BabelInternalSettingsNavigationResult*)applyApplicationSettingsComponents:(NSURLComponents*)components {
  BabelInternalSettingsNavigationResult* result = [[BabelInternalSettingsNavigationResult alloc] init];
  for (NSURLQueryItem* item in components.queryItems) {
    if ([item.name isEqualToString:@"tabOpeningStrategy"] &&
        [settingsStore_ setTabOpeningStrategy:item.value]) {
      break;
    }

    if ([item.name isEqualToString:@"longQuitShortcut"]) {
      BOOL enabled = [item.value isEqualToString:@"1"] ||
                     [[item.value lowercaseString] isEqualToString:@"true"];
      [settingsStore_ setLongQuitShortcutEnabled:enabled];
      break;
    }

    if ([item.name isEqualToString:@"addressSuggestions"] &&
        [settingsStore_ setAddressSuggestionsMode:item.value]) {
      break;
    }

    if ([item.name isEqualToString:@"markdownTheme"]) {
      NSString* previousTheme = [settingsStore_ markdownTheme];
      if ([settingsStore_ setMarkdownTheme:item.value]) {
        result.markdownThemeDidChange = ![previousTheme isEqualToString:item.value];
        break;
      }
    }

    if ([item.name isEqualToString:@"appearanceTheme"] &&
        [BabelTheme.sharedTheme isSupportedAppearanceMode:item.value]) {
      NSString* previousTheme = [BabelTheme.sharedTheme appearanceMode];
      [userDefaults_ setObject:item.value forKey:BabelThemeAppearanceDefaultsKey];
      [userDefaults_ synchronize];
      result.appearanceThemeDidChange = ![previousTheme isEqualToString:item.value];
      break;
    }
  }

  return result;
}

@end
