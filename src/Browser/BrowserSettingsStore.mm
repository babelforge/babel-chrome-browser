#import "Browser/BrowserSettingsStore.h"

NSString* const BabelTabOpeningStrategyAppend = @"append";
NSString* const BabelTabOpeningStrategyAfterSelected = @"after-selected";
NSString* const BabelTabOpeningStrategyChildCluster = @"child-cluster";
NSString* const BabelAddressSuggestionsModeLocal = @"local";
NSString* const BabelAddressSuggestionsModeGoogle = @"google";
NSString* const BabelMarkdownThemeGitHubLight = @"github-light";
NSString* const BabelMarkdownThemeGitHubDark = @"github-dark";
NSString* const BabelMarkdownThemeReader = @"reader";
NSString* const BabelMarkdownThemeCompact = @"compact";

static NSString* const kAddressSuggestionsModeDefaultsKey = @"AddressSuggestionsMode";
static NSString* const kTabOpeningStrategyDefaultsKey = @"TabOpeningStrategy";
static NSString* const kMarkdownThemeDefaultsKey = @"MarkdownTheme";
static NSString* const kLongQuitShortcutEnabledDefaultsKey = @"LongQuitShortcutEnabled";

@implementation BabelBrowserSettingsStore {
  NSUserDefaults* userDefaults_;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults {
  self = [super init];
  if (self) {
    userDefaults_ = userDefaults ?: NSUserDefaults.standardUserDefaults;
  }
  return self;
}

- (NSString*)tabOpeningStrategy {
  NSString* strategy = [userDefaults_ stringForKey:kTabOpeningStrategyDefaultsKey];
  if ([self isSupportedTabOpeningStrategy:strategy]) {
    return strategy;
  }
  return BabelTabOpeningStrategyChildCluster;
}

- (BOOL)setTabOpeningStrategy:(NSString*)strategy {
  if (![self isSupportedTabOpeningStrategy:strategy]) {
    return NO;
  }

  [userDefaults_ setObject:strategy forKey:kTabOpeningStrategyDefaultsKey];
  [userDefaults_ synchronize];
  return YES;
}

- (BOOL)isSupportedTabOpeningStrategy:(NSString*)strategy {
  return [strategy isEqualToString:BabelTabOpeningStrategyAppend] ||
         [strategy isEqualToString:BabelTabOpeningStrategyAfterSelected] ||
         [strategy isEqualToString:BabelTabOpeningStrategyChildCluster];
}

- (NSString*)addressSuggestionsMode {
  NSString* mode = [userDefaults_ stringForKey:kAddressSuggestionsModeDefaultsKey];
  if ([self isSupportedAddressSuggestionsMode:mode]) {
    return mode;
  }
  return BabelAddressSuggestionsModeLocal;
}

- (BOOL)setAddressSuggestionsMode:(NSString*)mode {
  if (![self isSupportedAddressSuggestionsMode:mode]) {
    return NO;
  }

  [userDefaults_ setObject:mode forKey:kAddressSuggestionsModeDefaultsKey];
  [userDefaults_ synchronize];
  return YES;
}

- (BOOL)isSupportedAddressSuggestionsMode:(NSString*)mode {
  return [mode isEqualToString:BabelAddressSuggestionsModeLocal] ||
         [mode isEqualToString:BabelAddressSuggestionsModeGoogle];
}

- (NSString*)markdownTheme {
  NSString* theme = [userDefaults_ stringForKey:kMarkdownThemeDefaultsKey];
  if ([self isSupportedMarkdownTheme:theme]) {
    return theme;
  }
  return BabelMarkdownThemeGitHubLight;
}

- (BOOL)setMarkdownTheme:(NSString*)theme {
  if (![self isSupportedMarkdownTheme:theme]) {
    return NO;
  }

  [userDefaults_ setObject:theme forKey:kMarkdownThemeDefaultsKey];
  [userDefaults_ synchronize];
  return YES;
}

- (BOOL)isSupportedMarkdownTheme:(NSString*)theme {
  return [theme isEqualToString:BabelMarkdownThemeGitHubLight] ||
         [theme isEqualToString:BabelMarkdownThemeGitHubDark] ||
         [theme isEqualToString:BabelMarkdownThemeReader] ||
         [theme isEqualToString:BabelMarkdownThemeCompact];
}

- (BOOL)longQuitShortcutEnabled {
  return [userDefaults_ boolForKey:kLongQuitShortcutEnabledDefaultsKey];
}

- (void)setLongQuitShortcutEnabled:(BOOL)enabled {
  [userDefaults_ setBool:enabled forKey:kLongQuitShortcutEnabledDefaultsKey];
  [userDefaults_ synchronize];
}

@end
