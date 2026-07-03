#import "Browser/BrowserWindowController.h"

#import "Browser/BrowserClient.h"
#import "Browser/ExtensionProfileStore.h"
#import "Browser/FaviconStore.h"
#import "Browser/ModuleActionService.h"
#import "Browser/ModulePageRenderer.h"
#import "Browser/ModuleUpdateService.h"
#import "Browser/ModuleUIActionCoordinator.h"
#import "Browser/BrowserModels.h"
#import "Browser/BrowserTheme.h"
#import "Browser/BrowserViews.h"
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
static const CGFloat kWindowFrameComparisonTolerance = 2.0;
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
static NSString* const kSidebarCollapsedDefaultsKey = @"SidebarCollapsed";
static NSString* const kSidebarWidthDefaultsKey = @"SidebarWidth";
static NSString* const kAddressSuggestionsModeDefaultsKey = @"AddressSuggestionsMode";
static NSString* const kTabOpeningStrategyDefaultsKey = @"TabOpeningStrategy";
static NSString* const kMarkdownThemeDefaultsKey = @"MarkdownTheme";
static NSString* const kMainWindowFrameDefaultsKey = @"MainWindowFrame";
static NSString* const kMainWindowZoomedDefaultsKey = @"MainWindowZoomed";
static NSString* const kLongQuitShortcutEnabledDefaultsKey = @"LongQuitShortcutEnabled";
static NSString* const kModuleUpdateURLDefaultsKey = @"ModuleUpdateURL";
static NSString* const kModuleUpdateLocalDirectoryDefaultsKey = @"ModuleUpdateLocalDirectory";
static NSString* const kModuleUpdateLocalIndexFilename = @"module-update-local-index.json";
static NSString* const kDeveloperToolsDockModeBottom = @"bottom";
static NSString* const kDeveloperToolsDockModeTop = @"top";
static NSString* const kDeveloperToolsDockModeLeft = @"left";
static NSString* const kDeveloperToolsDockModeRight = @"right";
static NSString* const kTabOpeningStrategyAppend = @"append";
static NSString* const kTabOpeningStrategyAfterSelected = @"after-selected";
static NSString* const kTabOpeningStrategyChildCluster = @"child-cluster";
static NSString* const kAddressSuggestionsModeLocal = @"local";
static NSString* const kAddressSuggestionsModeGoogle = @"google";
static NSString* const kMarkdownThemeGitHubLight = @"github-light";
static NSString* const kMarkdownThemeGitHubDark = @"github-dark";
static NSString* const kMarkdownThemeReader = @"reader";
static NSString* const kMarkdownThemeCompact = @"compact";
static NSString* const kCompactCommandOpaquePrefix = @"babelchrome:group:";
static NSString* const kCompactCommandHierarchicalPrefix = @"babelchrome://command/group:";
static NSString* const kInternalStartQueryParameter = @"__babelchrome_start";
static NSString* const kInternalRefreshQueryParameter = @"__babelchrome_refresh";
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


