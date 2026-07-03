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
  if (groups_.count == 0) {
    return 0;
  }

  CGFloat rowPitch = 34.0;
  NSInteger targetIndex = (NSInteger)floor((y + (rowPitch / 2.0)) / rowPitch);
  if (targetIndex < 0) {
    return 0;
  }
  return MIN((NSUInteger)targetIndex, groups_.count);
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
