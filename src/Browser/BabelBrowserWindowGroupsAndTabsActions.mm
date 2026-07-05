#import "Browser/BabelBrowserWindowGroupsAndTabsActions.h"

#import "Browser/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowGroupsAndTabsActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (void)restoreSessionGroupsFromState:(NSDictionary*)state {
  [owner_->browserSessionRestorationCoordinator_ restoreSelectedGroupFromState:state];
}

- (void)restoreGroupsFromState:(NSDictionary*)state {
  [owner_->browserSessionRestorationCoordinator_ restoreGroupsFromState:state];
}

- (BabelBrowserGroup*)createGroupWithName:(NSString*)name identifier:(NSString*)identifier {
  return [owner_->browserGroupManager_ createGroupWithName:name identifier:identifier];
}

- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier {
  return [owner_->browserGroupManager_ groupWithIdentifier:identifier];
}

- (BabelBrowserGroup*)groupWithName:(NSString*)name {
  return [owner_->browserGroupManager_ groupWithName:name];
}

- (BabelBrowserGroup*)ensureGroupNamed:(NSString*)name {
  return [owner_->browserGroupManager_ ensureGroupNamed:name];
}

- (BabelBrowserGroup*)targetGroupForModuleIdentifier:(NSString*)moduleIdentifier
                                      fallbackGroup:(BabelBrowserGroup*)fallbackGroup {
  NSString* defaultGroupName = [owner_->moduleActionService_ defaultGroupNameForModuleIdentifier:moduleIdentifier];
  if (defaultGroupName.length > 0) {
    return [owner_ ensureGroupNamed:defaultGroupName];
  }

  return fallbackGroup ?: [owner_ ensureGroupNamed:kDefaultGroupName];
}

- (NSString*)nextManualGroupName {
  return [owner_->browserGroupManager_ nextManualGroupName];
}

- (void)addGroupFromButton:(id)sender {
  NSString* groupName = [owner_ nextManualGroupName];
  BabelBrowserGroup* group = [owner_ createGroupWithName:groupName identifier:NSUUID.UUID.UUIDString];
  [owner_ selectGroup:group];
  [owner_ createTabForURL:BabelChromeConfiguration.defaultURLString inGroup:group];
  [owner_ saveGroupsState];
}

- (void)selectGroupFromItem:(BabelGroupItemView*)groupItemView {
  BabelBrowserGroup* group = [owner_ groupWithIdentifier:groupItemView.identifier];
  if (group) {
    [owner_ selectGroup:group];
    [owner_ saveGroupsState];
  }
}

- (void)dragGroupFromItem:(BabelGroupItemView*)groupItemView {
  BabelBrowserGroup* group = [owner_ groupWithIdentifier:groupItemView.identifier];
  if (!group) {
    return;
  }

  NSEvent* currentEvent = NSApp.currentEvent;
  NSPoint listPoint = [owner_->groupsListView_ convertPoint:currentEvent.locationInWindow fromView:nil];
  NSUInteger targetIndex = [owner_ groupInsertionIndexForListY:listPoint.y];
  BOOL didMove = [owner_->browserGroupMoveCoordinator_ moveGroup:group
                                                inGroups:owner_->groups_
                                          insertionIndex:targetIndex];
  if (!didMove) {
    return;
  }

  owner_->isReorderingGroups_ = YES;
  [owner_ layoutGroupItems];
}

- (NSUInteger)groupInsertionIndexForListY:(CGFloat)y {
  return [owner_->groupListCoordinator_ insertionIndexForListY:y groupCount:owner_->groups_.count];
}

- (void)finishDraggingGroupFromItem:(BabelGroupItemView*)groupItemView {
  if (!owner_->isReorderingGroups_) {
    return;
  }

  owner_->isReorderingGroups_ = NO;
  [owner_ layoutGroupItems];
  [owner_ saveGroupsState];
}

- (void)selectGroup:(BabelBrowserGroup*)group {
  [owner_->browserGroupSelectionController_ selectGroup:group];
}

- (void)deleteGroupFromMenu:(NSMenuItem*)menuItem {
  NSString* groupIdentifier = menuItem.representedObject;
  BabelBrowserGroup* group = [owner_ groupWithIdentifier:groupIdentifier];
  if (!group || owner_->groups_.count <= 1) {
    return;
  }

  NSUInteger groupIndex = [owner_->groups_ indexOfObject:group];
  BabelBrowserGroup* nextGroup = [owner_ groupToSelectAfterDeletingGroupAtIndex:groupIndex];
  [owner_ deleteGroup:group selectingGroup:nextGroup];
}

