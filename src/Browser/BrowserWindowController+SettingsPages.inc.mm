// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSString*)historyPageHTML {
  NSMutableArray<NSDictionary*>* openTabRows = [NSMutableArray array];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([self isInternalPageTab:tab]) {
        continue;
      }
      NSString* title = tab.title.length > 0 ? tab.title : tab.requestedURLString;
      [openTabRows addObject:@{
        BabelHistoryRowTitleKey : title ?: @"",
        BabelHistoryRowURLStringKey : tab.requestedURLString ?: tab.urlString ?: @"",
        BabelHistoryRowGroupNameKey : group.name ?: kDefaultGroupName,
      }];
    }
  }

  NSMutableArray<NSDictionary*>* recentlyClosedTabRows = [NSMutableArray array];
  NSArray<BabelClosedTab*>* closedTabs = [recentlyClosedTabStore_ allClosedTabs];
  for (NSInteger index = (NSInteger)closedTabs.count - 1; index >= 0; index--) {
    BabelClosedTab* closedTab = closedTabs[(NSUInteger)index];
    NSString* title = closedTab.title.length > 0 ? closedTab.title : closedTab.requestedURLString;
    [recentlyClosedTabRows addObject:@{
      BabelHistoryRowTitleKey : title ?: @"",
      BabelHistoryRowURLStringKey : closedTab.requestedURLString ?: closedTab.urlString ?: @"",
      BabelHistoryRowGroupNameKey : closedTab.groupName ?: kDefaultGroupName,
      BabelHistoryRowReopenIndexKey : @((NSUInteger)index),
    }];
  }

  NSString* body = [historyPageRenderer_ historyPageBodyWithOpenTabRows:openTabRows
                                                   recentlyClosedTabRows:recentlyClosedTabRows];
  return [self internalPageHTMLWithTitle:@"History" body:body];
}

- (NSString*)settingsPageHTML {
  NSString* strategy = [self tabOpeningStrategy];
  NSString* addressSuggestionsMode = [self addressSuggestionsMode];
  NSString* appearanceTheme = [BabelTheme.sharedTheme appearanceMode];
  BOOL longQuitShortcutEnabled = [browserSettingsStore_ longQuitShortcutEnabled];
  NSString* body = [appSettingsPageRenderer_ settingsPageBodyWithDefaultURLString:BabelChromeConfiguration.defaultURLString
                                                                  appearanceTheme:appearanceTheme
                                                          longQuitShortcutEnabled:longQuitShortcutEnabled
                                                               tabOpeningStrategy:strategy
                                                           addressSuggestionsMode:addressSuggestionsMode];
  return [self internalPageHTMLWithTitle:@"Settings" body:body];
}

- (NSString*)moduleSettingsPageHTMLForIdentifier:(NSString*)moduleIdentifier {
  NSString* normalizedIdentifier = [self normalizedModuleSettingsIdentifier:moduleIdentifier];
  if ([normalizedIdentifier isEqualToString:@"babelforge.markdown-viewer"]) {
    NSString* body = [NSString stringWithFormat:
        @"<h1>Markdown Viewer Settings</h1>"
         "<section>"
         "<p class='note'>These settings belong to the Markdown Viewer module, not to BabelChrome itself.</p>"
         "<dl>"
         "<dt>Markdown theme</dt><dd>%@</dd>"
         "</dl>"
         "</section>"
         "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
        [self settingsMarkdownThemeHTML:[self markdownTheme] settingsURLString:@"babelchrome://settings/babelforge.markdown-viewer"]];
    return [self internalPageHTMLWithTitle:@"Markdown Viewer Settings" body:body];
  }

  NSString* moduleName = [self moduleNameForIdentifier:normalizedIdentifier] ?: normalizedIdentifier;
  NSString* body = [NSString stringWithFormat:
      @"<h1>%@ Settings</h1>"
       "<section>"
       "<p class='empty'>This module does not expose native BabelChrome settings yet.</p>"
       "</section>"
       "<p><a class='smallButton' data-can-open-menu='true' href='babelchrome://modules'>Back to modules</a></p>",
      [self htmlEscapedString:moduleName]];
  return [self internalPageHTMLWithTitle:[NSString stringWithFormat:@"%@ Settings", moduleName] body:body];
}

- (NSString*)extensionsPageHTML {
  NSArray<NSString*>* extensionPaths = [extensionProfileStore_ installedExtensionPaths];
  NSArray<NSDictionary*>* profileExtensions = [extensionProfileStore_ profileInstalledExtensions];
  NSMutableArray<NSDictionary*>* profileExtensionRows = [NSMutableArray array];
  for (NSDictionary* extension in profileExtensions ?: @[]) {
    NSString* extensionIdentifier = [extension[@"id"] isKindOfClass:NSString.class]
        ? extension[@"id"]
        : @"";
    BOOL enabled = [extension[@"enabled"] boolValue];
    NSString* toggleAction = enabled ? @"disableProfile" : @"enableProfile";
    NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
    NSString* status = [extensionProfileStore_ profileExtensionStatusLabelForIdentifier:extensionIdentifier
                                                                                enabled:enabled];
    [profileExtensionRows addObject:@{
      BabelExtensionProfileNameKey : [extension[@"name"] isKindOfClass:NSString.class] ? extension[@"name"] : @"",
      BabelExtensionProfileIdentifierKey : extensionIdentifier ?: @"",
      BabelExtensionProfileVersionKey : [extension[@"version"] isKindOfClass:NSString.class] ? extension[@"version"] : @"",
      BabelExtensionProfilePathKey : [extension[@"path"] isKindOfClass:NSString.class] ? extension[@"path"] : @"",
      BabelExtensionProfileStatusKey : status ?: @"",
      BabelExtensionProfileToggleActionKey : toggleAction,
      BabelExtensionProfileToggleLabelKey : toggleLabel,
      BabelExtensionProfileRequiresRestartKey : @([extensionProfileStore_ profileExtensionRequiresRestart:extensionIdentifier]),
    }];
  }

  NSMutableArray<NSDictionary*>* unpackedExtensionRows = [NSMutableArray array];
  for (NSString* extensionPath in extensionPaths ?: @[]) {
    NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
    BOOL manifestExists = [NSFileManager.defaultManager fileExistsAtPath:manifestPath];
    NSString* status = manifestExists ? @"Ready after restart" : @"Missing manifest.json";
    [unpackedExtensionRows addObject:@{
      BabelUnpackedExtensionNameKey : extensionPath.lastPathComponent ?: @"",
      BabelUnpackedExtensionPathKey : extensionPath ?: @"",
      BabelUnpackedExtensionStatusKey : [NSString stringWithFormat:@"%@ - %@", status, extensionPath ?: @""],
    }];
  }

  NSString* body = [extensionsPageRenderer_ extensionsPageBodyWithProfileExtensionRows:profileExtensionRows
                                                                 unpackedExtensionRows:unpackedExtensionRows];
  return [self internalPageHTMLWithTitle:@"Extensions" body:body];
}
