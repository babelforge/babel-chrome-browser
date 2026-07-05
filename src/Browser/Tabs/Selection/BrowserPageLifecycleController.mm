#import "Browser/Tabs/Selection/BrowserPageLifecycleController.h"

#import "Browser/Tabs/Selection/AdjacentTabPreloadPlanner.h"
#import "Browser/CEF/Client/BrowserClient.h"
#import "Browser/Tabs/Creation/BrowserCreationScheduler.h"
#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/UI/Views/BrowserViews.h"
#import "Browser/Tabs/Lifecycle/LiveBrowserEvictionPolicy.h"
#import "Browser/Tabs/Lifecycle/LiveBrowserLimitEnforcer.h"

#include "include/cef_browser.h"

@implementation BabelBrowserPageLifecycleController {
  NSMutableArray<BabelBrowserGroup*>* groups_;
  NSMutableArray<BabelBrowserTab*>* pendingTabs_;
  CefRefPtr<BabelBrowserClient> browserClient_;
  BabelBrowserCreationScheduler* creationScheduler_;
  BabelAdjacentTabPreloadPlanner* adjacentTabPreloadPlanner_;
  BabelLiveBrowserEvictionPolicy* evictionPolicy_;
  BabelLiveBrowserLimitEnforcer* liveBrowserLimitEnforcer_;
  int64_t keyboardDelayNanoseconds_;
  int64_t adjacentInitialDelayNanoseconds_;
  int64_t adjacentStepDelayNanoseconds_;
  BabelVisibleTabsProvider visibleTabsProvider_;
  BabelCurrentTabProvider selectedTabProvider_;
  BabelBrowserTerminationProvider terminationProvider_;
  BOOL needsInitialRestoredBrowserCreation_;
}

- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                   pendingTabs:(NSMutableArray<BabelBrowserTab*>*)pendingTabs
                 browserClient:(CefRefPtr<BabelBrowserClient>)browserClient
             creationScheduler:(BabelBrowserCreationScheduler*)creationScheduler
      adjacentTabPreloadPlanner:(BabelAdjacentTabPreloadPlanner*)adjacentTabPreloadPlanner
                evictionPolicy:(BabelLiveBrowserEvictionPolicy*)evictionPolicy
       liveBrowserLimitEnforcer:(BabelLiveBrowserLimitEnforcer*)liveBrowserLimitEnforcer
       keyboardDelayNanoseconds:(int64_t)keyboardDelayNanoseconds
adjacentInitialDelayNanoseconds:(int64_t)adjacentInitialDelayNanoseconds
   adjacentStepDelayNanoseconds:(int64_t)adjacentStepDelayNanoseconds
           visibleTabsProvider:(BabelVisibleTabsProvider)visibleTabsProvider
            selectedTabProvider:(BabelCurrentTabProvider)selectedTabProvider
            terminationProvider:(BabelBrowserTerminationProvider)terminationProvider {
  self = [super init];
  if (self) {
    groups_ = groups;
    pendingTabs_ = pendingTabs;
    browserClient_ = browserClient;
    creationScheduler_ = creationScheduler;
    adjacentTabPreloadPlanner_ = adjacentTabPreloadPlanner;
    evictionPolicy_ = evictionPolicy;
    liveBrowserLimitEnforcer_ = liveBrowserLimitEnforcer;
    keyboardDelayNanoseconds_ = keyboardDelayNanoseconds;
    adjacentInitialDelayNanoseconds_ = adjacentInitialDelayNanoseconds;
    adjacentStepDelayNanoseconds_ = adjacentStepDelayNanoseconds;
    visibleTabsProvider_ = [visibleTabsProvider copy];
    selectedTabProvider_ = [selectedTabProvider copy];
    terminationProvider_ = [terminationProvider copy];
    needsInitialRestoredBrowserCreation_ = NO;
  }
  return self;
}

- (void)markNeedsInitialRestoredBrowserCreation {
  needsInitialRestoredBrowserCreation_ = YES;
}

- (void)cancelKeyboardBrowserCreation {
  [creationScheduler_ cancelKeyboardBrowserCreation];
}

