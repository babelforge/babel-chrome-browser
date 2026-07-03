// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (NSData*)persistedGroupsAndTabsStateData {
  return [groupSessionStore_ persistedGroupsAndTabsStateData];
}

- (NSDictionary*)persistedGroupsAndTabsStateFromData:(NSData*)data {
  return [groupSessionStore_ persistedGroupsAndTabsStateFromData:data];
}

- (void)restoreSessionTabsFromState:(NSDictionary*)state {
  [self restoreGroupsFromState:state];
}

- (void)restoreSessionGroupsFromState:(NSDictionary*)state {
  BabelBrowserGroup* defaultGroup = [self groupWithIdentifier:kDefaultGroupIdentifier];
  if (!defaultGroup) {
    defaultGroup = [self createGroupWithName:kDefaultGroupName identifier:kDefaultGroupIdentifier];
  }

  NSString* selectedGroupIdentifier = [self persistedSelectedGroupIdentifierFromState:state];
  BabelBrowserGroup* groupToSelect = [self groupWithIdentifier:selectedGroupIdentifier] ?: defaultGroup;
  [self selectGroup:groupToSelect];
  [self saveGroupsState];
}

- (NSString*)persistedSelectedGroupIdentifierFromState:(NSDictionary*)state {
  return [groupSessionStore_ selectedGroupIdentifierFromState:state
                                           fallbackIdentifier:kDefaultGroupIdentifier];
}