- (void)renameGroupFromMenu:(NSMenuItem*)menuItem {
  NSString* groupIdentifier = menuItem.representedObject;
  BabelBrowserGroup* group = [owner_ groupWithIdentifier:groupIdentifier];
  if (!group) {
    return;
  }

  NSString* newName = [owner_->groupRenameController_ promptForGroupNameWithCurrentName:group.name];
  if (newName.length == 0 || [newName isEqualToString:group.name]) {
    return;
  }

  BabelBrowserGroup* existingGroup = [owner_ groupWithName:newName];
  if (existingGroup && existingGroup != group) {
    [owner_->groupRenameController_ showDuplicateNameAlertForGroupName:newName];
    return;
  }

  group.name = newName;
  group.groupItemView.title = newName;
  [owner_ saveGroupsState];
}

- (BabelBrowserGroup*)groupToSelectAfterDeletingGroupAtIndex:(NSUInteger)groupIndex {
  return [owner_->browserGroupCollection_ groupToSelectAfterDeletingGroupAtIndex:groupIndex groups:owner_->groups_];
}

- (void)deleteGroup:(BabelBrowserGroup*)group selectingGroup:(BabelBrowserGroup*)nextGroup {
  BOOL deletingSelectedGroup = group == owner_->selectedGroup_;
  for (BabelBrowserTab* tab in [group.tabs copy]) {
    CefRefPtr<CefBrowser> browser = [tab browser];
    [owner_->recentlyClosedTabStore_ pushTab:tab fromGroup:group defaultGroupName:kDefaultGroupName];
    [owner_ removeTab:tab fromGroup:group allowSelection:!deletingSelectedGroup];
    if (browser) {
      browser->GetHost()->CloseBrowser(true);
    }
  }

  [group.groupItemView removeFromSuperview];
  [owner_->groups_ removeObject:group];

  if (deletingSelectedGroup) {
    [owner_ selectGroup:nextGroup ?: owner_->groups_.firstObject];
  } else {
    [owner_ layoutGroupItems];
  }

  [owner_ saveGroupsState];
}

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier inGroup:(BabelBrowserGroup*)group {
  return [owner_->browserTabCollection_ tabWithIdentifier:identifier inGroup:group];
}

- (BabelBrowserTab*)tabWithURLString:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  for (BabelBrowserTab* tab in group.tabs) {
    if ([owner_->tabURLMatcher_ tab:tab matchesURLString:urlString]) {
      return tab;
    }
  }
  return nil;
}