- (void)createBrowserForTabIfNeeded:(BabelBrowserTab*)tab {
  NSArray<BabelBrowserTab*>* visibleTabs = visibleTabsProvider_ ? visibleTabsProvider_() : @[];
  if (!tab || ![visibleTabs containsObject:tab] || [tab browser] || [pendingTabs_ containsObject:tab]) {
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

  __weak BabelBrowserPageLifecycleController* weakSelf = self;
  [creationScheduler_ scheduleKeyboardBrowserCreationForTab:tab
                                           delayNanoseconds:keyboardDelayNanoseconds_
                                        selectedTabProvider:^BabelBrowserTab* {
                                          BabelBrowserPageLifecycleController* strongSelf = weakSelf;
                                          return [strongSelf selectedTab];
                                        }
                                        terminationProvider:^BOOL {
                                          BabelBrowserPageLifecycleController* strongSelf = weakSelf;
                                          return [strongSelf isTerminating];
                                        }
                                              createHandler:^(BabelBrowserTab* tabToCreate) {
                                                [weakSelf createBrowserForTabIfNeeded:tabToCreate];
                                              }
                                             preloadHandler:^{
                                               [weakSelf scheduleAdjacentTabPreloadForSelectedTab];
                                             }];
}

- (void)createInitialRestoredBrowserIfNeeded {
  BabelBrowserTab* selectedTab = [self selectedTab];
  if (!needsInitialRestoredBrowserCreation_ || [self isTerminating] || !selectedTab) {
    return;
  }

  needsInitialRestoredBrowserCreation_ = NO;
  [creationScheduler_ cancelKeyboardBrowserCreation];
  [self createBrowserForTabIfNeeded:selectedTab];
  [self scheduleAdjacentTabPreloadForSelectedTab];
}

- (void)scheduleAdjacentTabPreloadForSelectedTab {
  NSArray<BabelBrowserTab*>* visibleTabs = visibleTabsProvider_ ? visibleTabsProvider_() : @[];
  BabelBrowserTab* selectedTab = [self selectedTab];
  if ([self isTerminating] || !selectedTab || visibleTabs.count < 2) {
    return;
  }

  NSArray<BabelBrowserTab*>* tabsToPreload =
      [adjacentTabPreloadPlanner_ adjacentTabsToPreloadAroundTab:selectedTab tabs:visibleTabs];
  __weak BabelBrowserPageLifecycleController* weakSelf = self;
  [creationScheduler_ scheduleAdjacentPreloadForTabs:tabsToPreload
                                           anchorTab:selectedTab
                             initialDelayNanoseconds:adjacentInitialDelayNanoseconds_
                                stepDelayNanoseconds:adjacentStepDelayNanoseconds_
                                  selectedTabProvider:^BabelBrowserTab* {
                                    BabelBrowserPageLifecycleController* strongSelf = weakSelf;
                                    return [strongSelf selectedTab];
                                  }
                                  terminationProvider:^BOOL {
                                    BabelBrowserPageLifecycleController* strongSelf = weakSelf;
                                    return [strongSelf isTerminating];
                                  }
                                        createHandler:^(BabelBrowserTab* tabToPreload) {
                                          [weakSelf createBrowserForTabIfNeeded:tabToPreload];
                                        }];
}

- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab {
  NSArray<BabelBrowserTab*>* visibleTabs = visibleTabsProvider_ ? visibleTabsProvider_() : @[];
  return [adjacentTabPreloadPlanner_ adjacentTabsToPreloadAroundTab:tab tabs:visibleTabs];
}

- (void)touchRecentlyUsedTab:(BabelBrowserTab*)tab {
  [evictionPolicy_ touchTab:tab];
}

- (void)closeBrowserForTabKeepingNativeTab:(BabelBrowserTab*)tab {
  CefRefPtr<CefBrowser> browser = [tab browser];
  if (!browser || tab.identifier.length == 0) {
    return;
  }

  [evictionPolicy_ markTabEvicting:tab];
  browser->GetHost()->CloseDevTools();
  browser->GetHost()->CloseBrowser(true);
}

- (void)enforceLivePageBrowserLimit {
  if ([self isTerminating]) {
    return;
  }

  __weak BabelBrowserPageLifecycleController* weakSelf = self;
  [liveBrowserLimitEnforcer_ enforceLiveBrowserLimitForGroups:groups_
                                                  selectedTab:[self selectedTab]
                                                  visibleTabs:(visibleTabsProvider_ ? visibleTabsProvider_() : @[])
                                                 closeHandler:^(BabelBrowserTab* tab) {
                                                   [weakSelf closeBrowserForTabKeepingNativeTab:tab];
                                                 }];
}

- (void)reset {
  [pendingTabs_ removeAllObjects];
  [evictionPolicy_ reset];
  needsInitialRestoredBrowserCreation_ = NO;
}

- (BabelBrowserTab*)selectedTab {
  return selectedTabProvider_ ? selectedTabProvider_() : nil;
}

- (BOOL)isTerminating {
  return terminationProvider_ ? terminationProvider_() : YES;
}

@end