- (void)restoreGroupsFromState:(NSDictionary*)state {
  NSArray* groupStates = state[@"groups"];
  if (![groupStates isKindOfClass:NSArray.class]) {
    return;
  }

  for (NSDictionary* groupState in groupStates) {
    if (![groupState isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSString* groupName = groupState[@"name"];
    NSString* groupIdentifier = groupState[@"id"];
    if (groupName.length == 0 || groupIdentifier.length == 0) {
      continue;
    }

    BabelBrowserGroup* group = [self createGroupWithName:groupName identifier:groupIdentifier];
    group.selectedTabIdentifier = groupState[@"selectedTabId"];

    NSArray* tabStates = groupState[@"tabs"];
    if (![tabStates isKindOfClass:NSArray.class]) {
      continue;
    }

    for (NSDictionary* tabState in tabStates) {
      if (![tabState isKindOfClass:NSDictionary.class]) {
        continue;
      }

      NSString* urlString = tabState[@"url"];
      if (urlString.length == 0) {
        continue;
      }

      NSString* requestedURLString = tabState[@"requestedUrl"] ?: urlString;
      NSString* restoredNavigationURLString =
          [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
      if (restoredNavigationURLString.length > 0) {
        urlString = restoredNavigationURLString;
      } else if ([self isStableBabelChromeURLString:requestedURLString]) {
        urlString = requestedURLString;
      }
      if ([self tabWithURLString:requestedURLString inGroup:group] ||
          [self tabWithURLString:urlString inGroup:group]) {
        continue;
      }

      NSString* tabIdentifier = tabState[@"id"] ?: NSUUID.UUID.UUIDString;
      NSString* title = tabState[@"title"] ?: urlString;
      BabelBrowserTab* tab = [self makeTabForURL:urlString
                                      identifier:tabIdentifier
                                           title:title];
      tab.requestedURLString = requestedURLString;
      tab.parentTabIdentifier = tabState[@"parentTabId"];
      [group.tabs addObject:tab];
      [pagesPanel_ addSubview:tab.hostView];
      [pagesPanel_ addSubview:tab.developerToolsPanelView];
    }
  }
}

- (BabelBrowserGroup*)createGroupWithName:(NSString*)name identifier:(NSString*)identifier {
  BabelBrowserGroup* existingGroup = [self groupWithIdentifier:identifier];
  if (existingGroup) {
    return existingGroup;
  }

  BabelBrowserGroup* group = [[BabelBrowserGroup alloc] init];
  group.identifier = identifier;
  group.name = name;
  group.groupItemView = [[BabelGroupItemView alloc] initWithIdentifier:identifier title:name];
  group.groupItemView.target = self;
  group.groupItemView.action = @selector(selectGroupFromItem:);
  group.groupItemView.renameTarget = self;
  group.groupItemView.renameAction = @selector(renameGroupFromMenu:);
  group.groupItemView.deleteTarget = self;
  group.groupItemView.deleteAction = @selector(deleteGroupFromMenu:);
  group.groupItemView.dragTarget = self;
  group.groupItemView.dragAction = @selector(dragGroupFromItem:);
  group.groupItemView.dragEndTarget = self;
  group.groupItemView.dragEndAction = @selector(finishDraggingGroupFromItem:);
  [groups_ addObject:group];
  [groupsListView_ addSubview:group.groupItemView];
  [self layoutGroupItems];
  return group;
}

- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier {
  if (identifier.length == 0) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups_) {
    if ([group.identifier isEqualToString:identifier]) {
      return group;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)groupWithName:(NSString*)name {
  for (BabelBrowserGroup* group in groups_) {
    if ([group.name isEqualToString:name]) {
      return group;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)ensureGroupNamed:(NSString*)name {
  NSString* normalizedName = name.length > 0 ? name : kDefaultGroupName;
  BabelBrowserGroup* existingGroup = [self groupWithName:normalizedName];
  if (existingGroup) {
    return existingGroup;
  }

  NSString* identifier = [normalizedName isEqualToString:kDefaultGroupName]
      ? kDefaultGroupIdentifier
      : NSUUID.UUID.UUIDString;
  return [self createGroupWithName:normalizedName identifier:identifier];
}

- (BabelBrowserGroup*)targetGroupForModuleIdentifier:(NSString*)moduleIdentifier
                                      fallbackGroup:(BabelBrowserGroup*)fallbackGroup {
  NSString* defaultGroupName = [moduleActionService_ defaultGroupNameForModuleIdentifier:moduleIdentifier];
  if (defaultGroupName.length > 0) {
    return [self ensureGroupNamed:defaultGroupName];
  }

  return fallbackGroup ?: [self ensureGroupNamed:kDefaultGroupName];
}

- (NSString*)nextManualGroupName {
  NSUInteger index = 1;
  while ([self groupWithName:[NSString stringWithFormat:@"Group %lu", (unsigned long)index]]) {
    index++;
  }
  return [NSString stringWithFormat:@"Group %lu", (unsigned long)index];
}

- (void)addGroupFromButton:(id)sender {
  NSString* groupName = [self nextManualGroupName];
  BabelBrowserGroup* group = [self createGroupWithName:groupName identifier:NSUUID.UUID.UUIDString];
  [self selectGroup:group];
  [self createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  [self saveGroupsState];
}

- (void)selectGroupFromItem:(BabelGroupItemView*)groupItemView {
  BabelBrowserGroup* group = [self groupWithIdentifier:groupItemView.identifier];
  if (group) {
    [self selectGroup:group];
    [self saveGroupsState];
  }
}

- (void)dragGroupFromItem:(BabelGroupItemView*)groupItemView {
  BabelBrowserGroup* group = [self groupWithIdentifier:groupItemView.identifier];
  if (!group) {
    return;
  }

  NSUInteger currentIndex = [groups_ indexOfObject:group];
  if (currentIndex == NSNotFound) {
    return;
  }

  NSEvent* currentEvent = NSApp.currentEvent;
  NSPoint listPoint = [groupsListView_ convertPoint:currentEvent.locationInWindow fromView:nil];
  NSUInteger targetIndex = [self groupInsertionIndexForListY:listPoint.y];
  if (targetIndex > currentIndex) {
    targetIndex--;
  }
  targetIndex = MIN(targetIndex, groups_.count - 1);
  if (targetIndex == currentIndex) {
    return;
  }

  isReorderingGroups_ = YES;
  [groups_ removeObjectAtIndex:currentIndex];
  [groups_ insertObject:group atIndex:targetIndex];
  [self layoutGroupItems];
}

- (NSUInteger)groupInsertionIndexForListY:(CGFloat)y {
  return [groupListCoordinator_ insertionIndexForListY:y groupCount:groups_.count];
}

- (void)finishDraggingGroupFromItem:(BabelGroupItemView*)groupItemView {
  if (!isReorderingGroups_) {
    return;
  }

  isReorderingGroups_ = NO;
  [self layoutGroupItems];
  [self saveGroupsState];
}

- (void)selectGroup:(BabelBrowserGroup*)group {
  selectedGroup_ = group;
  tabs_ = group.tabs;

  for (BabelBrowserGroup* currentGroup in groups_) {
    currentGroup.groupItemView.selected = currentGroup == group;
    for (BabelBrowserTab* tab in currentGroup.tabs) {
      if (tab != draggingTab_) {
        [tab.tabItemView removeFromSuperview];
      }
      tab.hostView.hidden = YES;
      tab.developerToolsPanelView.hidden = YES;
    }
  }

  for (BabelBrowserTab* tab in tabs_) {
    if (tab.tabItemView.superview != tabsItemsPanel_) {
      [tabsItemsPanel_ addSubview:tab.tabItemView];
    }
  }

  BabelBrowserTab* tabToSelect = [self tabWithIdentifier:group.selectedTabIdentifier inGroup:group] ?:
      tabs_.lastObject;
  if (tabToSelect) {
    [self selectTab:tabToSelect];
  } else {
    selectedTab_ = nil;
    [self clearAddressBar];
    [self updateWindowTitleForSelectedTab];
    [self layoutTabItemsSelectingLastTab:NO];
  }
  [self layoutGroupItems];
}

- (void)deleteGroupFromMenu:(NSMenuItem*)menuItem {
  NSString* groupIdentifier = menuItem.representedObject;
  BabelBrowserGroup* group = [self groupWithIdentifier:groupIdentifier];
  if (!group || groups_.count <= 1) {
    return;
  }

  NSUInteger groupIndex = [groups_ indexOfObject:group];
  BabelBrowserGroup* nextGroup = [self groupToSelectAfterDeletingGroupAtIndex:groupIndex];
  [self deleteGroup:group selectingGroup:nextGroup];
}

- (void)renameGroupFromMenu:(NSMenuItem*)menuItem {
  NSString* groupIdentifier = menuItem.representedObject;
  BabelBrowserGroup* group = [self groupWithIdentifier:groupIdentifier];
  if (!group) {
    return;
  }

  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Rename Group";
  alert.informativeText = @"Enter the new group name.";
  [alert addButtonWithTitle:@"Rename"];
  [alert addButtonWithTitle:@"Cancel"];

  NSTextField* textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 28)];
  textField.stringValue = group.name ?: @"";
  alert.accessoryView = textField;

  NSModalResponse response = [alert runModal];
  if (response != NSAlertFirstButtonReturn) {
    return;
  }

  NSString* newName = [textField.stringValue stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (newName.length == 0 || [newName isEqualToString:group.name]) {
    return;
  }

  BabelBrowserGroup* existingGroup = [self groupWithName:newName];
  if (existingGroup && existingGroup != group) {
    [self showGroupRenameDuplicateNameAlert:newName];
    return;
  }

  group.name = newName;
  group.groupItemView.title = newName;
  [self saveGroupsState];
}

- (void)showGroupRenameDuplicateNameAlert:(NSString*)groupName {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Group Name Already Exists";
  alert.informativeText = [NSString stringWithFormat:@"A group named \"%@\" already exists.",
                                                     groupName];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

- (BabelBrowserGroup*)groupToSelectAfterDeletingGroupAtIndex:(NSUInteger)groupIndex {
  if (groups_.count <= 1) {
    return nil;
  }

  NSUInteger nextIndex = groupIndex > 0 ? groupIndex - 1 : 1;
  return groups_[nextIndex];
}

- (void)deleteGroup:(BabelBrowserGroup*)group selectingGroup:(BabelBrowserGroup*)nextGroup {
  BOOL deletingSelectedGroup = group == selectedGroup_;
  for (BabelBrowserTab* tab in [group.tabs copy]) {
    CefRefPtr<CefBrowser> browser = [tab browser];
    [self pushClosedTab:tab fromGroup:group];
    [self removeTab:tab fromGroup:group allowSelection:!deletingSelectedGroup];
    if (browser) {
      browser->GetHost()->CloseBrowser(true);
    }
  }

  [group.groupItemView removeFromSuperview];
  [groups_ removeObject:group];

  if (deletingSelectedGroup) {
    [self selectGroup:nextGroup ?: groups_.firstObject];
  } else {
    [self layoutGroupItems];
  }

  [self saveGroupsState];
}

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier inGroup:(BabelBrowserGroup*)group {
  if (identifier.length == 0) {
    return nil;
  }

  for (BabelBrowserTab* tab in group.tabs) {
    if ([tab.identifier isEqualToString:identifier]) {
      return tab;
    }
  }
  return nil;
}

- (BabelBrowserTab*)tabWithURLString:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  for (BabelBrowserTab* tab in group.tabs) {
    if ([self tab:tab matchesURLString:urlString]) {
      return tab;
    }
  }
  return nil;
}

- (BOOL)tab:(BabelBrowserTab*)tab matchesURLString:(NSString*)urlString {
  if ([tab.urlString isEqualToString:urlString] ||
      [tab.requestedURLString isEqualToString:urlString]) {
    return YES;
  }

  NSString* normalizedURLString = [self URLStringByRemovingTrailingSlash:urlString];
  if ([[self URLStringByRemovingTrailingSlash:tab.urlString] isEqualToString:normalizedURLString] ||
      [[self URLStringByRemovingTrailingSlash:tab.requestedURLString] isEqualToString:normalizedURLString]) {
    return YES;
  }

  return [self rootURLString:urlString matchesURLString:tab.urlString] ||
         [self rootURLString:urlString matchesURLString:tab.requestedURLString];
}

- (NSString*)URLStringByRemovingTrailingSlash:(NSString*)urlString {
  if (urlString.length > 1 && [urlString hasSuffix:@"/"]) {
    return [urlString substringToIndex:urlString.length - 1];
  }
  return urlString ?: @"";
}

- (BOOL)rootURLString:(NSString*)rootURLString matchesURLString:(NSString*)candidateURLString {
  NSURLComponents* rootComponents = [NSURLComponents componentsWithString:rootURLString];
  NSURLComponents* candidateComponents = [NSURLComponents componentsWithString:candidateURLString];
  if (rootComponents.scheme.length == 0 || candidateComponents.scheme.length == 0) {
    return NO;
  }

  NSString* rootPath = rootComponents.path ?: @"";
  if (rootPath.length > 0 && ![rootPath isEqualToString:@"/"]) {
    return NO;
  }

  BOOL sameScheme = [rootComponents.scheme isEqualToString:candidateComponents.scheme];
  BOOL sameHost = [rootComponents.host isEqualToString:candidateComponents.host];
  NSNumber* rootPort = rootComponents.port ?: @([rootComponents.scheme isEqualToString:@"https"] ? 443 : 80);
  NSNumber* candidatePort = candidateComponents.port ?:
      @([candidateComponents.scheme isEqualToString:@"https"] ? 443 : 80);
  return sameScheme && sameHost && [rootPort isEqualToNumber:candidatePort];
}

- (void)saveGroupsState {
  [groupSessionStore_ saveGroups:groups_
          selectedGroupIdentifier:selectedGroup_.identifier
  fallbackSelectedGroupIdentifier:kDefaultGroupIdentifier
              excludingTabsMatching:^BOOL(BabelBrowserTab* tab) {
    return [self isInternalPageTab:tab];
  }];
}
- (void)showMainWindow {
  [self restoreSessionWindowZoom];
  [self layoutInterfaceForCurrentSplitViewSize];
  [self restoreSessionSidebarAfterInitialLayout];
  [self.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                        identifier:(NSString*)identifier
                             title:(NSString*)title {
  BabelBrowserTab* tab = [[BabelBrowserTab alloc] init];
  tab.identifier = identifier ?: NSUUID.UUID.UUIDString;
  tab.urlString = urlString;
  tab.requestedURLString = urlString;
  tab.title = title ?: urlString;
  tab.hostView = [[BabelPageContainerView alloc] initWithFrame:pagesPanel_.bounds];
  __weak BabelBrowserWindowController* weakSelf = self;
  tab.hostView.canAcceptLocalDrop = ^BOOL(BabelPageContainerView* container) {
    return [weakSelf pageContainerSupportsLocalDrop:container];
  };
  tab.hostView.localDropHandler = ^(BabelPageContainerView* container) {
    [weakSelf pageContainerDidReceiveLocalDrop:container];
  };
  tab.hostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.hostView.hidden = YES;

  tab.developerToolsPanelView = [[NSView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsPanelView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsPanelView.hidden = YES;
  tab.developerToolsPanelView.wantsLayer = YES;
  tab.developerToolsPanelView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.panel.background"
                                         view:tab.developerToolsPanelView];

  tab.developerToolsToolbarView = [[NSView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsToolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  tab.developerToolsToolbarView.wantsLayer = YES;
  tab.developerToolsToolbarView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.toolbar.background"
                                         view:tab.developerToolsToolbarView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsToolbarView];

  tab.developerToolsResizeHandleView =
      [[BabelDeveloperToolsResizeHandleView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsResizeHandleView.resizeTarget = self;
  tab.developerToolsResizeHandleView.resizeAction = @selector(resizeDeveloperToolsFromHandle:);
  tab.developerToolsResizeHandleView.wantsLayer = YES;
  tab.developerToolsResizeHandleView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.handle.background"
                                         view:tab.developerToolsResizeHandleView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsResizeHandleView];

  tab.developerToolsHostView = [[BabelBrowserHostView alloc] initWithFrame:NSZeroRect];
  tab.developerToolsHostView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  tab.developerToolsHostView.wantsLayer = YES;
  tab.developerToolsHostView.layer.backgroundColor =
      [BabelTheme.sharedTheme cgColorForToken:@"developerTools.panel.background"
                                         view:tab.developerToolsHostView];
  [tab.developerToolsPanelView addSubview:tab.developerToolsHostView];
  [self addDeveloperToolsControlsToTab:tab];
  tab.developerToolsVisible = NO;

  tab.tabItemView = [[BabelTabItemView alloc] initWithIdentifier:tab.identifier
                                                          title:[self compactTitleForString:tab.title]];
  tab.tabItemView.faviconImage = [faviconStore_ faviconImageForURLString:tab.urlString];
  tab.tabItemView.target = self;
  tab.tabItemView.action = @selector(selectTabFromItem:);
  tab.tabItemView.closeTarget = self;
  tab.tabItemView.closeAction = @selector(closeTabFromItem:);
  tab.tabItemView.dragTarget = self;
  tab.tabItemView.dragAction = @selector(dragTabFromItem:);
  tab.tabItemView.dragEndTarget = self;
  tab.tabItemView.dragEndAction = @selector(finishDraggingTabFromItem:);
  return tab;
}

- (void)addDeveloperToolsControlsToTab:(BabelBrowserTab*)tab {
  NSArray<NSButton*>* buttons = @[
    [self developerToolsButtonWithImageName:@"devtools-close"
                              fallbackTitle:@"x"
                                toolTip:@"Close Developer Tools"
                                    tag:0
                                 action:@selector(closeDeveloperToolsFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-left"
                              fallbackTitle:@"L"
                                toolTip:@"Dock Developer Tools Left"
                                    tag:kDeveloperToolsDockTagLeft
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-right"
                              fallbackTitle:@"R"
                                toolTip:@"Dock Developer Tools Right"
                                    tag:kDeveloperToolsDockTagRight
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-bottom"
                              fallbackTitle:@"B"
                                toolTip:@"Dock Developer Tools Bottom"
                                    tag:kDeveloperToolsDockTagBottom
                                 action:@selector(changeDeveloperToolsDockFromButton:)],
    [self developerToolsButtonWithImageName:@"devtools-dock-top"
                              fallbackTitle:@"T"
                                toolTip:@"Dock Developer Tools Top"
                                    tag:kDeveloperToolsDockTagTop
                                 action:@selector(changeDeveloperToolsDockFromButton:)]
  ];

  CGFloat x = 8.0;
  for (NSButton* button in buttons) {
    button.frame = NSMakeRect(x, 4.0, 26.0, 22.0);
    [tab.developerToolsToolbarView addSubview:button];
    x += 30.0;
  }
}

- (NSButton*)developerToolsButtonWithImageName:(NSString*)imageName
                                 fallbackTitle:(NSString*)fallbackTitle
                                       toolTip:(NSString*)toolTip
                                           tag:(NSInteger)tag
                                        action:(SEL)action {
  NSButton* button = BabelButton(fallbackTitle, self, action);
  button.bezelStyle = NSBezelStyleTexturedRounded;
  button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  button.toolTip = toolTip;
  button.tag = tag;
  ConfigureIconButton(button, imageName, fallbackTitle);
  return button;
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  BabelBrowserTab* tab = [self makeTabForURL:urlString identifier:nil title:urlString];
  [group.tabs addObject:tab];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self saveGroupsState];
  return tab;
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab {
  return [self createTabForURL:urlString
                       inGroup:group
                     parentTab:parentTab
          respectingUserStrategy:YES];
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab
   respectingUserStrategy:(BOOL)respectingUserStrategy {
  BabelBrowserTab* tab = [self makeTabForURL:urlString identifier:nil title:urlString];
  tab.parentTabIdentifier = parentTab.identifier;
  [self insertTab:tab
          inGroup:group
        parentTab:parentTab
 respectingUserStrategy:respectingUserStrategy];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self saveGroupsState];
  return tab;
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab {
  [self insertTab:tab
          inGroup:group
        parentTab:parentTab
 respectingUserStrategy:YES];
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
 respectingUserStrategy:(BOOL)respectingUserStrategy {
  NSArray<NSString*>* tabIdentifiers = [self tabIdentifiersForGroup:group];
  NSString* parentTabIdentifier = parentTab.identifier ?: @"";
  if ([tabPlacementPolicy_ shouldAppendTabWithParentIdentifier:parentTabIdentifier
                                                tabIdentifiers:tabIdentifiers
                                                      strategy:[self tabOpeningStrategy]
                                        respectingUserStrategy:respectingUserStrategy]) {
    [group.tabs addObject:tab];
    return;
  }

  NSUInteger insertionIndex =
      [tabPlacementPolicy_ insertionIndexForNewChildOfParentIdentifier:parentTabIdentifier
                                                        tabIdentifiers:tabIdentifiers
                                      parentIdentifiersByTabIdentifier:[self parentIdentifiersByTabIdentifierForGroup:group]
                                                              strategy:[self tabOpeningStrategy]];
  [group.tabs insertObject:tab atIndex:MIN(insertionIndex, group.tabs.count)];
}

- (NSArray<NSString*>*)tabIdentifiersForGroup:(BabelBrowserGroup*)group {
  NSMutableArray<NSString*>* tabIdentifiers = [NSMutableArray array];
  for (BabelBrowserTab* tab in group.tabs) {
    if (tab.identifier.length > 0) {
      [tabIdentifiers addObject:tab.identifier];
    }
  }
  return tabIdentifiers;
}

- (NSDictionary<NSString*, NSString*>*)parentIdentifiersByTabIdentifierForGroup:(BabelBrowserGroup*)group {
  NSMutableDictionary<NSString*, NSString*>* parentIdentifiers = [NSMutableDictionary dictionary];
  for (BabelBrowserTab* tab in group.tabs) {
    if (tab.identifier.length > 0 && tab.parentTabIdentifier.length > 0) {
      parentIdentifiers[tab.identifier] = tab.parentTabIdentifier;
    }
  }
  return parentIdentifiers;
}

- (NSString*)tabOpeningStrategy {
  return [browserSettingsStore_ tabOpeningStrategy];
}

- (BOOL)isSupportedTabOpeningStrategy:(NSString*)strategy {
  return [browserSettingsStore_ isSupportedTabOpeningStrategy:strategy];
}

- (NSString*)addressSuggestionsMode {
  return [browserSettingsStore_ addressSuggestionsMode];
}

- (BOOL)isSupportedAddressSuggestionsMode:(NSString*)mode {
  return [browserSettingsStore_ isSupportedAddressSuggestionsMode:mode];
}

- (NSString*)markdownTheme {
  return [browserSettingsStore_ markdownTheme];
}

- (BOOL)isSupportedMarkdownTheme:(NSString*)theme {
  return [browserSettingsStore_ isSupportedMarkdownTheme:theme];
}

- (BOOL)googleSuggestEnabled {
  return [[self addressSuggestionsMode] isEqualToString:BabelAddressSuggestionsModeGoogle];
}

- (void)createBrowserForTabIfNeeded:(BabelBrowserTab*)tab {
  if (!tab || ![tabs_ containsObject:tab] || [tab browser] || [pendingTabs_ containsObject:tab]) {
    return;
  }

  [pendingTabs_ addObject:tab];
  CefWindowInfo windowInfo;
  NSRect bounds = tab.hostView.bounds;
  windowInfo.SetAsChild((__bridge CefWindowHandle)tab.hostView,
                        CefRect(0, 0, bounds.size.width, bounds.size.height));
  windowInfo.runtime_style = CEF_RUNTIME_STYLE_ALLOY;

  CefBrowserSettings browserSettings;
  CefBrowserHost::CreateBrowser(windowInfo,
                                browserClient_,
                                std::string(tab.urlString.UTF8String),
                                browserSettings,
                                nullptr,
                                nullptr);
}

- (void)scheduleBrowserCreationAfterKeyboardNavigationForTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return;
  }

  NSUInteger generation = ++deferredBrowserCreationGeneration_;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               kKeyboardTabSelectionBrowserCreationDelayNanoseconds),
                 dispatch_get_main_queue(), ^{
    if (generation != deferredBrowserCreationGeneration_ ||
        self->selectedTab_ != tab ||
        self->isTerminating_) {
      return;
    }

    [self createBrowserForTabIfNeeded:tab];
    [self scheduleAdjacentTabPreloadForSelectedTab];
  });
}

- (void)createInitialRestoredBrowserIfNeeded {
  if (!needsInitialRestoredBrowserCreation_ || isTerminating_ || !selectedTab_) {
    return;
  }

  needsInitialRestoredBrowserCreation_ = NO;
  ++deferredBrowserCreationGeneration_;
  [self createBrowserForTabIfNeeded:selectedTab_];
  [self scheduleAdjacentTabPreloadForSelectedTab];
}

- (void)scheduleAdjacentTabPreloadForSelectedTab {
  if (isTerminating_ || !selectedTab_ || tabs_.count < 2) {
    return;
  }

  NSUInteger generation = ++adjacentTabPreloadGeneration_;
  BabelBrowserTab* anchorTab = selectedTab_;
  NSArray<BabelBrowserTab*>* tabsToPreload = [self adjacentTabsToPreloadAroundTab:anchorTab];
  [self scheduleAdjacentTabPreloadForTabs:tabsToPreload
                                anchorTab:anchorTab
                               generation:generation
                                    index:0];
}

- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab {
  NSUInteger selectedIndex = [tabs_ indexOfObject:tab];
  if (selectedIndex == NSNotFound || tabs_.count < 2) {
    return @[];
  }

  NSMutableArray<BabelBrowserTab*>* tabsToPreload = [NSMutableArray array];
  if (selectedIndex > 0) {
    [tabsToPreload addObject:tabs_[selectedIndex - 1]];
  }

  if (selectedIndex + 1 < tabs_.count) {
    BabelBrowserTab* nextTab = tabs_[selectedIndex + 1];
    if (![tabsToPreload containsObject:nextTab]) {
      [tabsToPreload addObject:nextTab];
    }
  }

  return tabsToPreload;
}

- (void)scheduleAdjacentTabPreloadForTabs:(NSArray<BabelBrowserTab*>*)tabsToPreload
                                anchorTab:(BabelBrowserTab*)anchorTab
                               generation:(NSUInteger)generation
                                    index:(NSUInteger)index {
  if (index >= tabsToPreload.count) {
    return;
  }

  int64_t delay = index == 0
      ? kAdjacentTabPreloadInitialDelayNanoseconds
      : kAdjacentTabPreloadStepDelayNanoseconds;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^{
    if (generation != self->adjacentTabPreloadGeneration_ ||
        self->selectedTab_ != anchorTab ||
        self->isTerminating_) {
      return;
    }

    BabelBrowserTab* tabToPreload = tabsToPreload[index];
    [self createBrowserForTabIfNeeded:tabToPreload];
    [self scheduleAdjacentTabPreloadForTabs:tabsToPreload
                                  anchorTab:anchorTab
                                 generation:generation
                                      index:index + 1];
  });
}

- (void)touchRecentlyUsedTab:(BabelBrowserTab*)tab {
  [liveBrowserEvictionPolicy_ touchTab:tab];
}

- (NSMutableSet<NSString*>*)protectedLiveBrowserTabIdentifiers {
  NSMutableSet<NSString*>* protectedIdentifiers = [NSMutableSet set];
  if (selectedTab_.identifier.length > 0) {
    [protectedIdentifiers addObject:selectedTab_.identifier];
  }

  for (BabelBrowserTab* tab in [self adjacentTabsToPreloadAroundTab:selectedTab_]) {
    if (tab.identifier.length > 0) {
      [protectedIdentifiers addObject:tab.identifier];
    }
  }

  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if (tab.developerToolsVisible && tab.identifier.length > 0) {
        [protectedIdentifiers addObject:tab.identifier];
      }
    }
  }

  return protectedIdentifiers;
}

- (NSArray<BabelBrowserTab*>*)livePageBrowserTabsExcludingEvictions {
  return [liveBrowserEvictionPolicy_ liveBrowserTabsInGroupsExcludingEvictions:groups_];
}

- (BabelBrowserTab*)leastRecentlyUsedEvictableTabFromTabs:(NSArray<BabelBrowserTab*>*)liveTabs
                                     protectedIdentifiers:(NSSet<NSString*>*)protectedIdentifiers {
  return [liveBrowserEvictionPolicy_ leastRecentlyUsedEvictableTabFromTabs:liveTabs
                                                       protectedIdentifiers:protectedIdentifiers];
}

- (void)closeBrowserForTabKeepingNativeTab:(BabelBrowserTab*)tab {
  CefRefPtr<CefBrowser> browser = [tab browser];
  if (!browser || tab.identifier.length == 0) {
    return;
  }

  [liveBrowserEvictionPolicy_ markTabEvicting:tab];
  browser->GetHost()->CloseDevTools();
  browser->GetHost()->CloseBrowser(true);
}

- (void)enforceLivePageBrowserLimit {
  if (isTerminating_) {
    return;
  }

  NSMutableSet<NSString*>* protectedIdentifiers = [self protectedLiveBrowserTabIdentifiers];
  while (YES) {
    NSArray<BabelBrowserTab*>* liveTabs = [self livePageBrowserTabsExcludingEvictions];
    if (liveTabs.count <= kMaximumLivePageBrowsers) {
      return;
    }

    BabelBrowserTab* tabToEvict =
        [self leastRecentlyUsedEvictableTabFromTabs:liveTabs
                               protectedIdentifiers:protectedIdentifiers];
    if (!tabToEvict) {
      return;
    }

    [self closeBrowserForTabKeepingNativeTab:tabToEvict];
  }
}
- (void)selectTabFromItem:(BabelTabItemView*)tabItemView {
  for (BabelBrowserTab* tab in tabs_) {
    if ([tab.identifier isEqualToString:tabItemView.identifier]) {
      [self selectTab:tab];
      return;
    }
  }
}

- (void)dragTabFromItem:(BabelTabItemView*)tabItemView {
  if (!draggingTab_) {
    draggingTab_ = [self tabWithIdentifier:tabItemView.identifier];
  }

  BabelBrowserTab* tab = draggingTab_;
  if (!tab) {
    return;
  }

  NSEvent* currentEvent = NSApp.currentEvent;
  [self scheduleGroupSelectionForDraggingTabAtWindowPoint:currentEvent.locationInWindow];

  if ([self moveDraggingTabIfNeededToVisibleTabStripAtWindowPoint:currentEvent.locationInWindow]) {
    return;
  }

  if (![self isWindowPointInsideTabStrip:currentEvent.locationInWindow]) {
    return;
  }

  if (![tabs_ containsObject:tab]) {
    return;
  }

  NSUInteger currentIndex = [tabs_ indexOfObject:tab];
  NSPoint tabStripPoint = [tabsItemsPanel_ convertPoint:currentEvent.locationInWindow fromView:nil];
  NSUInteger targetIndex = [self tabInsertionIndexForTabStripX:tabStripPoint.x];
  targetIndex = [tabDragCoordinator_ targetIndexForMovingItemAtIndex:currentIndex
                                                    toInsertionIndex:targetIndex
                                                           itemCount:tabs_.count];
  if (targetIndex == currentIndex) {
    return;
  }

  isReorderingTabs_ = YES;
  [tabs_ removeObjectAtIndex:currentIndex];
  [tabs_ insertObject:tab atIndex:targetIndex];
  [self layoutTabItemsSelectingLastTab:NO];
}

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier {
  for (BabelBrowserGroup* group in groups_) {
    BabelBrowserTab* tab = [self tabWithIdentifier:identifier inGroup:group];
    if (tab) {
      return tab;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)groupContainingTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups_) {
    if ([group.tabs containsObject:tab]) {
      return group;
    }
  }
  return nil;
}

- (BabelBrowserGroup*)groupAtWindowPoint:(NSPoint)windowPoint {
  NSPoint listPoint = [groupsListView_ convertPoint:windowPoint fromView:nil];
  return [tabDragCoordinator_ groupAtListPoint:listPoint
                                        groups:groups_
                              groupsListBounds:groupsListView_.bounds];
}

- (BOOL)isWindowPointInsideSidebar:(NSPoint)windowPoint {
  NSPoint sidebarPoint = [sidebarView_ convertPoint:windowPoint fromView:nil];
  return NSPointInRect(sidebarPoint, sidebarView_.bounds);
}

- (BOOL)isWindowPointInsideTabStrip:(NSPoint)windowPoint {
  NSPoint tabStripPoint = [tabsItemsPanel_ convertPoint:windowPoint fromView:nil];
  return NSPointInRect(tabStripPoint, tabsItemsPanel_.bounds);
}

- (void)scheduleGroupSelectionForDraggingTabAtWindowPoint:(NSPoint)windowPoint {
  BabelBrowserGroup* group = [self groupAtWindowPoint:windowPoint];
  if (!group || group == selectedGroup_) {
    pendingTabDragHoverGroup_ = nil;
    tabDragHoverGeneration_++;
    return;
  }

  if (pendingTabDragHoverGroup_ == group) {
    return;
  }

  pendingTabDragHoverGroup_ = group;
  NSUInteger generation = ++tabDragHoverGeneration_;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kTabDragGroupHoverDelayNanoseconds),
                 dispatch_get_main_queue(), ^{
    if (generation != self->tabDragHoverGeneration_ ||
        !self->draggingTab_ ||
        self->pendingTabDragHoverGroup_ != group) {
      return;
    }

    NSPoint currentWindowPoint = [self.window convertPointFromScreen:NSEvent.mouseLocation];
    if ([self groupAtWindowPoint:currentWindowPoint] != group) {
      return;
    }

    [self selectGroup:group];
  });
}

- (BOOL)moveDraggingTabIfNeededToVisibleTabStripAtWindowPoint:(NSPoint)windowPoint {
  if (!draggingTab_ || ![self isWindowPointInsideTabStrip:windowPoint]) {
    return NO;
  }

  BabelBrowserGroup* sourceGroup = [self groupContainingTab:draggingTab_];
  BabelBrowserGroup* destinationGroup = selectedGroup_;
  if (!sourceGroup || !destinationGroup || sourceGroup == destinationGroup) {
    return NO;
  }

  NSPoint tabStripPoint = [tabsItemsPanel_ convertPoint:windowPoint fromView:nil];
  NSUInteger targetIndex = [self tabInsertionIndexForTabStripX:tabStripPoint.x];
  [self moveDraggingTabToGroup:destinationGroup insertionIndex:targetIndex selectMovedTab:YES];
  return YES;
}

- (void)moveDraggingTabToGroup:(BabelBrowserGroup*)destinationGroup
                insertionIndex:(NSUInteger)insertionIndex
                  selectMovedTab:(BOOL)selectMovedTab {
  if (!draggingTab_ || !destinationGroup) {
    return;
  }

  BabelBrowserGroup* sourceGroup = [self groupContainingTab:draggingTab_];
  if (!sourceGroup) {
    return;
  }

  if (sourceGroup == destinationGroup) {
    NSUInteger currentIndex = [destinationGroup.tabs indexOfObject:draggingTab_];
    if (currentIndex == NSNotFound) {
      return;
    }
    NSUInteger targetIndex = [tabDragCoordinator_ targetIndexForMovingItemAtIndex:currentIndex
                                                                 toInsertionIndex:insertionIndex
                                                                        itemCount:destinationGroup.tabs.count];
    if (targetIndex == currentIndex) {
      return;
    }
    [destinationGroup.tabs removeObjectAtIndex:currentIndex];
    targetIndex = MIN(targetIndex, destinationGroup.tabs.count);
    [destinationGroup.tabs insertObject:draggingTab_ atIndex:targetIndex];
    isReorderingTabs_ = YES;
    [self layoutTabItemsSelectingLastTab:NO];
    return;
  }

  [sourceGroup.tabs removeObject:draggingTab_];
  if ([sourceGroup.selectedTabIdentifier isEqualToString:draggingTab_.identifier]) {
    sourceGroup.selectedTabIdentifier = sourceGroup.tabs.lastObject.identifier ?: @"";
  }

  NSUInteger targetIndex = MIN(insertionIndex, destinationGroup.tabs.count);
  [destinationGroup.tabs insertObject:draggingTab_ atIndex:targetIndex];
  destinationGroup.selectedTabIdentifier = draggingTab_.identifier;
  isReorderingTabs_ = YES;
  isDraggingTabAcrossGroups_ = YES;

  [self selectGroup:destinationGroup];
  if (selectMovedTab) {
    [self selectTab:draggingTab_];
  } else {
    [self layoutTabItemsSelectingLastTab:NO];
  }
}

- (NSUInteger)tabInsertionIndexForTabStripX:(CGFloat)x {
  return [tabDragCoordinator_ insertionIndexForTabStripX:x tabs:tabs_];
}

- (void)finishDraggingTabFromItem:(BabelTabItemView*)tabItemView {
  NSEvent* currentEvent = NSApp.currentEvent;
  BabelBrowserGroup* dropGroup = [self groupAtWindowPoint:currentEvent.locationInWindow];
  BabelBrowserGroup* sourceGroup = [self groupContainingTab:draggingTab_];
  if (draggingTab_ && dropGroup && dropGroup != sourceGroup) {
    [self moveDraggingTabToGroup:dropGroup
                  insertionIndex:dropGroup.tabs.count
                    selectMovedTab:YES];
  } else if (draggingTab_ && !dropGroup &&
             [self isWindowPointInsideSidebar:currentEvent.locationInWindow]) {
    NSString* groupName = [self nextManualGroupName];
    BabelBrowserGroup* group = [self createGroupWithName:groupName
                                              identifier:NSUUID.UUID.UUIDString];
    [self moveDraggingTabToGroup:group insertionIndex:0 selectMovedTab:YES];
  }

  pendingTabDragHoverGroup_ = nil;
  tabDragHoverGeneration_++;

  if (!isReorderingTabs_ && !isDraggingTabAcrossGroups_) {
    if (draggingTab_ && ![tabs_ containsObject:draggingTab_]) {
      [draggingTab_.tabItemView removeFromSuperview];
    }
    draggingTab_ = nil;
    [self layoutTabItemsSelectingLastTab:NO];
    return;
  }

  isReorderingTabs_ = NO;
  isDraggingTabAcrossGroups_ = NO;
  draggingTab_ = nil;
  [self layoutTabItemsSelectingLastTab:NO];
  [self saveGroupsState];
}

- (void)closeTabFromItem:(BabelTabItemView*)tabItemView {
  for (BabelBrowserTab* tab in [tabs_ copy]) {
    if (![tab.identifier isEqualToString:tabItemView.identifier]) {
      continue;
    }

    [self pushClosedTab:tab fromGroup:selectedGroup_];

    if (selectedGroup_.tabs.count <= 1) {
      if ([tab browser]) {
        [tab browser]->GetHost()->CloseDevTools();
      }
      [self hideDeveloperToolsForTab:tab];
      [self resetTabToDefaultPage:tab];
      return;
    }

    if ([tab browser]) {
      CefRefPtr<CefBrowser> browser = [tab browser];
      browser->GetHost()->CloseDevTools();
      [self removeSelectedGroupTab:tab];
      browser->GetHost()->CloseBrowser(true);
      return;
    }

    [self removeSelectedGroupTab:tab];
    return;
  }
}

- (void)pushClosedTab:(BabelBrowserTab*)tab fromGroup:(BabelBrowserGroup*)group {
  if (!tab || tab.urlString.length == 0 || !group) {
    return;
  }

  BabelClosedTab* closedTab = [[BabelClosedTab alloc] init];
  closedTab.urlString = tab.urlString;
  closedTab.requestedURLString = tab.requestedURLString ?: tab.urlString;
  closedTab.title = tab.title ?: tab.urlString;
  closedTab.groupIdentifier = group.identifier;
  closedTab.groupName = group.name ?: kDefaultGroupName;
  [recentlyClosedTabStore_ pushClosedTab:closedTab];
}

- (void)reopenLastClosedTab {
  if (recentlyClosedTabStore_.count == 0) {
    return;
  }

  [self reopenClosedTabAtIndex:recentlyClosedTabStore_.count - 1];
}

- (void)reopenClosedTabAtIndex:(NSUInteger)closedTabIndex {
  BabelClosedTab* closedTab = [recentlyClosedTabStore_ popClosedTabAtIndex:closedTabIndex];
  if (!closedTab) {
    return;
  }

  BabelBrowserGroup* group = [self groupWithIdentifier:closedTab.groupIdentifier];
  if (!group) {
    NSString* groupName = closedTab.groupName.length > 0 ? closedTab.groupName : kDefaultGroupName;
    NSString* groupIdentifier = closedTab.groupIdentifier.length > 0
        ? closedTab.groupIdentifier
        : NSUUID.UUID.UUIDString;
    group = [self createGroupWithName:groupName identifier:groupIdentifier];
  }

  NSString* requestedURLString = closedTab.requestedURLString ?: closedTab.urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString] ?:
      closedTab.urlString;
  BabelBrowserTab* tab = [self makeTabForURL:navigationURLString
                                  identifier:nil
                                       title:closedTab.title ?: closedTab.urlString];
  tab.requestedURLString = requestedURLString;
  [group.tabs addObject:tab];
  [pagesPanel_ addSubview:tab.hostView];
  [pagesPanel_ addSubview:tab.developerToolsPanelView];
  [self selectGroup:group];
  [self selectTab:tab];
  [self showMainWindow];
  [self saveGroupsState];
}

- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab {
  NSString* defaultURLString = BabelChromeConfiguration.defaultURLString;
  tab.urlString = defaultURLString;
  tab.requestedURLString = defaultURLString;
  tab.title = defaultURLString;
  tab.tabItemView.title = [self compactTitleForString:defaultURLString];
  [self selectTab:tab];

  if ([tab browser]) {
    [tab browser]->GetMainFrame()->LoadURL(std::string(defaultURLString.UTF8String));
  }

  [self saveGroupsState];
}

- (void)selectNextTab {
  [self selectTabWithOffset:1];
}

- (void)selectPreviousTab {
  [self selectTabWithOffset:-1];
}

- (void)openURLStringInNewTab:(NSString*)urlString {
  if (urlString.length == 0) {
    return;
  }

  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([stableViewerURLResolver_ isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      return;
    }
    navigationURLString = urlString;
  }
  BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group];
  tab.requestedURLString = requestedURLString;
  if (tab == selectedTab_) {
    [self updateAddressBarForTab:tab];
  }
  [self saveGroupsState];
  [self showMainWindow];
}

- (void)openURLStringInNewTab:(NSString*)urlString openerBrowser:(CefRefPtr<CefBrowser>)browser {
  if (urlString.length == 0) {
    return;
  }

  BabelBrowserTab* parentTab = [self tabForBrowser:browser];
  BabelBrowserGroup* group = selectedGroup_ ?: [self ensureGroupNamed:kDefaultGroupName];
  if (parentTab) {
    for (BabelBrowserGroup* candidateGroup in groups_) {
      if ([candidateGroup.tabs containsObject:parentTab]) {
        group = candidateGroup;
        break;
      }
    }
  }

  NSString* requestedURLString = [self stableViewerURLStringForSupportedURLString:urlString] ?: urlString;
  NSString* navigationURLString = [self navigationURLStringForStableBabelChromeURLString:requestedURLString];
  if (navigationURLString.length == 0) {
    if ([stableViewerURLResolver_ isStableViewerURLString:requestedURLString] ||
        [self stableViewerURLStringForSupportedURLString:urlString]) {
      return;
    }
    navigationURLString = urlString;
  }
  BabelBrowserTab* tab = [self createTabForURL:navigationURLString inGroup:group parentTab:parentTab];
  tab.requestedURLString = requestedURLString;
  if (tab == selectedTab_) {
    [self updateAddressBarForTab:tab];
  }
  [self saveGroupsState];
  [self showMainWindow];
}
