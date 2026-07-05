#import "Browser/Groups/Management/BrowserGroupSelectionController.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Tabs/Model/BrowserTabCollection.h"
#import "Browser/UI/Views/BrowserViews.h"

@implementation BabelBrowserGroupSelectionController {
  NSMutableArray<BabelBrowserGroup*>* groups_;
  __weak NSView* tabsItemsPanel_;
  BabelBrowserTabCollection* tabCollection_;
  BabelGroupSelectionDraggingTabProvider draggingTabProvider_;
  BabelGroupSelectionVisibleTabsHandler visibleTabsHandler_;
  BabelGroupSelectionGroupHandler selectedGroupHandler_;
  BabelGroupSelectionTabHandler selectedTabHandler_;
  BabelGroupSelectionTabHandler selectTabHandler_;
  BabelGroupSelectionVoidHandler clearAddressHandler_;
  BabelGroupSelectionVoidHandler updateWindowTitleHandler_;
  BabelGroupSelectionVoidHandler layoutTabsHandler_;
  BabelGroupSelectionVoidHandler layoutGroupsHandler_;
}

- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                tabsItemsPanel:(NSView*)tabsItemsPanel
                 tabCollection:(BabelBrowserTabCollection*)tabCollection
           draggingTabProvider:(BabelGroupSelectionDraggingTabProvider)draggingTabProvider
            visibleTabsHandler:(BabelGroupSelectionVisibleTabsHandler)visibleTabsHandler
          selectedGroupHandler:(BabelGroupSelectionGroupHandler)selectedGroupHandler
            selectedTabHandler:(BabelGroupSelectionTabHandler)selectedTabHandler
              selectTabHandler:(BabelGroupSelectionTabHandler)selectTabHandler
            clearAddressHandler:(BabelGroupSelectionVoidHandler)clearAddressHandler
       updateWindowTitleHandler:(BabelGroupSelectionVoidHandler)updateWindowTitleHandler
             layoutTabsHandler:(BabelGroupSelectionVoidHandler)layoutTabsHandler
            layoutGroupsHandler:(BabelGroupSelectionVoidHandler)layoutGroupsHandler {
  self = [super init];
  if (self) {
    groups_ = groups;
    tabsItemsPanel_ = tabsItemsPanel;
    tabCollection_ = tabCollection;
    draggingTabProvider_ = [draggingTabProvider copy];
    visibleTabsHandler_ = [visibleTabsHandler copy];
    selectedGroupHandler_ = [selectedGroupHandler copy];
    selectedTabHandler_ = [selectedTabHandler copy];
    selectTabHandler_ = [selectTabHandler copy];
    clearAddressHandler_ = [clearAddressHandler copy];
    updateWindowTitleHandler_ = [updateWindowTitleHandler copy];
    layoutTabsHandler_ = [layoutTabsHandler copy];
    layoutGroupsHandler_ = [layoutGroupsHandler copy];
  }
  return self;
}

- (void)selectGroup:(BabelBrowserGroup*)group {
  if (selectedGroupHandler_) {
    selectedGroupHandler_(group);
  }
  if (visibleTabsHandler_) {
    visibleTabsHandler_(group.tabs);
  }

  BabelBrowserTab* draggingTab = draggingTabProvider_ ? draggingTabProvider_() : nil;
  for (BabelBrowserGroup* currentGroup in groups_) {
    currentGroup.groupItemView.selected = currentGroup == group;
    for (BabelBrowserTab* tab in currentGroup.tabs) {
      if (tab != draggingTab) {
        [tab.tabItemView removeFromSuperview];
      }
      tab.hostView.hidden = YES;
      tab.developerToolsPanelView.hidden = YES;
    }
  }

  for (BabelBrowserTab* tab in group.tabs) {
    if (tab.tabItemView.superview != tabsItemsPanel_) {
      [tabsItemsPanel_ addSubview:tab.tabItemView];
    }
  }

  BabelBrowserTab* tabToSelect =
      [tabCollection_ tabWithIdentifier:group.selectedTabIdentifier inGroup:group] ?: group.tabs.lastObject;
  if (tabToSelect) {
    if (selectTabHandler_) {
      selectTabHandler_(tabToSelect);
    }
  } else {
    if (selectedTabHandler_) {
      selectedTabHandler_(nil);
    }
    if (clearAddressHandler_) {
      clearAddressHandler_();
    }
    if (updateWindowTitleHandler_) {
      updateWindowTitleHandler_();
    }
    if (layoutTabsHandler_) {
      layoutTabsHandler_();
    }
  }
  if (layoutGroupsHandler_) {
    layoutGroupsHandler_();
  }
}

@end
