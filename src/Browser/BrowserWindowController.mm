#import "Browser/BrowserWindowController.h"

#import "Browser/BrowserClient.h"
#import "Browser/AdjacentTabPreloadPlanner.h"
#import "Browser/AppSettingsPageRenderer.h"
#import "Browser/DeveloperToolsDockingPolicy.h"
#import "Browser/BrowserSettingsStore.h"
#import "Browser/BrowserTabFactory.h"
#import "Browser/ChromeCommandParser.h"
#import "Browser/DeveloperToolsDockingStore.h"
#import "Browser/DeveloperToolsLayoutCalculator.h"
#import "Browser/ExtensionProfileStore.h"
#import "Browser/ExtensionsPageRenderer.h"
#import "Browser/FaviconStore.h"
#import "Browser/GoogleSuggestClient.h"
#import "Browser/BrowserGroupCollection.h"
#import "Browser/BrowserGroupFactory.h"
#import "Browser/BrowserGroupMoveCoordinator.h"
#import "Browser/BrowserTabCollection.h"
#import "Browser/BrowserTabInsertionCoordinator.h"
#import "Browser/BrowserTabMoveCoordinator.h"
#import "Browser/GroupListCoordinator.h"
#import "Browser/GroupSessionStore.h"
#import "Browser/HistoryPageRenderer.h"
#import "Browser/InternalNavigationActionParser.h"
#import "Browser/InternalPageRenderer.h"
#import "Browser/InternalSettingsNavigationHandler.h"
#import "Browser/LiveBrowserEvictionPolicy.h"
#import "Browser/LocalDropBridgeScriptBuilder.h"
#import "Browser/LocalDropCoordinator.h"
#import "Browser/ModuleActionService.h"
#import "Browser/ModulePageRenderer.h"
#import "Browser/ModuleSettingsPageRenderer.h"
#import "Browser/ModuleUpdateService.h"
#import "Browser/ModuleUIActionCoordinator.h"
#import "Browser/NewTabURLResolver.h"
#import "Browser/OmniboxLocalSuggestionBuilder.h"
#import "Browser/OmniboxSuggestionsController.h"
#import "Browser/RecentlyClosedTabStore.h"
#import "Browser/RuntimeRefreshCoordinator.h"
#import "Browser/SettingsOptionRenderer.h"
#import "Browser/SidebarLayoutCalculator.h"
#import "Browser/StableServerURLResolver.h"
#import "Browser/StableViewerURLResolver.h"
#import "Browser/TabDragCoordinator.h"
#import "Browser/TabPlacementPolicy.h"
#import "Browser/TabStripLayoutCalculator.h"
#import "Browser/TabURLMatcher.h"
#import "Browser/BrowserModels.h"
#import "Browser/BrowserSupportViews.h"
#import "Browser/BrowserTheme.h"
#import "Browser/BrowserViews.h"
#import "Browser/WindowStateStore.h"
#import "Configuration/Configuration.h"
#import "LocalServices/LocalServiceHost.h"

#include <cmath>
#include <vector>

#include "include/cef_browser.h"
#include "include/cef_app.h"
#include "include/cef_callback.h"
#include "include/wrapper/cef_helpers.h"

static const CGFloat kSidebarInitialWidth = 240.0;
static const CGFloat kSidebarHeaderButtonSize = 28.0;
static const CGFloat kSidebarHeaderLeadingInset = 10.0;
static const CGFloat kSidebarHeaderButtonGap = 8.0;
static const CGFloat kSidebarHeaderTrailingInset = 12.0;
static const CGFloat kSidebarTitleRenderPadding = 4.0;
static const CGFloat kSidebarMaximumWidth = 360.0;
static const CGFloat kSidebarCollapsedWidth = 48.0;
static const CGFloat kTabBarHeight = 40.0;
static const CGFloat kTitlebarTabLeadingInset = 88.0;
static const CGFloat kToolbarHeight = 44.0;
static const CGFloat kTabNormalWidth = 184.0;
static const CGFloat kTabActiveWidth = 210.0;
static const CGFloat kTabMinimumWidth = 36.0;
static const CGFloat kTabHeight = 32.0;
static const CGFloat kTabSpacing = 3.0;
static const CGFloat kNewTabButtonWidth = 34.0;
static const CGFloat kDeveloperToolsToolbarHeight = 30.0;
static const CGFloat kDeveloperToolsResizeHandleThickness = 7.0;
static const CGFloat kLinkStatusBarHeight = 24.0;
static const CGFloat kLinkStatusBarMaximumWidth = 760.0;
static const CGFloat kOmniboxSuggestionRowHeight = 44.0;
static const NSUInteger kOmniboxSuggestionMaximumCount = 10;
static const CGFloat kOmniboxSuggestionPanelMaximumHeight =
    kOmniboxSuggestionRowHeight * kOmniboxSuggestionMaximumCount;
