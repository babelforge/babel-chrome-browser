// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSString*)historyPageHTML {
  NSMutableString* body = [NSMutableString string];
  [body appendString:@"<h1>History</h1>"];
  [body appendString:@"<h2>Open Tabs</h2><ul>"];
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([self isInternalPageTab:tab]) {
        continue;
      }
      NSString* title = tab.title.length > 0 ? tab.title : tab.requestedURLString;
      [body appendFormat:@"<li><span>%@</span><small>%@</small><em>%@</em></li>",
                         [self htmlEscapedString:title],
                         [self htmlEscapedString:tab.requestedURLString ?: tab.urlString],
                         [self htmlEscapedString:group.name ?: kDefaultGroupName]];
    }
  }
  [body appendString:@"</ul>"];

  [body appendString:@"<h2>Recently Closed Tabs</h2>"];
  if (closedTabs_.count == 0) {
    [body appendString:@"<p class='empty'>No recently closed tab.</p>"];
  } else {
    [body appendString:@"<ul>"];
    for (NSInteger index = (NSInteger)closedTabs_.count - 1; index >= 0; index--) {
      BabelClosedTab* closedTab = closedTabs_[(NSUInteger)index];
      NSString* title = closedTab.title.length > 0 ? closedTab.title : closedTab.requestedURLString;
      [body appendFormat:
          @"<li><span>%@</span><small>%@</small><em>%@</em>"
           "<div class='actions'><a class='smallButton' href='babelchrome://history?reopen=%ld'>Re-open</a></div></li>",
          [self htmlEscapedString:title],
          [self htmlEscapedString:closedTab.requestedURLString ?: closedTab.urlString],
          [self htmlEscapedString:closedTab.groupName ?: kDefaultGroupName],
          (long)index];
    }
    [body appendString:@"</ul>"];
  }
  return [self internalPageHTMLWithTitle:@"History" body:body];
}

