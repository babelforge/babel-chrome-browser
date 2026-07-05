#import "Browser/Tabs/Movement/BrowserTabDragSessionController.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Tabs/Model/BrowserTabCollection.h"
#import "Browser/Tabs/Movement/BrowserTabMoveCoordinator.h"
#import "Browser/UI/Views/BrowserViews.h"
#import "Browser/Tabs/Movement/TabDragCoordinator.h"
#import "Browser/Tabs/Movement/TabDragHoverScheduler.h"

@implementation BabelBrowserTabDragSessionController {
  NSMutableArray<BabelBrowserGroup*>* groups_;
  __weak NSWindow* window_;
  __weak NSView* groupsListView_;
  __weak NSView* sidebarView_;
  __weak NSView* tabsItemsPanel_;
  BabelBrowserTabCollection* tabCollection_;
  BabelTabDragCoordinator* dragCoordinator_;
  BabelTabDragHoverScheduler* hoverScheduler_;
  BabelBrowserTabMoveCoordinator* moveCoordinator_;
  BabelTabDragVisibleTabsProvider visibleTabsProvider_;
  BabelTabDragSelectedGroupProvider selectedGroupProvider_;
  BabelTabDragTabLookupProvider tabLookupProvider_;
  BabelTabDragGroupNameProvider manualGroupNameProvider_;
  BabelTabDragGroupCreateHandler groupCreateHandler_;
  BabelTabDragGroupHandler selectGroupHandler_;
  BabelTabDragTabHandler selectTabHandler_;
  BabelTabDragLayoutHandler layoutTabsHandler_;
  BabelTabDragSaveHandler saveStateHandler_;
  int64_t hoverDelayNanoseconds_;
  BabelBrowserTab* draggingTab_;
  BOOL isReorderingTabs_;
  BOOL isDraggingTabAcrossGroups_;
}

- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                         window:(NSWindow*)window
                 groupsListView:(NSView*)groupsListView
                    sidebarView:(NSView*)sidebarView
                 tabsItemsPanel:(NSView*)tabsItemsPanel
                  tabCollection:(BabelBrowserTabCollection*)tabCollection
                dragCoordinator:(BabelTabDragCoordinator*)dragCoordinator
                 hoverScheduler:(BabelTabDragHoverScheduler*)hoverScheduler
                moveCoordinator:(BabelBrowserTabMoveCoordinator*)moveCoordinator
            visibleTabsProvider:(BabelTabDragVisibleTabsProvider)visibleTabsProvider
          selectedGroupProvider:(BabelTabDragSelectedGroupProvider)selectedGroupProvider
              tabLookupProvider:(BabelTabDragTabLookupProvider)tabLookupProvider
        manualGroupNameProvider:(BabelTabDragGroupNameProvider)manualGroupNameProvider
             groupCreateHandler:(BabelTabDragGroupCreateHandler)groupCreateHandler
             selectGroupHandler:(BabelTabDragGroupHandler)selectGroupHandler
               selectTabHandler:(BabelTabDragTabHandler)selectTabHandler
              layoutTabsHandler:(BabelTabDragLayoutHandler)layoutTabsHandler
               saveStateHandler:(BabelTabDragSaveHandler)saveStateHandler
          hoverDelayNanoseconds:(int64_t)hoverDelayNanoseconds {
  self = [super init];
  if (self) {
    groups_ = groups;
    window_ = window;
    groupsListView_ = groupsListView;
    sidebarView_ = sidebarView;
    tabsItemsPanel_ = tabsItemsPanel;
    tabCollection_ = tabCollection;
    dragCoordinator_ = dragCoordinator;
    hoverScheduler_ = hoverScheduler;
    moveCoordinator_ = moveCoordinator;
    visibleTabsProvider_ = [visibleTabsProvider copy];
    selectedGroupProvider_ = [selectedGroupProvider copy];
    tabLookupProvider_ = [tabLookupProvider copy];
    manualGroupNameProvider_ = [manualGroupNameProvider copy];
    groupCreateHandler_ = [groupCreateHandler copy];
    selectGroupHandler_ = [selectGroupHandler copy];
    selectTabHandler_ = [selectTabHandler copy];
    layoutTabsHandler_ = [layoutTabsHandler copy];
    saveStateHandler_ = [saveStateHandler copy];
    hoverDelayNanoseconds_ = hoverDelayNanoseconds;
    isReorderingTabs_ = NO;
    isDraggingTabAcrossGroups_ = NO;
  }
  return self;
}

- (BabelBrowserTab*)draggingTab {
  return draggingTab_;
}