static const int64_t kGoogleSuggestDebounceDelayNanoseconds = 220 * NSEC_PER_MSEC;
static NSString* const kDefaultGroupIdentifier = @"default";
static NSString* const kDefaultGroupName = @"default";
static NSString* const kDeveloperToolsDockModeDefaultsKey = @"DeveloperToolsDockMode";
static NSString* const kDeveloperToolsSizeRatioDefaultsKey = @"DeveloperToolsSizeRatio";
static NSString* const kModuleUpdateURLDefaultsKey = @"ModuleUpdateURL";
static NSString* const kModuleUpdateLocalDirectoryDefaultsKey = @"ModuleUpdateLocalDirectory";
static NSString* const kModuleUpdateLocalIndexFilename = @"module-update-local-index.json";
static NSString* const kDeveloperToolsDockModeBottom = @"bottom";
static NSString* const kDeveloperToolsDockModeTop = @"top";
static NSString* const kDeveloperToolsDockModeLeft = @"left";
static NSString* const kDeveloperToolsDockModeRight = @"right";
static NSString* const kHistoryPageURLString = @"babelchrome://history";
static NSString* const kSettingsPageURLString = @"babelchrome://settings";
static NSString* const kExtensionsPageURLString = @"babelchrome://extensions";
static NSString* const kModulesPageURLString = @"babelchrome://modules";
static const NSInteger kDeveloperToolsDockTagLeft = 1;
static const NSInteger kDeveloperToolsDockTagRight = 2;
static const NSInteger kDeveloperToolsDockTagBottom = 3;
static const NSInteger kDeveloperToolsDockTagTop = 4;
static const int64_t kKeyboardTabSelectionBrowserCreationDelayNanoseconds = 220 * NSEC_PER_MSEC;
static const int64_t kAdjacentTabPreloadInitialDelayNanoseconds = 700 * NSEC_PER_MSEC;
static const int64_t kAdjacentTabPreloadStepDelayNanoseconds = 350 * NSEC_PER_MSEC;
static const int64_t kTabDragGroupHoverDelayNanoseconds = 450 * NSEC_PER_MSEC;
static const NSUInteger kMaximumLivePageBrowsers = 8;

