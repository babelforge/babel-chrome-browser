#import "Browser/CEF/Attachment/BrowserAttachmentCoordinator.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/UI/Views/BrowserViews.h"
#import "Browser/Tabs/Lifecycle/LiveBrowserEvictionPolicy.h"

@implementation BabelBrowserAttachmentCoordinator {
  NSMutableArray<BabelBrowserGroup*>* groups_;
  NSMutableArray<BabelBrowserTab*>* pendingTabs_;
  BabelLiveBrowserEvictionPolicy* evictionPolicy_;
  BabelBrowserAttachmentGroupHandler selectGroupHandler_;
  BabelBrowserAttachmentTabHandler removeTabHandler_;
  BabelBrowserAttachmentTabHandler hideDeveloperToolsHandler_;
  BabelBrowserAttachmentTabHandler layoutDeveloperToolsHandler_;
  BabelBrowserAttachmentVoidHandler enforceLiveBrowserLimitHandler_;
  BabelBrowserAttachmentCountProvider totalTabCountProvider_;
}

- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                   pendingTabs:(NSMutableArray<BabelBrowserTab*>*)pendingTabs
                evictionPolicy:(BabelLiveBrowserEvictionPolicy*)evictionPolicy
            selectGroupHandler:(BabelBrowserAttachmentGroupHandler)selectGroupHandler
              removeTabHandler:(BabelBrowserAttachmentTabHandler)removeTabHandler
      hideDeveloperToolsHandler:(BabelBrowserAttachmentTabHandler)hideDeveloperToolsHandler
   layoutDeveloperToolsHandler:(BabelBrowserAttachmentTabHandler)layoutDeveloperToolsHandler
 enforceLiveBrowserLimitHandler:(BabelBrowserAttachmentVoidHandler)enforceLiveBrowserLimitHandler
         totalTabCountProvider:(BabelBrowserAttachmentCountProvider)totalTabCountProvider {
  self = [super init];
  if (self) {
    groups_ = groups;
    pendingTabs_ = pendingTabs;
    evictionPolicy_ = evictionPolicy;
    selectGroupHandler_ = [selectGroupHandler copy];
    removeTabHandler_ = [removeTabHandler copy];
    hideDeveloperToolsHandler_ = [hideDeveloperToolsHandler copy];
    layoutDeveloperToolsHandler_ = [layoutDeveloperToolsHandler copy];
    enforceLiveBrowserLimitHandler_ = [enforceLiveBrowserLimitHandler copy];
    totalTabCountProvider_ = [totalTabCountProvider copy];
  }
  return self;
}

- (BOOL)attachPageBrowser:(CefRefPtr<CefBrowser>)browser {
  BabelBrowserTab* tab = pendingTabs_.firstObject;
  if (tab) {
    [pendingTabs_ removeObjectAtIndex:0];
  }

  if (!tab) {
    return NO;
  }

  [tab setBrowser:browser];
  [tab.hostView setBrowser:browser];
  [tab.hostView layoutSubtreeIfNeeded];

  if (enforceLiveBrowserLimitHandler_) {
    enforceLiveBrowserLimitHandler_();
  }
  return YES;
}

- (BOOL)attachDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              toTab:(BabelBrowserTab*)tab {
  if (!tab) {
    return NO;
  }

  [tab setDeveloperToolsBrowser:browser];
  [tab.developerToolsHostView setBrowser:browser];
  [tab.developerToolsHostView layoutSubtreeIfNeeded];
  return YES;
}

- (BOOL)detachClosedBrowser:(CefRefPtr<CefBrowser>)browser
              selectedGroup:(BabelBrowserGroup*)selectedGroup
              isTerminating:(BOOL)isTerminating {
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab developerToolsBrowser] && [tab developerToolsBrowser]->IsSame(browser)) {
        if (hideDeveloperToolsHandler_) {
          hideDeveloperToolsHandler_(tab);
        }
        return NO;
      }
    }
  }

  if (browser->IsPopup()) {
    return NO;
  }

  BabelBrowserTab* tabToRemove = nil;
  BabelBrowserGroup* groupToSelect = nil;
  for (BabelBrowserGroup* group in groups_) {
    for (BabelBrowserTab* tab in group.tabs) {
      if ([tab browser] && [tab browser]->IsSame(browser)) {
        tabToRemove = tab;
        groupToSelect = group;
        break;
      }
    }
    if (tabToRemove) {
      break;
    }
  }

  if (!tabToRemove) {
    return NO;
  }

  if ([evictionPolicy_ isTabEvicting:tabToRemove]) {
    [evictionPolicy_ unmarkTabEvicting:tabToRemove];
    [tabToRemove setBrowser:nullptr];
    [tabToRemove.hostView setBrowser:nullptr];
    return NO;
  }

  if (groupToSelect && groupToSelect != selectedGroup && selectGroupHandler_) {
    selectGroupHandler_(groupToSelect);
  }
  if (removeTabHandler_) {
    removeTabHandler_(tabToRemove);
  }

  return isTerminating && totalTabCountProvider_ && 0 == totalTabCountProvider_();
}

- (void)removeTab:(BabelBrowserTab*)tab fromGroup:(BabelBrowserGroup*)group {
  if (!tab || !group) {
    return;
  }

  [tab.tabItemView removeFromSuperview];
  [tab.hostView removeFromSuperview];
  [tab.developerToolsPanelView removeFromSuperview];
  [group.tabs removeObject:tab];
  [pendingTabs_ removeObject:tab];
  [evictionPolicy_ removeTab:tab];
}

@end
