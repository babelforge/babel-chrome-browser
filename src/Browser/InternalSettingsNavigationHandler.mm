#import "Browser/InternalSettingsNavigationHandler.h"

#import "Browser/BrowserSettingsStore.h"
#import "Browser/BrowserTheme.h"

@implementation BabelInternalSettingsNavigationResult

@synthesize markdownThemeDidChange;
@synthesize appearanceThemeDidChange;

@end

@implementation BabelInternalSettingsNavigationHandler {
  BabelBrowserSettingsStore* settingsStore_;
  NSUserDefaults* userDefaults_;
}

- (instancetype)initWithSettingsStore:(BabelBrowserSettingsStore*)settingsStore
                         userDefaults:(NSUserDefaults*)userDefaults {
  self = [super init];
  if (self) {
    settingsStore_ = settingsStore;
    userDefaults_ = userDefaults ?: NSUserDefaults.standardUserDefaults;
  }
  return self;
}

- (BabelInternalSettingsNavigationResult*)applyModuleSettingsComponents:(NSURLComponents*)components
                                                       moduleIdentifier:(NSString*)moduleIdentifier {
  BabelInternalSettingsNavigationResult* result = [[BabelInternalSettingsNavigationResult alloc] init];
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
