// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
- (void)restoreSessionGroupsFromState:(NSDictionary*)state {
  [browserSessionRestorationCoordinator_ restoreSelectedGroupFromState:state];
}

- (void)restoreGroupsFromState:(NSDictionary*)state {
  [browserSessionRestorationCoordinator_ restoreGroupsFromState:state];
}

- (BabelBrowserGroup*)createGroupWithName:(NSString*)name identifier:(NSString*)identifier {
  return [browserGroupManager_ createGroupWithName:name identifier:identifier];
}

- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier {
  return [browserGroupManager_ groupWithIdentifier:identifier];
}

- (BabelBrowserGroup*)groupWithName:(NSString*)name {
  return [browserGroupManager_ groupWithName:name];
}

- (BabelBrowserGroup*)ensureGroupNamed:(NSString*)name {
  return [browserGroupManager_ ensureGroupNamed:name];
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
  return [browserGroupManager_ nextManualGroupName];
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

  NSEvent* currentEvent = NSApp.currentEvent;
  NSPoint listPoint = [groupsListView_ convertPoint:currentEvent.locationInWindow fromView:nil];
  NSUInteger targetIndex = [self groupInsertionIndexForListY:listPoint.y];
  BOOL didMove = [browserGroupMoveCoordinator_ moveGroup:group
                                                inGroups:groups_
                                          insertionIndex:targetIndex];
  if (!didMove) {
    return;
  }

  isReorderingGroups_ = YES;
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
  [browserGroupSelectionController_ selectGroup:group];
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

  NSString* newName = [groupRenameController_ promptForGroupNameWithCurrentName:group.name];
  if (newName.length == 0 || [newName isEqualToString:group.name]) {
    return;
  }

  BabelBrowserGroup* existingGroup = [self groupWithName:newName];
  if (existingGroup && existingGroup != group) {
    [groupRenameController_ showDuplicateNameAlertForGroupName:newName];
    return;
  }

  group.name = newName;
  group.groupItemView.title = newName;
  [self saveGroupsState];
}

- (BabelBrowserGroup*)groupToSelectAfterDeletingGroupAtIndex:(NSUInteger)groupIndex {
  return [browserGroupCollection_ groupToSelectAfterDeletingGroupAtIndex:groupIndex groups:groups_];
}

- (void)deleteGroup:(BabelBrowserGroup*)group selectingGroup:(BabelBrowserGroup*)nextGroup {
  BOOL deletingSelectedGroup = group == selectedGroup_;
  for (BabelBrowserTab* tab in [group.tabs copy]) {
    CefRefPtr<CefBrowser> browser = [tab browser];
    [recentlyClosedTabStore_ pushTab:tab fromGroup:group defaultGroupName:kDefaultGroupName];
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
  return [browserTabCollection_ tabWithIdentifier:identifier inGroup:group];
}

- (BabelBrowserTab*)tabWithURLString:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  for (BabelBrowserTab* tab in group.tabs) {
    if ([tabURLMatcher_ tab:tab matchesURLString:urlString]) {
      return tab;
    }
  }
  return nil;
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
  return [browserTabCreationCoordinator_ makeTabForURL:urlString
                                            identifier:identifier
                                                 title:title];
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  BabelBrowserTab* tab = [browserTabCreationCoordinator_ createTabForURL:urlString inGroup:group];
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
  BabelBrowserTab* tab = [browserTabCreationCoordinator_ createTabForURL:urlString
                                                                 inGroup:group
                                                               parentTab:parentTab
                                                  respectingUserStrategy:respectingUserStrategy];
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
  [browserTabCreationCoordinator_ insertTab:tab
                                    inGroup:group
                                  parentTab:parentTab
                     respectingUserStrategy:respectingUserStrategy];
}

- (NSString*)tabOpeningStrategy {
  return [browserSettingsStore_ tabOpeningStrategy];
}

- (NSString*)addressSuggestionsMode {
  return [browserSettingsStore_ addressSuggestionsMode];
}

- (NSString*)markdownTheme {
  return [browserSettingsStore_ markdownTheme];
}

- (BOOL)googleSuggestEnabled {
  return [[self addressSuggestionsMode] isEqualToString:BabelAddressSuggestionsModeGoogle];
}

- (void)createBrowserForTabIfNeeded:(BabelBrowserTab*)tab {
  [browserPageLifecycleController_ createBrowserForTabIfNeeded:tab];
}

- (void)scheduleBrowserCreationAfterKeyboardNavigationForTab:(BabelBrowserTab*)tab {
  [browserPageLifecycleController_ scheduleBrowserCreationAfterKeyboardNavigationForTab:tab];
}

- (void)createInitialRestoredBrowserIfNeeded {
  [browserPageLifecycleController_ createInitialRestoredBrowserIfNeeded];
}

- (void)scheduleAdjacentTabPreloadForSelectedTab {
  [browserPageLifecycleController_ scheduleAdjacentTabPreloadForSelectedTab];
}

- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab {
  return [browserPageLifecycleController_ adjacentTabsToPreloadAroundTab:tab];
}

- (void)touchRecentlyUsedTab:(BabelBrowserTab*)tab {
  [browserPageLifecycleController_ touchRecentlyUsedTab:tab];
}

- (void)closeBrowserForTabKeepingNativeTab:(BabelBrowserTab*)tab {
  [browserPageLifecycleController_ closeBrowserForTabKeepingNativeTab:tab];
}

- (void)enforceLivePageBrowserLimit {
  [browserPageLifecycleController_ enforceLivePageBrowserLimit];
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
  [browserTabDragSessionController_ dragTabWithIdentifier:tabItemView.identifier];
}

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier {
  return [browserTabCollection_ tabWithIdentifier:identifier groups:groups_];
}

- (BabelBrowserGroup*)groupContainingTab:(BabelBrowserTab*)tab {
  return [browserTabCollection_ groupContainingTab:tab groups:groups_];
}

- (void)finishDraggingTabFromItem:(BabelTabItemView*)tabItemView {
  [browserTabDragSessionController_ finishDraggingTab];
}

- (void)closeTabFromItem:(BabelTabItemView*)tabItemView {
  [browserClosedTabController_ closeTabWithIdentifier:tabItemView.identifier];
}

- (void)reopenLastClosedTab {
  [browserClosedTabController_ reopenLastClosedTab];
}

- (void)reopenClosedTabAtIndex:(NSUInteger)closedTabIndex {
  [browserClosedTabController_ reopenClosedTabAtIndex:closedTabIndex];
}

- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab {
  [browserClosedTabController_ resetTabToDefaultPage:tab];
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
  BabelNewTabURLResolution* resolution = [newTabURLResolver_ resolveURLString:urlString];
  if (!resolution.shouldOpen) {
    return;
  }
  BabelBrowserTab* tab = [self createTabForURL:resolution.navigationURLString inGroup:group];
  tab.requestedURLString = resolution.requestedURLString;
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

  BabelNewTabURLResolution* resolution = [newTabURLResolver_ resolveURLString:urlString];
  if (!resolution.shouldOpen) {
    return;
  }
  BabelBrowserTab* tab = [self createTabForURL:resolution.navigationURLString
                                       inGroup:group
                                     parentTab:parentTab];
  tab.requestedURLString = resolution.requestedURLString;
  if (tab == selectedTab_) {
    [self updateAddressBarForTab:tab];
  }
  [self saveGroupsState];
  [self showMainWindow];
}