@implementation BabelBrowserWindowController {
  NSView* rootView_;
  NSView* splitView_;
  NSView* sidebarView_;
  BabelDeveloperToolsResizeHandleView* sidebarResizeHandleView_;
  NSTextField* sidebarTitle_;
  NSButton* sidebarCollapseButton_;
  NSButton* newGroupButton_;
  NSView* groupsListView_;
  NSView* rightView_;
  NSView* tabsBarPanel_;
  NSView* tabsItemsPanel_;
  NSButton* newTabButton_;
  NSView* addressBarPanel_;
  NSTextField* addressLabel_;
  NSView* addressTextFieldContainer_;
  NSTextField* urlTextField_;
  BabelBadgeLabel* viewerBadgeLabel_;
  NSButton* reloadButton_;
  NSView* omniboxSuggestionsPanel_;
  NSView* pagesPanel_;
  NSView* linkStatusBarView_;
  NSTextField* linkStatusBarLabel_;
  NSMutableArray<BabelBrowserGroup*>* groups_;
  BabelAdjacentTabPreloadPlanner* adjacentTabPreloadPlanner_;
  BabelAppSettingsPageRenderer* appSettingsPageRenderer_;
  BabelBrowserSettingsStore* browserSettingsStore_;
  BabelBrowserTabFactory* browserTabFactory_;
  BabelChromeCommandParser* chromeCommandParser_;
  BabelDeveloperToolsDockingPolicy* developerToolsDockingPolicy_;
  BabelDeveloperToolsDockingStore* developerToolsDockingStore_;
  BabelDeveloperToolsLayoutCalculator* developerToolsLayoutCalculator_;
  BabelExtensionProfileStore* extensionProfileStore_;
  BabelExtensionsPageRenderer* extensionsPageRenderer_;
  BabelFaviconStore* faviconStore_;
  BabelGoogleSuggestClient* googleSuggestClient_;
  BabelBrowserGroupCollection* browserGroupCollection_;
  BabelBrowserGroupFactory* browserGroupFactory_;
  BabelBrowserGroupMoveCoordinator* browserGroupMoveCoordinator_;
  BabelBrowserTabCollection* browserTabCollection_;
  BabelBrowserTabInsertionCoordinator* browserTabInsertionCoordinator_;
  BabelBrowserTabMoveCoordinator* browserTabMoveCoordinator_;
  BabelGroupListCoordinator* groupListCoordinator_;
  BabelGroupSessionStore* groupSessionStore_;
  BabelHistoryPageRenderer* historyPageRenderer_;
  BabelInternalNavigationActionParser* internalNavigationActionParser_;
  BabelInternalPageRenderer* internalPageRenderer_;
  BabelInternalSettingsNavigationHandler* internalSettingsNavigationHandler_;
  BabelLiveBrowserEvictionPolicy* liveBrowserEvictionPolicy_;
  BabelLocalDropBridgeScriptBuilder* localDropBridgeScriptBuilder_;
  BabelLocalDropCoordinator* localDropCoordinator_;
  BabelModuleActionService* moduleActionService_;
  BabelModulePageRenderer* modulePageRenderer_;
  BabelModuleSettingsPageRenderer* moduleSettingsPageRenderer_;
  BabelModuleUpdateService* moduleUpdateService_;
  BabelModuleUIActionCoordinator* moduleUIActionCoordinator_;
  BabelNewTabURLResolver* newTabURLResolver_;
  BabelOmniboxLocalSuggestionBuilder* omniboxLocalSuggestionBuilder_;
  BabelOmniboxSuggestionsController* omniboxSuggestionsController_;
  BabelRecentlyClosedTabStore* recentlyClosedTabStore_;
  BabelRuntimeRefreshCoordinator* runtimeRefreshCoordinator_;
  BabelSettingsOptionRenderer* settingsOptionRenderer_;
  BabelSidebarLayoutCalculator* sidebarLayoutCalculator_;
  BabelStableServerURLResolver* stableServerURLResolver_;
  BabelStableViewerURLResolver* stableViewerURLResolver_;
  BabelTabDragCoordinator* tabDragCoordinator_;
  BabelTabStripLayoutCalculator* tabStripLayoutCalculator_;
  BabelTabURLMatcher* tabURLMatcher_;
  BabelWindowStateStore* windowStateStore_;
  BabelBrowserGroup* selectedGroup_;
  NSMutableArray<BabelBrowserTab*>* tabs_;
  NSMutableArray<BabelBrowserTab*>* pendingTabs_;
  BabelBrowserTab* selectedTab_;
  BabelBrowserTab* draggingTab_;
  BabelBrowserGroup* pendingTabDragHoverGroup_;
  BabelBrowserTab* pendingDeveloperToolsTab_;
  CefRefPtr<BabelBrowserClient> browserClient_;
  NSString* developerToolsDockMode_;
  CGFloat developerToolsSizeRatio_;
  CGFloat expandedSidebarWidth_;
  BOOL sidebarCollapsed_;
  BOOL isTerminating_;
  BOOL didRestoreMainWindowState_;
  BOOL isReorderingGroups_;
  BOOL isReorderingTabs_;
  BOOL isDraggingTabAcrossGroups_;
  BOOL isRestoringSession_;
  BOOL isBuildingInterface_;
  BOOL didApplyInitialSidebarRestore_;
  BOOL needsInitialRestoredBrowserCreation_;
  NSUInteger deferredBrowserCreationGeneration_;
  NSUInteger adjacentTabPreloadGeneration_;
  NSUInteger tabDragHoverGeneration_;
  NSUInteger googleSuggestGeneration_;
}

