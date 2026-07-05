#import "Browser/BrowserClosedTabController.h"

#import "Browser/BrowserModels.h"
#import "Browser/ClosedTabReopenCoordinator.h"
#import "Browser/ClosedTabRestorationPlanner.h"
#import "Browser/RecentlyClosedTabStore.h"
#import "Browser/TabContentViewAttacher.h"
#import "Browser/TabDefaultPageResetter.h"

#include "include/cef_browser.h"

@implementation BabelBrowserClosedTabController {
  BabelRecentlyClosedTabStore* recentlyClosedTabStore_;
  BabelClosedTabReopenCoordinator* closedTabReopenCoordinator_;
  BabelTabDefaultPageResetter* tabDefaultPageResetter_;
  BabelTabContentViewAttacher* tabContentViewAttacher_;
  __weak NSView* pagesPanel_;
  NSString* defaultGroupName_;
  BabelClosedTabVisibleTabsProvider visibleTabsProvider_;
  BabelClosedTabSelectedGroupProvider selectedGroupProvider_;
  BabelClosedTabGroupLookupProvider groupLookupProvider_;
  BabelClosedTabGroupCreateHandler groupCreateHandler_;
  BabelClosedTabCreateHandler tabCreateHandler_;
  BabelClosedTabTabHandler hideDeveloperToolsHandler_;
  BabelClosedTabTabHandler removeSelectedGroupTabHandler_;
  BabelClosedTabGroupHandler selectGroupHandler_;
  BabelClosedTabTabHandler selectTabHandler_;
  BabelClosedTabVoidHandler showWindowHandler_;
  BabelClosedTabVoidHandler saveStateHandler_;
}

- (instancetype)initWithRecentlyClosedTabStore:(BabelRecentlyClosedTabStore*)recentlyClosedTabStore
                    closedTabReopenCoordinator:(BabelClosedTabReopenCoordinator*)closedTabReopenCoordinator
                       tabDefaultPageResetter:(BabelTabDefaultPageResetter*)tabDefaultPageResetter
                      tabContentViewAttacher:(BabelTabContentViewAttacher*)tabContentViewAttacher
                                  pagesPanel:(NSView*)pagesPanel
                            defaultGroupName:(NSString*)defaultGroupName
                         visibleTabsProvider:(BabelClosedTabVisibleTabsProvider)visibleTabsProvider
                       selectedGroupProvider:(BabelClosedTabSelectedGroupProvider)selectedGroupProvider
                         groupLookupProvider:(BabelClosedTabGroupLookupProvider)groupLookupProvider
                           groupCreateHandler:(BabelClosedTabGroupCreateHandler)groupCreateHandler
                             tabCreateHandler:(BabelClosedTabCreateHandler)tabCreateHandler
                   hideDeveloperToolsHandler:(BabelClosedTabTabHandler)hideDeveloperToolsHandler
               removeSelectedGroupTabHandler:(BabelClosedTabTabHandler)removeSelectedGroupTabHandler
                           selectGroupHandler:(BabelClosedTabGroupHandler)selectGroupHandler
                             selectTabHandler:(BabelClosedTabTabHandler)selectTabHandler
                            showWindowHandler:(BabelClosedTabVoidHandler)showWindowHandler
                             saveStateHandler:(BabelClosedTabVoidHandler)saveStateHandler {
  self = [super init];
  if (self) {
    recentlyClosedTabStore_ = recentlyClosedTabStore;
    closedTabReopenCoordinator_ = closedTabReopenCoordinator;
    tabDefaultPageResetter_ = tabDefaultPageResetter;
    tabContentViewAttacher_ = tabContentViewAttacher;
    pagesPanel_ = pagesPanel;
    defaultGroupName_ = [defaultGroupName copy];
    visibleTabsProvider_ = [visibleTabsProvider copy];
    selectedGroupProvider_ = [selectedGroupProvider copy];
    groupLookupProvider_ = [groupLookupProvider copy];
    groupCreateHandler_ = [groupCreateHandler copy];
    tabCreateHandler_ = [tabCreateHandler copy];
    hideDeveloperToolsHandler_ = [hideDeveloperToolsHandler copy];
    removeSelectedGroupTabHandler_ = [removeSelectedGroupTabHandler copy];
    selectGroupHandler_ = [selectGroupHandler copy];
    selectTabHandler_ = [selectTabHandler copy];
    showWindowHandler_ = [showWindowHandler copy];
    saveStateHandler_ = [saveStateHandler copy];
  }
  return self;
}

- (void)closeTabWithIdentifier:(NSString*)identifier {
  NSArray<BabelBrowserTab*>* visibleTabs = visibleTabsProvider_ ? visibleTabsProvider_() : @[];
  BabelBrowserGroup* selectedGroup = selectedGroupProvider_ ? selectedGroupProvider_() : nil;
  for (BabelBrowserTab* tab in [visibleTabs copy]) {
    if (![tab.identifier isEqualToString:identifier]) {
      continue;
    }

    [recentlyClosedTabStore_ pushTab:tab fromGroup:selectedGroup defaultGroupName:defaultGroupName_];

    if (selectedGroup.tabs.count <= 1) {
      if ([tab browser]) {
        [tab browser]->GetHost()->CloseDevTools();
      }
      if (hideDeveloperToolsHandler_) {
        hideDeveloperToolsHandler_(tab);
      }
      [self resetTabToDefaultPage:tab];
      return;
    }

    if ([tab browser]) {
      CefRefPtr<CefBrowser> browser = [tab browser];
      browser->GetHost()->CloseDevTools();
      if (removeSelectedGroupTabHandler_) {
        removeSelectedGroupTabHandler_(tab);
      }
      browser->GetHost()->CloseBrowser(true);
      return;
    }

    if (removeSelectedGroupTabHandler_) {
      removeSelectedGroupTabHandler_(tab);
    }
    return;
  }
}

- (void)reopenLastClosedTab {
  if (recentlyClosedTabStore_.count == 0) {
    return;
  }

  [self reopenClosedTabAtIndex:recentlyClosedTabStore_.count - 1];
}

- (void)reopenClosedTabAtIndex:(NSUInteger)closedTabIndex {
  BabelClosedTabRestorationPlan* plan =
      [closedTabReopenCoordinator_ restorationPlanForClosedTabAtIndex:closedTabIndex];
  if (!plan) {
    return;
  }

  BabelBrowserGroup* group = groupLookupProvider_ ? groupLookupProvider_(plan.groupIdentifier) : nil;
  if (!group && groupCreateHandler_) {
    group = groupCreateHandler_(plan.groupName, plan.groupIdentifier);
  }

  BabelBrowserTab* tab = tabCreateHandler_ ? tabCreateHandler_(plan.navigationURLString, nil, plan.title) : nil;
  tab.requestedURLString = plan.requestedURLString;
  [group.tabs addObject:tab];
  [tabContentViewAttacher_ attachTab:tab toPagesPanel:pagesPanel_];
  if (selectGroupHandler_) {
    selectGroupHandler_(group);
  }
  if (selectTabHandler_) {
    selectTabHandler_(tab);
  }
  if (showWindowHandler_) {
    showWindowHandler_();
  }
  if (saveStateHandler_) {
    saveStateHandler_();
  }
}

- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab {
  [tabDefaultPageResetter_ resetTabToDefaultPage:tab];
  if (selectTabHandler_) {
    selectTabHandler_(tab);
  }

  if ([tab browser]) {
    [tab browser]->GetMainFrame()->LoadURL(std::string(tab.urlString.UTF8String));
  }

  if (saveStateHandler_) {
    saveStateHandler_();
  }
}

@end
