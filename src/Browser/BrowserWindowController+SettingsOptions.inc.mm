// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSString*)settingsTabOpeningStrategyHTML:(NSString*)selectedStrategy {
  return [settingsOptionRenderer_ tabOpeningStrategyHTMLWithSelectedStrategy:selectedStrategy];
}

- (NSString*)settingsAddressSuggestionsHTML:(NSString*)selectedMode {
  return [settingsOptionRenderer_ addressSuggestionsHTMLWithSelectedMode:selectedMode];
}

- (NSString*)settingsAppearanceThemeHTML:(NSString*)selectedTheme {
  return [settingsOptionRenderer_ appearanceThemeHTMLWithSelectedTheme:selectedTheme];
}

- (NSString*)settingsLongQuitShortcutHTML:(BOOL)enabled {
  return [settingsOptionRenderer_ longQuitShortcutHTMLWithEnabledState:enabled];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme {
  return [self settingsMarkdownThemeHTML:selectedTheme settingsURLString:@"babelchrome://settings"];
}

- (NSString*)settingsMarkdownThemeHTML:(NSString*)selectedTheme settingsURLString:(NSString*)settingsURLString {
  return [settingsOptionRenderer_ markdownThemeHTMLWithSelectedTheme:selectedTheme
                                                   settingsURLString:settingsURLString];
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
