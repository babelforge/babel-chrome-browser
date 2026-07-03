// This file is included by BrowserWindowController.mm.
// It remains in the same translation unit so private Objective-C++ ivars stay accessible.
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
  if (targetIndex > currentIndex) {
    targetIndex--;
  }
  targetIndex = MIN(targetIndex, tabs_.count - 1);
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
  if (!NSPointInRect(listPoint, groupsListView_.bounds)) {
    return nil;
  }

  for (BabelBrowserGroup* group in groups_) {
    if (NSPointInRect(listPoint, group.groupItemView.frame)) {
      return group;
    }
  }
  return nil;
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
    NSUInteger targetIndex = MIN(insertionIndex, destinationGroup.tabs.count);
    if (targetIndex > currentIndex) {
      targetIndex--;
    }
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
  if (tabs_.count == 0) {
    return 0;
  }

  for (NSUInteger index = 0; index < tabs_.count; index++) {
    BabelBrowserTab* tab = tabs_[index];
    if (x < NSMidX(tab.tabItemView.frame)) {
      return index;
    }
  }
  return tabs_.count;
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
  [closedTabs_ addObject:closedTab];
}

- (void)reopenLastClosedTab {
  if (closedTabs_.count == 0) {
    return;
  }

  [self reopenClosedTabAtIndex:closedTabs_.count - 1];
}

- (void)reopenClosedTabAtIndex:(NSUInteger)closedTabIndex {
  if (closedTabIndex >= closedTabs_.count) {
    return;
  }

  BabelClosedTab* closedTab = closedTabs_[closedTabIndex];
  [closedTabs_ removeObjectAtIndex:closedTabIndex];

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
    if ([self isStableViewerURLString:requestedURLString] ||
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
    if ([self isStableViewerURLString:requestedURLString] ||
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