- (void)dragTabWithIdentifier:(NSString*)identifier {
  if (!draggingTab_) {
    draggingTab_ = tabLookupProvider_ ? tabLookupProvider_(identifier) : nil;
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

  NSArray<BabelBrowserTab*>* visibleTabs = [self visibleTabs];
  if (![visibleTabs containsObject:tab]) {
    return;
  }

  NSPoint tabStripPoint = [tabsItemsPanel_ convertPoint:currentEvent.locationInWindow fromView:nil];
  NSUInteger targetIndex = [self tabInsertionIndexForTabStripX:tabStripPoint.x];
  BabelBrowserTabMoveResult* moveResult =
      [moveCoordinator_ moveTab:tab
                      fromGroup:[self selectedGroup]
                        toGroup:[self selectedGroup]
                  insertionIndex:targetIndex];
  if (!moveResult.didMove) {
    return;
  }

  isReorderingTabs_ = YES;
  [self layoutTabs];
}

- (BabelBrowserGroup*)groupAtWindowPoint:(NSPoint)windowPoint {
  NSPoint listPoint = [groupsListView_ convertPoint:windowPoint fromView:nil];
  return [dragCoordinator_ groupAtListPoint:listPoint
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

- (NSUInteger)tabInsertionIndexForTabStripX:(CGFloat)x {
  return [dragCoordinator_ insertionIndexForTabStripX:x tabs:[self visibleTabs]];
}

- (void)finishDraggingTab {
  NSEvent* currentEvent = NSApp.currentEvent;
  BabelBrowserGroup* dropGroup = [self groupAtWindowPoint:currentEvent.locationInWindow];
  BabelBrowserGroup* sourceGroup = [self groupContainingTab:draggingTab_];
  if (draggingTab_ && dropGroup && dropGroup != sourceGroup) {
    [self moveDraggingTabToGroup:dropGroup
                  insertionIndex:dropGroup.tabs.count
                    selectMovedTab:YES];
  } else if (draggingTab_ && !dropGroup &&
             [self isWindowPointInsideSidebar:currentEvent.locationInWindow]) {
    NSString* groupName = manualGroupNameProvider_ ? manualGroupNameProvider_() : @"";
    BabelBrowserGroup* group = groupCreateHandler_ ? groupCreateHandler_(groupName, NSUUID.UUID.UUIDString) : nil;
    [self moveDraggingTabToGroup:group insertionIndex:0 selectMovedTab:YES];
  }

  [hoverScheduler_ cancelPendingSelection];

  NSArray<BabelBrowserTab*>* visibleTabs = [self visibleTabs];
  if (!isReorderingTabs_ && !isDraggingTabAcrossGroups_) {
    if (draggingTab_ && ![visibleTabs containsObject:draggingTab_]) {
      [draggingTab_.tabItemView removeFromSuperview];
    }
    draggingTab_ = nil;
    [self layoutTabs];
    return;
  }

  isReorderingTabs_ = NO;
  isDraggingTabAcrossGroups_ = NO;
  draggingTab_ = nil;
  [self layoutTabs];
  if (saveStateHandler_) {
    saveStateHandler_();
  }
}

- (void)scheduleGroupSelectionForDraggingTabAtWindowPoint:(NSPoint)windowPoint {
  BabelBrowserGroup* group = [self groupAtWindowPoint:windowPoint];
  if (!group || group == [self selectedGroup]) {
    [hoverScheduler_ cancelPendingSelection];
    return;
  }

  if ([hoverScheduler_ isPendingGroup:group]) {
    return;
  }

  __weak BabelBrowserTabDragSessionController* weakSelf = self;
  [hoverScheduler_ scheduleSelectionForGroup:group
                            delayNanoseconds:hoverDelayNanoseconds_
                             validationBlock:^BOOL(BabelBrowserGroup* candidateGroup) {
                               BabelBrowserTabDragSessionController* strongSelf = weakSelf;
                               if (!strongSelf || !strongSelf->draggingTab_) {
                                 return NO;
                               }

                               NSPoint currentWindowPoint =
                                   [strongSelf->window_ convertPointFromScreen:NSEvent.mouseLocation];
                               return [strongSelf groupAtWindowPoint:currentWindowPoint] == candidateGroup;
                             }
                              selectionBlock:^(BabelBrowserGroup* candidateGroup) {
                                BabelBrowserTabDragSessionController* strongSelf = weakSelf;
                                [strongSelf selectGroup:candidateGroup];
                              }];
}

- (BOOL)moveDraggingTabIfNeededToVisibleTabStripAtWindowPoint:(NSPoint)windowPoint {
  if (!draggingTab_ || ![self isWindowPointInsideTabStrip:windowPoint]) {
    return NO;
  }

  BabelBrowserGroup* sourceGroup = [self groupContainingTab:draggingTab_];
  BabelBrowserGroup* destinationGroup = [self selectedGroup];
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

  BabelBrowserTabMoveResult* moveResult =
      [moveCoordinator_ moveTab:draggingTab_
                      fromGroup:sourceGroup
                        toGroup:destinationGroup
                  insertionIndex:insertionIndex];
  if (!moveResult.didMove) {
    return;
  }

  isReorderingTabs_ = YES;
  if (!moveResult.movedAcrossGroups) {
    [self layoutTabs];
    return;
  }

  isDraggingTabAcrossGroups_ = YES;
  [self selectGroup:destinationGroup];
  if (selectMovedTab) {
    [self selectTab:draggingTab_];
  } else {
    [self layoutTabs];
  }
}

- (BabelBrowserGroup*)groupContainingTab:(BabelBrowserTab*)tab {
  return [tabCollection_ groupContainingTab:tab groups:groups_];
}

- (NSArray<BabelBrowserTab*>*)visibleTabs {
  return visibleTabsProvider_ ? visibleTabsProvider_() : @[];
}

- (BabelBrowserGroup*)selectedGroup {
  return selectedGroupProvider_ ? selectedGroupProvider_() : nil;
}

- (void)selectGroup:(BabelBrowserGroup*)group {
  if (selectGroupHandler_) {
    selectGroupHandler_(group);
  }
}

- (void)selectTab:(BabelBrowserTab*)tab {
  if (selectTabHandler_) {
    selectTabHandler_(tab);
  }
}

- (void)layoutTabs {
  if (layoutTabsHandler_) {
    layoutTabsHandler_();
  }
}

@end