- (void)saveGroupsState {
  [owner_->groupSessionStore_ saveGroups:owner_->groups_
          selectedGroupIdentifier:owner_->selectedGroup_.identifier
  fallbackSelectedGroupIdentifier:kDefaultGroupIdentifier
              excludingTabsMatching:^BOOL(BabelBrowserTab* tab) {
    return [owner_ isInternalPageTab:tab];
  }];
}
- (void)showMainWindow {
  [owner_ restoreSessionWindowZoom];
  [owner_ layoutInterfaceForCurrentSplitViewSize];
  [owner_ restoreSessionSidebarAfterInitialLayout];
  [owner_.window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                        identifier:(NSString*)identifier
                             title:(NSString*)title {
  return [owner_->browserTabCreationCoordinator_ makeTabForURL:urlString
                                            identifier:identifier
                                                 title:title];
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString inGroup:(BabelBrowserGroup*)group {
  BabelBrowserTab* tab = [owner_->browserTabCreationCoordinator_ createTabForURL:urlString inGroup:group];
  [owner_ selectGroup:group];
  [owner_ selectTab:tab];
  [owner_ saveGroupsState];
  return tab;
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab {
  return [owner_ createTabForURL:urlString
                       inGroup:group
                     parentTab:parentTab
          respectingUserStrategy:YES];
}

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab
   respectingUserStrategy:(BOOL)respectingUserStrategy {
  BabelBrowserTab* tab = [owner_->browserTabCreationCoordinator_ createTabForURL:urlString
                                                                 inGroup:group
                                                               parentTab:parentTab
                                                  respectingUserStrategy:respectingUserStrategy];
  [owner_ selectGroup:group];
  [owner_ selectTab:tab];
  [owner_ saveGroupsState];
  return tab;
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab {
  [owner_ insertTab:tab
          inGroup:group
        parentTab:parentTab
 respectingUserStrategy:YES];
}

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
 respectingUserStrategy:(BOOL)respectingUserStrategy {
  [owner_->browserTabCreationCoordinator_ insertTab:tab
                                    inGroup:group
                                  parentTab:parentTab
                     respectingUserStrategy:respectingUserStrategy];
}

- (NSString*)tabOpeningStrategy {
  return [owner_->browserSettingsStore_ tabOpeningStrategy];
}

- (NSString*)addressSuggestionsMode {
  return [owner_->browserSettingsStore_ addressSuggestionsMode];
}

- (NSString*)markdownTheme {
  return [owner_->browserSettingsStore_ markdownTheme];
}

- (BOOL)googleSuggestEnabled {
  return [[owner_ addressSuggestionsMode] isEqualToString:BabelAddressSuggestionsModeGoogle];
}

- (void)createBrowserForTabIfNeeded:(BabelBrowserTab*)tab {
  [owner_->browserPageLifecycleController_ createBrowserForTabIfNeeded:tab];
}

- (void)scheduleBrowserCreationAfterKeyboardNavigationForTab:(BabelBrowserTab*)tab {
  [owner_->browserPageLifecycleController_ scheduleBrowserCreationAfterKeyboardNavigationForTab:tab];
}

- (void)createInitialRestoredBrowserIfNeeded {
  [owner_->browserPageLifecycleController_ createInitialRestoredBrowserIfNeeded];
}

- (void)scheduleAdjacentTabPreloadForSelectedTab {
  [owner_->browserPageLifecycleController_ scheduleAdjacentTabPreloadForSelectedTab];
}

- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab {
  return [owner_->browserPageLifecycleController_ adjacentTabsToPreloadAroundTab:tab];
}

- (void)touchRecentlyUsedTab:(BabelBrowserTab*)tab {
  [owner_->browserPageLifecycleController_ touchRecentlyUsedTab:tab];
}

- (void)closeBrowserForTabKeepingNativeTab:(BabelBrowserTab*)tab {
  [owner_->browserPageLifecycleController_ closeBrowserForTabKeepingNativeTab:tab];
}

- (void)enforceLivePageBrowserLimit {
  [owner_->browserPageLifecycleController_ enforceLivePageBrowserLimit];
}
- (void)selectTabFromItem:(BabelTabItemView*)tabItemView {
  for (BabelBrowserTab* tab in owner_->tabs_) {
    if ([tab.identifier isEqualToString:tabItemView.identifier]) {
      [owner_ selectTab:tab];
      return;
    }
  }
}

- (void)dragTabFromItem:(BabelTabItemView*)tabItemView {
  [owner_->browserTabDragSessionController_ dragTabWithIdentifier:tabItemView.identifier];
}

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier {
  return [owner_->browserTabCollection_ tabWithIdentifier:identifier groups:owner_->groups_];
}

- (BabelBrowserGroup*)groupContainingTab:(BabelBrowserTab*)tab {
  return [owner_->browserTabCollection_ groupContainingTab:tab groups:owner_->groups_];
}

- (void)finishDraggingTabFromItem:(BabelTabItemView*)tabItemView {
  [owner_->browserTabDragSessionController_ finishDraggingTab];
}

- (void)closeTabFromItem:(BabelTabItemView*)tabItemView {
  [owner_->browserClosedTabController_ closeTabWithIdentifier:tabItemView.identifier];
}

- (void)reopenLastClosedTab {
  [owner_->browserClosedTabController_ reopenLastClosedTab];
}

- (void)reopenClosedTabAtIndex:(NSUInteger)closedTabIndex {
  [owner_->browserClosedTabController_ reopenClosedTabAtIndex:closedTabIndex];
}

- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab {
  [owner_->browserClosedTabController_ resetTabToDefaultPage:tab];
}

- (void)selectNextTab {
  [owner_ selectTabWithOffset:1];
}

- (void)selectPreviousTab {
  [owner_ selectTabWithOffset:-1];
}

- (void)openURLStringInNewTab:(NSString*)urlString {
  if (urlString.length == 0) {
    return;
  }

  BabelBrowserGroup* group = owner_->selectedGroup_ ?: [owner_ ensureGroupNamed:kDefaultGroupName];
  BabelNewTabURLResolution* resolution = [owner_->newTabURLResolver_ resolveURLString:urlString];
  if (!resolution.shouldOpen) {
    return;
  }
  BabelBrowserTab* tab = [owner_ createTabForURL:resolution.navigationURLString inGroup:group];
  tab.requestedURLString = resolution.requestedURLString;
  if (tab == owner_->selectedTab_) {
    [owner_ updateAddressBarForTab:tab];
  }
  [owner_ saveGroupsState];
  [owner_ showMainWindow];
}

- (void)openURLStringInNewTab:(NSString*)urlString openerBrowser:(CefRefPtr<CefBrowser>)browser {
  if (urlString.length == 0) {
    return;
  }

  BabelBrowserTab* parentTab = [owner_ tabForBrowser:browser];
  BabelBrowserGroup* group = owner_->selectedGroup_ ?: [owner_ ensureGroupNamed:kDefaultGroupName];
  if (parentTab) {
    for (BabelBrowserGroup* candidateGroup in owner_->groups_) {
      if ([candidateGroup.tabs containsObject:parentTab]) {
        group = candidateGroup;
        break;
      }
    }
  }

  BabelNewTabURLResolution* resolution = [owner_->newTabURLResolver_ resolveURLString:urlString];
  if (!resolution.shouldOpen) {
    return;
  }
  BabelBrowserTab* tab = [owner_ createTabForURL:resolution.navigationURLString
                                       inGroup:group
                                     parentTab:parentTab];
  tab.requestedURLString = resolution.requestedURLString;
  if (tab == owner_->selectedTab_) {
    [owner_ updateAddressBarForTab:tab];
  }
  [owner_ saveGroupsState];
  [owner_ showMainWindow];
}


@end