- (instancetype)init {
  NSRect frame = NSMakeRect(0, 0, 1280, 820);
  NSWindow* window =
      [[BabelMainWindow alloc] initWithContentRect:frame
                                         styleMask:NSWindowStyleMaskTitled |
                                                   NSWindowStyleMaskClosable |
                                                   NSWindowStyleMaskMiniaturizable |
                                                   NSWindowStyleMaskResizable
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
  window.title = BabelChromeConfiguration.applicationName;
  window.minSize = NSMakeSize(900, 580);
  window.titleVisibility = NSWindowTitleHidden;
  window.titlebarAppearsTransparent = YES;
  window.movableByWindowBackground = YES;
  window.styleMask = window.styleMask | NSWindowStyleMaskFullSizeContentView;

  self = [super initWithWindow:window];
  if (self) {
    groups_ = [NSMutableArray array];
    adjacentTabPreloadPlanner_ = [[BabelAdjacentTabPreloadPlanner alloc] init];
    browserSettingsStore_ =
        [[BabelBrowserSettingsStore alloc] initWithUserDefaults:NSUserDefaults.standardUserDefaults];
    chromeCommandParser_ =
        [[BabelChromeCommandParser alloc] initWithDefaultGroupName:kDefaultGroupName
                                                  defaultURLString:BabelChromeConfiguration.defaultURLString];
    developerToolsDockingPolicy_ =
        [[BabelDeveloperToolsDockingPolicy alloc] initWithBottomMode:kDeveloperToolsDockModeBottom
                                                             topMode:kDeveloperToolsDockModeTop
                                                            leftMode:kDeveloperToolsDockModeLeft
                                                           rightMode:kDeveloperToolsDockModeRight
                                                             leftTag:kDeveloperToolsDockTagLeft
                                                            rightTag:kDeveloperToolsDockTagRight
                                                           bottomTag:kDeveloperToolsDockTagBottom
                                                              topTag:kDeveloperToolsDockTagTop];
    developerToolsDockingStore_ =
        [[BabelDeveloperToolsDockingStore alloc] initWithUserDefaults:NSUserDefaults.standardUserDefaults
                                                  dockModeDefaultsKey:kDeveloperToolsDockModeDefaultsKey
                                                 sizeRatioDefaultsKey:kDeveloperToolsSizeRatioDefaultsKey];
    developerToolsLayoutCalculator_ = [[BabelDeveloperToolsLayoutCalculator alloc] init];
    extensionProfileStore_ =
        [[BabelExtensionProfileStore alloc]
            initWithProfileDirectoryURL:BabelChromeConfiguration.profileDirectoryURL
      profileExtensionBackupDirectoryURL:BabelChromeConfiguration.profileExtensionBackupDirectoryURL
                            userDefaults:NSUserDefaults.standardUserDefaults
               extensionPathsDefaultsKey:BabelChromeConfiguration.extensionPathsDefaultsKey
disabledProfileExtensionIdentifiersDefaultsKey:BabelChromeConfiguration.disabledProfileExtensionIdentifiersDefaultsKey
pendingProfileExtensionRestartStatesDefaultsKey:BabelChromeConfiguration.pendingProfileExtensionRestartStatesDefaultsKey];
    extensionsPageRenderer_ =
        [[BabelExtensionsPageRenderer alloc] initWithTrashIconHTML:[self trashIconHTML]];
    faviconStore_ =
        [[BabelFaviconStore alloc] initWithStoreFileURL:BabelChromeConfiguration.faviconStoreFileURL];
    __weak BabelBrowserWindowController* weakSelf = self;
    browserTabFactory_ =
        [[BabelBrowserTabFactory alloc]
            initWithFaviconStore:faviconStore_
                    actionTarget:self
               compactTitleBlock:^NSString*(NSString* title) {
                 return [weakSelf compactTitleForString:title];
               }
        localDropAcceptanceBlock:^BOOL(BabelPageContainerView* container) {
          return [weakSelf pageContainerSupportsLocalDrop:container];
        }
            localDropHandlerBlock:^(BabelPageContainerView* container) {
              [weakSelf pageContainerDidReceiveLocalDrop:container];
            }];
    googleSuggestClient_ = [[BabelGoogleSuggestClient alloc] init];
    browserGroupCollection_ = [[BabelBrowserGroupCollection alloc] init];
    browserGroupFactory_ = [[BabelBrowserGroupFactory alloc] initWithActionTarget:self];
    browserGroupMoveCoordinator_ = [[BabelBrowserGroupMoveCoordinator alloc] init];
    browserTabCollection_ = [[BabelBrowserTabCollection alloc] init];
    BabelTabPlacementPolicy* tabPlacementPolicy = [[BabelTabPlacementPolicy alloc] init];
    browserTabInsertionCoordinator_ =
        [[BabelBrowserTabInsertionCoordinator alloc] initWithPlacementPolicy:tabPlacementPolicy
                                                               tabCollection:browserTabCollection_];
    groupListCoordinator_ = [[BabelGroupListCoordinator alloc] init];
    groupSessionStore_ = [[BabelGroupSessionStore alloc] init];
    historyPageRenderer_ = [[BabelHistoryPageRenderer alloc] init];
    internalNavigationActionParser_ = [[BabelInternalNavigationActionParser alloc] init];
    internalPageRenderer_ = [[BabelInternalPageRenderer alloc] init];
    internalSettingsNavigationHandler_ =
        [[BabelInternalSettingsNavigationHandler alloc] initWithSettingsStore:browserSettingsStore_
                                                                 userDefaults:NSUserDefaults.standardUserDefaults];
    liveBrowserEvictionPolicy_ = [[BabelLiveBrowserEvictionPolicy alloc] init];
    localDropBridgeScriptBuilder_ = [[BabelLocalDropBridgeScriptBuilder alloc] init];
    localDropCoordinator_ = [[BabelLocalDropCoordinator alloc] init];
    moduleActionService_ = [[BabelModuleActionService alloc] init];
    modulePageRenderer_ =
        [[BabelModulePageRenderer alloc]
            initWithGearIconHTML:[self resourceSVGIconHTMLNamed:@"settings-gear" fallback:@"&#9881;"]
                    trashIconHTML:[self trashIconHTML]];
    moduleUpdateService_ =
        [[BabelModuleUpdateService alloc]
            initWithUserDefaults:NSUserDefaults.standardUserDefaults
             updateURLDefaultsKey:kModuleUpdateURLDefaultsKey
   updateLocalDirectoryDefaultsKey:kModuleUpdateLocalDirectoryDefaultsKey
                localIndexFilePath:[BabelChromeConfiguration.applicationSupportDirectoryURL.path
                                       stringByAppendingPathComponent:kModuleUpdateLocalIndexFilename]];
    moduleUIActionCoordinator_ =
        [[BabelModuleUIActionCoordinator alloc] initWithModuleActionService:moduleActionService_
                                                        moduleUpdateService:moduleUpdateService_];
    newTabURLResolver_ =
        [[BabelNewTabURLResolver alloc]
            initWithSupportedViewerURLResolver:^NSString*(NSString* urlString) {
              return [weakSelf stableViewerURLStringForSupportedURLString:urlString];
            }
            stableNavigationURLResolver:^NSString*(NSString* urlString) {
              return [weakSelf navigationURLStringForStableBabelChromeURLString:urlString];
            }
            stableViewerURLPredicate:^BOOL(NSString* urlString) {
              BabelBrowserWindowController* strongSelf = weakSelf;
              return strongSelf ? [strongSelf->stableViewerURLResolver_ isStableViewerURLString:urlString] : NO;
            }];
    omniboxLocalSuggestionBuilder_ = [[BabelOmniboxLocalSuggestionBuilder alloc] init];
    recentlyClosedTabStore_ = [[BabelRecentlyClosedTabStore alloc] init];
    runtimeRefreshCoordinator_ = [[BabelRuntimeRefreshCoordinator alloc] init];
    settingsOptionRenderer_ = [[BabelSettingsOptionRenderer alloc] init];
    sidebarLayoutCalculator_ =
        [[BabelSidebarLayoutCalculator alloc] initWithHeaderButtonSize:kSidebarHeaderButtonSize
                                                    headerLeadingInset:kSidebarHeaderLeadingInset
                                                       headerButtonGap:kSidebarHeaderButtonGap
                                                   headerTrailingInset:kSidebarHeaderTrailingInset];
    appSettingsPageRenderer_ =
        [[BabelAppSettingsPageRenderer alloc] initWithOptionRenderer:settingsOptionRenderer_];
    moduleSettingsPageRenderer_ =
        [[BabelModuleSettingsPageRenderer alloc] initWithOptionRenderer:settingsOptionRenderer_];
    stableServerURLResolver_ = [[BabelStableServerURLResolver alloc] init];
    stableViewerURLResolver_ = [[BabelStableViewerURLResolver alloc] init];
    tabDragCoordinator_ = [[BabelTabDragCoordinator alloc] init];
    browserTabMoveCoordinator_ =
        [[BabelBrowserTabMoveCoordinator alloc] initWithDragCoordinator:tabDragCoordinator_];
    tabStripLayoutCalculator_ =
        [[BabelTabStripLayoutCalculator alloc] initWithNormalWidth:kTabNormalWidth
                                                       activeWidth:kTabActiveWidth
                                                      minimumWidth:kTabMinimumWidth
                                                          tabHeight:kTabHeight
                                                            spacing:kTabSpacing];
    tabURLMatcher_ = [[BabelTabURLMatcher alloc] init];
    windowStateStore_ = [[BabelWindowStateStore alloc] initWithUserDefaults:NSUserDefaults.standardUserDefaults];
    tabs_ = [NSMutableArray array];
    pendingTabs_ = [NSMutableArray array];
    browserClient_ = new BabelBrowserClient(self);
    developerToolsDockMode_ = [self restoredDeveloperToolsDockMode];
    developerToolsSizeRatio_ = [self restoredDeveloperToolsSizeRatio];
    expandedSidebarWidth_ = kSidebarInitialWidth;
    sidebarCollapsed_ = NO;
    isTerminating_ = NO;
    didRestoreMainWindowState_ = NO;
    isReorderingGroups_ = NO;
    isReorderingTabs_ = NO;
    isDraggingTabAcrossGroups_ = NO;
    isRestoringSession_ = NO;
    isBuildingInterface_ = NO;
    didApplyInitialSidebarRestore_ = NO;
    needsInitialRestoredBrowserCreation_ = NO;
    deferredBrowserCreationGeneration_ = 0;
    adjacentTabPreloadGeneration_ = 0;
    tabDragHoverGeneration_ = 0;
    googleSuggestGeneration_ = 0;
    [extensionProfileStore_ restoreProfileExtensionsMovedByOlderVersions];
    [extensionProfileStore_ clearPendingProfileExtensionRestartStates];
    window.delegate = self;
    [self buildInterface];
    omniboxSuggestionsController_ =
        [[BabelOmniboxSuggestionsController alloc] initWithPanel:omniboxSuggestionsPanel_];
    [faviconStore_ restore];
    [self restoreSessionByPriority];
  }
  return self;
}

#include "BrowserWindowController+WindowLifecycle.inc.mm"

#include "BrowserWindowController+GroupsAndTabs.inc.mm"

#include "BrowserWindowController+URLRouting.inc.mm"

#include "BrowserWindowController+LocalDrop.inc.mm"

#include "BrowserWindowController+InternalPages.inc.mm"

#include "BrowserWindowController+BrowserControls.inc.mm"

#include "BrowserWindowController+BrowserAttachment.inc.mm"
#include "BrowserWindowController+DeveloperToolsEmbedding.inc.mm"
#include "BrowserWindowController+AddressAndSuggestions.inc.mm"

@end
