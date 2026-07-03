// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSString*)settingsTabOpeningStrategyHTML:(NSString*)selectedStrategy {
  NSString* originalClass = [selectedStrategy isEqualToString:BabelTabOpeningStrategyAppend]
      ? @"option selected"
      : @"option";
  NSString* childClusterClass = [selectedStrategy isEqualToString:BabelTabOpeningStrategyChildCluster]
      ? @"option selected"
      : @"option";
  return [NSString stringWithFormat:
      @"<div class='options'>"
       "<a class='%@' href='babelchrome://settings?tabOpeningStrategy=%@'>"
       "<strong>Original</strong><span>New tabs open at the end of the tab bar.</span></a>"
       "<a class='%@' href='babelchrome://settings?tabOpeningStrategy=%@'>"
       "<strong>Parent group</strong><span>New tabs opened from a page stay next to their parent tab.</span></a>"
       "</div>",
      originalClass,
      BabelTabOpeningStrategyAppend,
      childClusterClass,
      BabelTabOpeningStrategyChildCluster];
}

- (NSString*)settingsAddressSuggestionsHTML:(NSString*)selectedMode {
  NSString* localClass = [selectedMode isEqualToString:BabelAddressSuggestionsModeLocal]
      ? @"option selected"
      : @"option";
  NSString* googleClass = [selectedMode isEqualToString:BabelAddressSuggestionsModeGoogle]
      ? @"option selected"
      : @"option";
  return [NSString stringWithFormat:
      @"<div class='options'>"
       "<a class='%@' href='babelchrome://settings?addressSuggestions=%@'>"
       "<strong>Local only</strong><span>Use open tabs and recently closed tabs only.</span></a>"
       "<a class='%@' href='babelchrome://settings?addressSuggestions=%@'>"
       "<strong>Local + Google</strong><span>Also ask Google Suggest while typing.</span></a>"
       "</div>",
      localClass,
      BabelAddressSuggestionsModeLocal,
      googleClass,
      BabelAddressSuggestionsModeGoogle];
}

- (NSString*)settingsAppearanceThemeHTML:(NSString*)selectedTheme {
  NSDictionary<NSString*, NSString*>* labels = @{
    BabelThemeAppearanceSystem : @"System",
    BabelThemeAppearanceLight : @"Light",
    BabelThemeAppearanceDark : @"Dark",
  };
  NSDictionary<NSString*, NSString*>* descriptions = @{
    BabelThemeAppearanceSystem : @"Follow the current macOS appearance.",
    BabelThemeAppearanceLight : @"Always use BabelChrome light colors.",
    BabelThemeAppearanceDark : @"Always use BabelChrome dark colors.",
  };
  NSArray<NSString*>* themes = @[
    BabelThemeAppearanceSystem,
    BabelThemeAppearanceLight,
    BabelThemeAppearanceDark
  ];
  NSMutableString* html = [NSMutableString stringWithString:@"<div class='options'>"];
  for (NSString* theme in themes) {
    NSString* optionClass = [selectedTheme isEqualToString:theme] ? @"option selected" : @"option";
    [html appendFormat:
        @"<a class='%@' href='babelchrome://settings?appearanceTheme=%@'>"
         "<strong>%@</strong><span>%@</span></a>",
        optionClass,
        theme,
        [self htmlEscapedString:labels[theme]],
        [self htmlEscapedString:descriptions[theme]]];
  }
  [html appendString:@"</div>"];
  return html;
}

- (NSString*)settingsLongQuitShortcutHTML:(BOOL)enabled {
  NSString* offClass = enabled ? @"option" : @"option selected";
  NSString* onClass = enabled ? @"option selected" : @"option";
  return [NSString stringWithFormat:
      @"<div class='options'>"
       "<a class='%@' href='babelchrome://settings?longQuitShortcut=0'>"
       "<strong>Immediate Cmd+Q</strong><span>Quit as soon as Cmd+Q is pressed.</span></a>"
       "<a class='%@' href='babelchrome://settings?longQuitShortcut=1'>"
       "<strong>Long Cmd+Q</strong><span>Require Cmd+Q to be held for 2 seconds before quitting.</span></a>"
       "</div>",
      offClass,
      onClass];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme {
  return [self settingsMarkdownThemeHTML:selectedTheme settingsURLString:@"babelchrome://settings"];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme settingsURLString:(NSString*)settingsURLString {
  NSDictionary<NSString*, NSString*>* labels = @{
    BabelMarkdownThemeGitHubLight : @"GitHub Light",
    BabelMarkdownThemeGitHubDark : @"GitHub Dark",
    BabelMarkdownThemeReader : @"Reader",
    BabelMarkdownThemeCompact : @"Compact",
  };
  NSDictionary<NSString*, NSString*>* descriptions = @{
    BabelMarkdownThemeGitHubLight : @"Default technical documentation style.",
    BabelMarkdownThemeGitHubDark : @"Dark technical documentation style.",
    BabelMarkdownThemeReader : @"Wider reading rhythm for long documents.",
    BabelMarkdownThemeCompact : @"Denser rendering for reference documents.",
  };
  NSArray<NSString*>* themes = @[
    BabelMarkdownThemeGitHubLight,
    BabelMarkdownThemeGitHubDark,
    BabelMarkdownThemeReader,
    BabelMarkdownThemeCompact
  ];
  NSMutableString* html = [NSMutableString stringWithString:@"<div class='options'>"];
  for (NSString* theme in themes) {
    NSString* optionClass = [selectedTheme isEqualToString:theme] ? @"option selected" : @"option";
    [html appendFormat:
        @"<a class='%@' href='%@?markdownTheme=%@'>"
         "<strong>%@</strong><span>%@</span></a>",
        optionClass,
        [self htmlEscapedString:settingsURLString ?: @"babelchrome://settings"],
        theme,
        [self htmlEscapedString:labels[theme]],
        [self htmlEscapedString:descriptions[theme]]];
  }
  [html appendString:@"</div>"];
  return html;
}

- (NSString*)moduleSettingsIdentifierFromSettingsComponents:(NSURLComponents*)components {
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

- (NSString*)normalizedModuleSettingsIdentifier:(NSString*)moduleIdentifier {
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
  NSDictionary* snapshot = [BabelLocalServiceHost.sharedHost modulesSnapshotWithError:&error];
  if (error) {
    return nil;
  }

  NSArray* modules = [snapshot[@"modules"] isKindOfClass:NSArray.class] ? snapshot[@"modules"] : @[];
  for (NSDictionary* module in modules) {
    if (![module isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* currentIdentifier = [module[@"id"] isKindOfClass:NSString.class] ? module[@"id"] : @"";
    if (![currentIdentifier isEqualToString:moduleIdentifier ?: @""]) {
      continue;
    }

    return [module[@"name"] isKindOfClass:NSString.class] ? module[@"name"] : currentIdentifier;
  }

  return nil;
}