#include "BrowserWindowController+SupportViews.inc.mm"
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
  NSMutableArray<BabelClosedTab*>* closedTabs_;
  NSMutableArray<NSDictionary*>* omniboxSuggestions_;
  NSMutableDictionary<NSString*, NSArray<NSString*>*>* googleSuggestCache_;
  BabelExtensionProfileStore* extensionProfileStore_;
  BabelFaviconStore* faviconStore_;
  BabelModuleActionService* moduleActionService_;
  BabelModulePageRenderer* modulePageRenderer_;
  BabelModuleUpdateService* moduleUpdateService_;
  BabelModuleUIActionCoordinator* moduleUIActionCoordinator_;
  NSMutableArray<NSString*>* recentlyUsedTabIdentifiers_;
  NSMutableSet<NSString*>* evictingBrowserTabIdentifiers_;
  NSMutableDictionary<NSNumber*, NSDate*>* pendingLocalDropBrowserIdentifiers_;
  NSMutableDictionary<NSNumber*, NSArray<NSString*>*>* pendingRefreshURLStringsByBrowserIdentifier_;
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
  NSInteger selectedOmniboxSuggestionIndex_;
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
    closedTabs_ = [NSMutableArray array];
    omniboxSuggestions_ = [NSMutableArray array];
    googleSuggestCache_ = [NSMutableDictionary dictionary];
    extensionProfileStore_ =
        [[BabelExtensionProfileStore alloc]
            initWithProfileDirectoryURL:BabelChromeConfiguration.profileDirectoryURL
      profileExtensionBackupDirectoryURL:BabelChromeConfiguration.profileExtensionBackupDirectoryURL
                            userDefaults:NSUserDefaults.standardUserDefaults
               extensionPathsDefaultsKey:BabelChromeConfiguration.extensionPathsDefaultsKey
disabledProfileExtensionIdentifiersDefaultsKey:BabelChromeConfiguration.disabledProfileExtensionIdentifiersDefaultsKey
pendingProfileExtensionRestartStatesDefaultsKey:BabelChromeConfiguration.pendingProfileExtensionRestartStatesDefaultsKey];
    faviconStore_ =
        [[BabelFaviconStore alloc] initWithStoreFileURL:BabelChromeConfiguration.faviconStoreFileURL];
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
    recentlyUsedTabIdentifiers_ = [NSMutableArray array];
    evictingBrowserTabIdentifiers_ = [NSMutableSet set];
    pendingLocalDropBrowserIdentifiers_ = [NSMutableDictionary dictionary];
    pendingRefreshURLStringsByBrowserIdentifier_ = [NSMutableDictionary dictionary];
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
    selectedOmniboxSuggestionIndex_ = -1;
    [extensionProfileStore_ restoreProfileExtensionsMovedByOlderVersions];
    [extensionProfileStore_ clearPendingProfileExtensionRestartStates];
    window.delegate = self;
    [self buildInterface];
    [faviconStore_ restore];
    [self restoreSessionByPriority];
  }
  return self;
}

#include "BrowserWindowController+SessionLifecycle.inc.mm"

#include "BrowserWindowController+InterfaceBuilding.inc.mm"

#include "BrowserWindowController+GroupsSession.inc.mm"

#include "BrowserWindowController+URLOpening.inc.mm"
#include "BrowserWindowController+StableURLRouting.inc.mm"
#include "BrowserWindowController+RuntimeRefreshRouting.inc.mm"
#include "BrowserWindowController+StableViewerDisplay.inc.mm"

#include "BrowserWindowController+TabBrowserCore.inc.mm"

#include "BrowserWindowController+TabDragAndClosed.inc.mm"

#include "BrowserWindowController+LocalDrop.inc.mm"

#include "BrowserWindowController+InternalPageOpeners.inc.mm"
#include "BrowserWindowController+InternalNavigationRouter.inc.mm"
#include "BrowserWindowController+InternalPageLoading.inc.mm"
#include "BrowserWindowController+SettingsPages.inc.mm"
#include "BrowserWindowController+SettingsOptions.inc.mm"
#include "BrowserWindowController+ExtensionActions.inc.mm"
#include "BrowserWindowController+InternalUtilities.inc.mm"

#include "BrowserWindowController+BrowserControls.inc.mm"

#include "BrowserWindowController+SelectionAddressBar.inc.mm"
#include "BrowserWindowController+BrowserAttachment.inc.mm"
#include "BrowserWindowController+DeveloperToolsEmbedding.inc.mm"
#include "BrowserWindowController+BrowserUpdatesAndFavicons.inc.mm"
#include "BrowserWindowController+AddressFieldEditing.inc.mm"
#include "BrowserWindowController+OmniboxSuggestions.inc.mm"

#include "BrowserWindowController+LayoutWindowLifecycle.inc.mm"

@end