- (NSString*)settingsPageHTML {
  NSString* strategy = [self tabOpeningStrategy];
  NSString* addressSuggestionsMode = [self addressSuggestionsMode];
  NSString* appearanceTheme = [BabelTheme.sharedTheme appearanceMode];
  BOOL longQuitShortcutEnabled =
      [NSUserDefaults.standardUserDefaults boolForKey:kLongQuitShortcutEnabledDefaultsKey];
  NSString* body = [NSString stringWithFormat:
      @"<h1>Settings</h1>"
       "<section><a class='primaryButton' data-can-open-menu='true' href='babelchrome://extensions'>Extensions</a>"
       " <a class='primaryButton' data-can-open-menu='true' href='babelchrome://modules'>PHP Modules</a></section>"
       "<section>"
       "<h2>General</h2>"
       "<dl>"
       "<dt>Default page</dt><dd>%@</dd>"
       "<dt>Application theme</dt><dd>%@</dd>"
       "<dt>Quit shortcut</dt><dd>%@</dd>"
       "<dt>Tab opening strategy</dt><dd>%@</dd>"
       "<dt>Address suggestions</dt><dd>%@</dd>"
       "<dt>Groups file</dt><dd>Stored in the BabelChrome application support folder.</dd>"
       "<dt>Developer Tools docking</dt><dd>The last selected dock mode is saved automatically.</dd>"
       "</dl>"
       "</section>",
      [self htmlEscapedString:BabelChromeConfiguration.defaultURLString],
      [self settingsAppearanceThemeHTML:appearanceTheme],
      [self settingsLongQuitShortcutHTML:longQuitShortcutEnabled],
      [self settingsTabOpeningStrategyHTML:strategy],
      [self settingsAddressSuggestionsHTML:addressSuggestionsMode]];
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
  NSArray<NSString*>* extensionPaths = [self installedExtensionPaths];
  NSArray<NSDictionary*>* profileExtensions = [self profileInstalledExtensions];
  NSMutableString* profileListHTML = [NSMutableString string];
  if (profileExtensions.count == 0) {
    [profileListHTML appendString:@"<p class='empty'>No Chrome profile extension was found.</p>"];
  } else {
    [profileListHTML appendString:@"<ul>"];
    for (NSDictionary* extension in profileExtensions) {
      NSString* extensionIdentifier = [extension[@"id"] isKindOfClass:NSString.class]
          ? extension[@"id"]
          : @"";
      BOOL enabled = [extension[@"enabled"] boolValue];
      NSString* toggleAction = enabled ? @"disableProfile" : @"enableProfile";
      NSString* toggleLabel = enabled ? @"Disable" : @"Enable";
      NSString* status = [self profileExtensionStatusLabelForIdentifier:extensionIdentifier
                                                                 enabled:enabled];
      NSString* restartHTML = [self profileExtensionRequiresRestart:extensionIdentifier]
          ? @"<a class='smallButton primarySmallButton' href='babelchrome://extensions?restart=1'>Restart</a>"
          : @"";
      [profileListHTML appendFormat:
          @"<li><span>%@</span><small>%@ - ID: %@ - Version: %@ - %@</small>"
           "<div class='actions'>%@<a class='smallButton' href='babelchrome://extensions?%@=%@'>%@</a>"
           "<a class='smallButton dangerButton iconTextButton' href='babelchrome://extensions?removeProfile=%@' title='Remove'>%@<span>Remove</span></a></div></li>",
          [self htmlEscapedString:extension[@"name"]],
          [self htmlEscapedString:status],
          [self htmlEscapedString:extensionIdentifier],
          [self htmlEscapedString:extension[@"version"]],
          [self htmlEscapedString:extension[@"path"]],
          restartHTML,
          toggleAction,
          [self queryEscapedString:extensionIdentifier],
          toggleLabel,
          [self queryEscapedString:extensionIdentifier],
          [self trashIconHTML]];
    }
    [profileListHTML appendString:@"</ul>"];
  }

  NSMutableString* unpackedListHTML = [NSMutableString string];
  if (extensionPaths.count == 0) {
    [unpackedListHTML appendString:@"<p class='empty'>No unpacked extension is configured.</p>"];
  } else {
    [unpackedListHTML appendString:@"<ul>"];
    for (NSString* extensionPath in extensionPaths) {
      NSString* manifestPath = [extensionPath stringByAppendingPathComponent:@"manifest.json"];
      BOOL manifestExists = [NSFileManager.defaultManager fileExistsAtPath:manifestPath];
      NSString* status = manifestExists ? @"Ready after restart" : @"Missing manifest.json";
      [unpackedListHTML appendFormat:
          @"<li><span>%@</span><small>%@</small><div class='actions'>"
           "<a class='smallButton dangerButton iconTextButton' href='babelchrome://extensions?remove=%@' title='Remove'>%@<span>Remove</span></a>"
           "</div></li>",
          [self htmlEscapedString:extensionPath.lastPathComponent],
          [self htmlEscapedString:[NSString stringWithFormat:@"%@ - %@", status, extensionPath]],
          [self queryEscapedString:extensionPath],
          [self trashIconHTML]];
    }
    [unpackedListHTML appendString:@"</ul>"];
  }

  NSString* body = [NSString stringWithFormat:
      @"<h1>Extensions</h1>"
       "<section>"
       "<h2>Chrome Web Store</h2>"
       "<form method='get' action='babelchrome://extensions' class='searchForm'>"
       "<input type='search' name='search' placeholder='Search extensions' autofocus>"
       "<button type='submit'>Search</button>"
       "</form>"
       "</section>"
       "<section>"
       "<h2>Chrome Profile Extensions</h2>"
       "<p class='note'>Extensions installed by Chromium in the BabelChrome profile are listed here. Disable and Enable changes are applied on the next BabelChrome restart.</p>"
       "%@"
       "</section>"
       "<section>"
       "<h2>Unpacked Extensions</h2>"
       "<p class='note'>BabelChrome loads configured unpacked extension folders at startup. Changes require restarting BabelChrome.</p>"
       "<p><a class='primaryButton' href='babelchrome://extensions?addUnpacked=1'>Add unpacked extension folder</a></p>"
       "%@"
       "</section>"
       "<div class='bottomButtonRow'><a class='smallButton' data-can-open-menu='true' href='babelchrome://settings'>Back to Settings</a></div>",
      profileListHTML,
      unpackedListHTML];
  return [self internalPageHTMLWithTitle:@"Extensions" body:body];
}
