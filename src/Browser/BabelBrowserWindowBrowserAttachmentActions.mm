#import "Browser/BabelBrowserWindowBrowserAttachmentActions.h"

#import "Browser/BrowserWindowControllerPrivate.h"

@implementation BabelBrowserWindowBrowserAttachmentActions {
  __weak BabelBrowserWindowController* owner_;
}

- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner {
  self = [super init];
  if (self) {
    owner_ = owner;
  }
  return self;
}

- (void)attachCreatedBrowser:(CefRefPtr<CefBrowser>)browser {
  if (browser->IsPopup()) {
    [owner_ attachCreatedPopupBrowser:browser];
    return;
  }

  if (owner_->pendingDeveloperToolsTab_) {
    BabelBrowserTab* tab = owner_->pendingDeveloperToolsTab_;
    owner_->pendingDeveloperToolsTab_ = nil;
    [owner_->browserAttachmentCoordinator_ attachDeveloperToolsBrowser:browser toTab:tab];
    return;
  }

  [owner_->browserAttachmentCoordinator_ attachPageBrowser:browser];
}

- (void)attachCreatedPopupBrowser:(CefRefPtr<CefBrowser>)browser {
  BabelBrowserTab* tab = owner_->pendingDeveloperToolsTab_;
  owner_->pendingDeveloperToolsTab_ = nil;
  if (!tab) {
    return;
  }

  [owner_->browserAttachmentCoordinator_ attachDeveloperToolsBrowser:browser toTab:tab];
  [owner_ reparentDeveloperToolsBrowser:browser intoTab:tab];
  [owner_ layoutBrowserViewsForTab:tab];
}

- (void)detachClosedBrowser:(CefRefPtr<CefBrowser>)browser {
  if ([owner_->browserAttachmentCoordinator_ detachClosedBrowser:browser
                                           selectedGroup:owner_->selectedGroup_
                                           isTerminating:owner_->isTerminating_]) {
    CefQuitMessageLoop();
  }
}

- (void)removeSelectedGroupTab:(BabelBrowserTab*)tab {
  [owner_ removeTab:tab fromGroup:owner_->selectedGroup_ allowSelection:YES];
}

- (void)removeTab:(BabelBrowserTab*)tab {
  [owner_ removeSelectedGroupTab:tab];
}

- (void)removeTab:(BabelBrowserTab*)tab
        fromGroup:(BabelBrowserGroup*)group
   allowSelection:(BOOL)allowSelection {
  [owner_ closeDeveloperToolsForTab:tab];
  [owner_->browserAttachmentCoordinator_ removeTab:tab fromGroup:group];
  if (group == owner_->selectedGroup_) {
    [owner_->tabs_ removeObject:tab];
  }

  if (allowSelection && owner_->selectedTab_ == tab) {
    owner_->selectedTab_ = owner_->tabs_.lastObject;
    if (owner_->selectedTab_) {
      [owner_ selectTab:owner_->selectedTab_];
    } else {
      [owner_ clearAddressBar];
    }
  }

  if (group == owner_->selectedGroup_) {
    [owner_ layoutTabItemsSelectingLastTab:NO];
  }
  [owner_ saveGroupsState];
}


@end
