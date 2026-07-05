#import "Browser/BrowserWindowController.h"

#import "Browser/AddressBarDisplayResolver.h"
#import "Browser/AddressFieldLayoutCalculator.h"
#import "Browser/AddressFieldNavigationResolver.h"
#import "Browser/AddressNavigationRequestResolver.h"
#import "Browser/AddressNavigationNormalizer.h"
#import "Browser/AdjacentTabPreloadPlanner.h"
#import "Browser/AppSettingsPageRenderer.h"
#import "Browser/ApplicationRelauncher.h"
#import "Browser/BrowserClient.h"
#import "Browser/BrowserAttachmentCoordinator.h"
#import "Browser/BrowserClosedTabController.h"
#import "Browser/BrowserCreationScheduler.h"
#import "Browser/BrowserGroupCollection.h"
#import "Browser/BrowserGroupFactory.h"
#import "Browser/BrowserGroupManager.h"
#import "Browser/BrowserGroupMoveCoordinator.h"
#import "Browser/BrowserGroupSelectionController.h"
#import "Browser/BrowserPasteboardWriter.h"
#import "Browser/BrowserPageLifecycleController.h"
#import "Browser/BrowserSettingsStore.h"
#import "Browser/BrowserStringFormatter.h"
#import "Browser/BrowserTabCollection.h"
#import "Browser/BrowserTabCreationCoordinator.h"
#import "Browser/BrowserTabDragSessionController.h"
#import "Browser/BrowserTabFactory.h"
#import "Browser/BrowserTabInsertionCoordinator.h"
#import "Browser/BrowserTabLookupService.h"
#import "Browser/BrowserTabMetadataUpdater.h"
#import "Browser/BrowserTabMoveCoordinator.h"
#import "Browser/BrowserThemeApplier.h"
#import "Browser/ChromeCommandParser.h"
#import "Browser/ClosedTabReopenCoordinator.h"
#import "Browser/ClosedTabRestorationPlanner.h"
#import "Browser/DeveloperToolsDockingPolicy.h"
#import "Browser/DeveloperToolsDockingStore.h"
#import "Browser/DeveloperToolsLayoutCalculator.h"
#import "Browser/DeveloperToolsPanelController.h"
#import "Browser/DeveloperToolsTargetResolver.h"
#import "Browser/ExtensionFolderController.h"
#import "Browser/ExtensionProfileStore.h"
#import "Browser/ExtensionsPageDataSource.h"
#import "Browser/ExtensionsPageRenderer.h"
#import "Browser/FaviconStore.h"
#import "Browser/GoogleSuggestClient.h"
#import "Browser/GroupListCoordinator.h"
#import "Browser/GroupRenameController.h"
#import "Browser/GroupSessionStore.h"
#import "Browser/HistoryPageDataSource.h"
#import "Browser/HistoryPageRenderer.h"
#import "Browser/HTMLDataURLBuilder.h"
#import "Browser/GoogleSuggestionScheduler.h"
#import "Browser/InternalNavigationActionParser.h"
#import "Browser/InternalModuleNavigationHandler.h"
#import "Browser/InternalExtensionsNavigationHandler.h"
#import "Browser/InternalPageAssetProvider.h"
#import "Browser/InternalPageHTMLComposer.h"
#import "Browser/InternalPageNavigator.h"
#import "Browser/InternalPageRenderer.h"
#import "Browser/InternalPageTabClassifier.h"
#import "Browser/InternalSettingsNavigationHandler.h"
#import "Browser/LiveBrowserEvictionPolicy.h"
#import "Browser/LiveBrowserLimitEnforcer.h"
#import "Browser/LinkStatusBarController.h"
#import "Browser/LocalDropBridgeScriptBuilder.h"
#import "Browser/BrowserMetadataEventController.h"
#import "Browser/LocalDropCoordinator.h"
#import "Browser/LocalDropLogWriter.h"
#import "Browser/LocalDropPayloadBuilder.h"
#import "Browser/LocalDropSessionController.h"
#import "Browser/LocalDropSupportResolver.h"
#import "Browser/LocalServiceURLClassifier.h"
#import "Browser/MainWindowViewFactory.h"
#import "Browser/ModuleActionService.h"
#import "Browser/ModuleInternalPageHTMLBuilder.h"
#import "Browser/ModuleLifecycleDispatcher.h"
#import "Browser/ModuleNavigationURLResolver.h"
#import "Browser/ModulePageRenderer.h"
#import "Browser/ModuleSettingsPageRenderer.h"
#import "Browser/ModuleSettingsRouteResolver.h"
#import "Browser/ModuleUpdateService.h"
#import "Browser/ModuleUIActionCoordinator.h"
#import "Browser/NewTabURLResolver.h"
#import "Browser/NoViewerPageRenderer.h"
#import "Browser/OmniboxLocalSuggestionBuilder.h"
#import "Browser/OmniboxSuggestionContextBuilder.h"
#import "Browser/OmniboxSuggestionsController.h"
#import "Browser/ProjectLauncherJSONImporter.h"
#import "Browser/ProjectLifecycleResponseParser.h"
#import "Browser/RecentlyClosedTabStore.h"
#import "Browser/RuntimeRefreshCoordinator.h"
#import "Browser/RuntimeRefreshTabMatcher.h"
#import "Browser/SettingsOptionRenderer.h"
#import "Browser/SidebarLayoutCalculator.h"
#import "Browser/StableServerURLResolver.h"
#import "Browser/StableURLTabReloader.h"
#import "Browser/StableViewerURLResolver.h"
#import "Browser/TabContentViewAttacher.h"
#import "Browser/TabDefaultPageResetter.h"
#import "Browser/TabDragCoordinator.h"
#import "Browser/TabDragHoverScheduler.h"
#import "Browser/TabPlacementPolicy.h"
#import "Browser/TabStripLayoutCalculator.h"
#import "Browser/TabURLMatcher.h"
#import "Browser/BrowserModels.h"
#import "Browser/BrowserNavigationController.h"
#import "Browser/BrowserPresentationFormatter.h"
#import "Browser/BrowserSessionRestorationCoordinator.h"
#import "Browser/BrowserSupportViews.h"
#import "Browser/BrowserTheme.h"
#import "Browser/BrowserViews.h"
#import "Browser/ViewerSourceResolver.h"
#import "Browser/ViewerNavigationURLResolver.h"
#import "Browser/ViewerSourceActionHandler.h"
#import "Browser/WindowStateStore.h"
#import "Configuration/Configuration.h"
#import "LocalServices/LocalServiceHost.h"

#include <cmath>
#include <vector>

#include "include/cef_browser.h"
#include "include/cef_app.h"
#include "include/cef_callback.h"
#include "include/wrapper/cef_helpers.h"

#include <string>
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

@interface BabelBrowserWindowController () {

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
  BabelAddressFieldLayoutCalculator* addressFieldLayoutCalculator_;
  BabelAddressFieldNavigationResolver* addressFieldNavigationResolver_;
  BabelAddressNavigationRequestResolver* addressNavigationRequestResolver_;
  BabelAddressNavigationNormalizer* addressNavigationNormalizer_;
  BabelAddressBarDisplayResolver* addressBarDisplayResolver_;
  BabelAdjacentTabPreloadPlanner* adjacentTabPreloadPlanner_;
  BabelAppSettingsPageRenderer* appSettingsPageRenderer_;
  BabelApplicationRelauncher* applicationRelauncher_;
  BabelBrowserAttachmentCoordinator* browserAttachmentCoordinator_;
  BabelBrowserClosedTabController* browserClosedTabController_;
  BabelBrowserCreationScheduler* browserCreationScheduler_;
  BabelBrowserSettingsStore* browserSettingsStore_;
  BabelBrowserTabFactory* browserTabFactory_;
  BabelChromeCommandParser* chromeCommandParser_;
  BabelDeveloperToolsDockingPolicy* developerToolsDockingPolicy_;
  BabelDeveloperToolsDockingStore* developerToolsDockingStore_;
  BabelDeveloperToolsLayoutCalculator* developerToolsLayoutCalculator_;
  BabelDeveloperToolsPanelController* developerToolsPanelController_;
  BabelDeveloperToolsTargetResolver* developerToolsTargetResolver_;
  BabelExtensionFolderController* extensionFolderController_;
  BabelExtensionProfileStore* extensionProfileStore_;
  BabelExtensionsPageDataSource* extensionsPageDataSource_;
  BabelExtensionsPageRenderer* extensionsPageRenderer_;
  BabelFaviconStore* faviconStore_;
  BabelGoogleSuggestClient* googleSuggestClient_;
  BabelGoogleSuggestionScheduler* googleSuggestionScheduler_;
  BabelBrowserGroupCollection* browserGroupCollection_;
  BabelBrowserGroupFactory* browserGroupFactory_;
  BabelBrowserGroupManager* browserGroupManager_;
  BabelBrowserGroupMoveCoordinator* browserGroupMoveCoordinator_;
  BabelBrowserGroupSelectionController* browserGroupSelectionController_;
  BabelBrowserNavigationController* browserNavigationController_;
  BabelBrowserPageLifecycleController* browserPageLifecycleController_;
  BabelBrowserPasteboardWriter* browserPasteboardWriter_;
  BabelBrowserPresentationFormatter* browserPresentationFormatter_;
  BabelBrowserSessionRestorationCoordinator* browserSessionRestorationCoordinator_;
  BabelBrowserTabCollection* browserTabCollection_;
  BabelBrowserTabCreationCoordinator* browserTabCreationCoordinator_;
  BabelBrowserTabDragSessionController* browserTabDragSessionController_;
  BabelBrowserTabInsertionCoordinator* browserTabInsertionCoordinator_;
  BabelBrowserTabLookupService* browserTabLookupService_;
  BabelBrowserTabMetadataUpdater* browserTabMetadataUpdater_;
  BabelBrowserTabMoveCoordinator* browserTabMoveCoordinator_;
  BabelBrowserThemeApplier* browserThemeApplier_;
  BabelBrowserStringFormatter* browserStringFormatter_;
  BabelClosedTabReopenCoordinator* closedTabReopenCoordinator_;
  BabelClosedTabRestorationPlanner* closedTabRestorationPlanner_;
  BabelGroupListCoordinator* groupListCoordinator_;
  BabelGroupRenameController* groupRenameController_;
  BabelGroupSessionStore* groupSessionStore_;
  BabelHistoryPageDataSource* historyPageDataSource_;
  BabelHistoryPageRenderer* historyPageRenderer_;
  BabelHTMLDataURLBuilder* htmlDataURLBuilder_;
  BabelInternalExtensionsNavigationHandler* internalExtensionsNavigationHandler_;
  BabelInternalModuleNavigationHandler* internalModuleNavigationHandler_;
  BabelInternalNavigationActionParser* internalNavigationActionParser_;
  BabelInternalPageAssetProvider* internalPageAssetProvider_;
  BabelInternalPageHTMLComposer* internalPageHTMLComposer_;
  BabelInternalPageNavigator* internalPageNavigator_;
  BabelInternalPageRenderer* internalPageRenderer_;
  BabelInternalPageTabClassifier* internalPageTabClassifier_;
  BabelInternalSettingsNavigationHandler* internalSettingsNavigationHandler_;
  BabelLinkStatusBarController* linkStatusBarController_;
  BabelBrowserMetadataEventController* browserMetadataEventController_;
  BabelLiveBrowserEvictionPolicy* liveBrowserEvictionPolicy_;
  BabelLiveBrowserLimitEnforcer* liveBrowserLimitEnforcer_;
  BabelLocalDropBridgeScriptBuilder* localDropBridgeScriptBuilder_;
  BabelLocalDropCoordinator* localDropCoordinator_;
  BabelLocalDropLogWriter* localDropLogWriter_;
  BabelLocalDropPayloadBuilder* localDropPayloadBuilder_;
  BabelLocalDropSessionController* localDropSessionController_;
  BabelLocalDropSupportResolver* localDropSupportResolver_;
  BabelLocalServiceURLClassifier* localServiceURLClassifier_;
  BabelMainWindowViewFactory* mainWindowViewFactory_;
  BabelModuleActionService* moduleActionService_;
  BabelModuleInternalPageHTMLBuilder* moduleInternalPageHTMLBuilder_;
  BabelModuleLifecycleDispatcher* moduleLifecycleDispatcher_;
  BabelModuleNavigationURLResolver* moduleNavigationURLResolver_;
  BabelModulePageRenderer* modulePageRenderer_;
  BabelModuleSettingsPageRenderer* moduleSettingsPageRenderer_;
  BabelModuleSettingsRouteResolver* moduleSettingsRouteResolver_;
  BabelModuleUpdateService* moduleUpdateService_;
  BabelModuleUIActionCoordinator* moduleUIActionCoordinator_;
  BabelNewTabURLResolver* newTabURLResolver_;
  BabelNoViewerPageRenderer* noViewerPageRenderer_;
  BabelOmniboxLocalSuggestionBuilder* omniboxLocalSuggestionBuilder_;
  BabelOmniboxSuggestionContextBuilder* omniboxSuggestionContextBuilder_;
  BabelOmniboxSuggestionsController* omniboxSuggestionsController_;
  BabelProjectLauncherJSONImporter* projectLauncherJSONImporter_;
  BabelRecentlyClosedTabStore* recentlyClosedTabStore_;
  BabelRuntimeRefreshCoordinator* runtimeRefreshCoordinator_;
  BabelRuntimeRefreshTabMatcher* runtimeRefreshTabMatcher_;
  BabelSettingsOptionRenderer* settingsOptionRenderer_;
  BabelSidebarLayoutCalculator* sidebarLayoutCalculator_;
  BabelStableServerURLResolver* stableServerURLResolver_;
  BabelStableURLTabReloader* stableURLTabReloader_;
  BabelStableViewerURLResolver* stableViewerURLResolver_;
  BabelTabContentViewAttacher* tabContentViewAttacher_;
  BabelTabDefaultPageResetter* tabDefaultPageResetter_;
  BabelTabDragCoordinator* tabDragCoordinator_;
  BabelTabDragHoverScheduler* tabDragHoverScheduler_;
  BabelTabStripLayoutCalculator* tabStripLayoutCalculator_;
  BabelTabURLMatcher* tabURLMatcher_;
  BabelViewerNavigationURLResolver* viewerNavigationURLResolver_;
  BabelViewerSourceActionHandler* viewerSourceActionHandler_;
  BabelViewerSourceResolver* viewerSourceResolver_;
  BabelWindowStateStore* windowStateStore_;
  BabelBrowserGroup* selectedGroup_;
  NSMutableArray<BabelBrowserTab*>* tabs_;
  NSMutableArray<BabelBrowserTab*>* pendingTabs_;
  BabelBrowserTab* selectedTab_;
  BabelBrowserTab* pendingDeveloperToolsTab_;
  CefRefPtr<BabelBrowserClient> browserClient_;
  NSString* developerToolsDockMode_;
  CGFloat developerToolsSizeRatio_;
  CGFloat expandedSidebarWidth_;
  BOOL sidebarCollapsed_;
  BOOL isTerminating_;
  BOOL didRestoreMainWindowState_;
  BOOL isReorderingGroups_;
  BOOL isRestoringSession_;
  BOOL isBuildingInterface_;
  BOOL didApplyInitialSidebarRestore_;
}

- (void)selectTabWithOffset:(NSInteger)offset;

- (void)selectTab:(BabelBrowserTab*)tab;

- (void)selectTab:(BabelBrowserTab*)tab deferringBrowserCreation:(BOOL)deferringBrowserCreation;

- (void)updateWindowTitleForSelectedTab;

- (void)layoutAddressTextFieldContent;

- (void)setAddressBadge:(NSDictionary*)badge;

- (void)openAddressBadgeSettingsFromMenu:(NSMenuItem*)sender;

- (void)updateAddressBarForTab:(BabelBrowserTab*)tab;

- (void)clearAddressBar;

- (void)navigateFromAddressField:(id)sender;

- (void)closeSelectedTab;

- (void)controlTextDidEndEditing:(NSNotification*)notification;

- (void)controlTextDidChange:(NSNotification*)notification;

- (BOOL)control:(NSControl*)control
       textView:(NSTextView*)textView
doCommandBySelector:(SEL)commandSelector;

- (void)updateOmniboxSuggestionsForQuery:(NSString*)query;

- (void)scheduleGoogleSuggestionsForQuery:(NSString*)query;

- (void)appendGoogleSuggestions:(NSArray<NSString*>*)suggestions
                       forQuery:(NSString*)query;

- (void)addOmniboxSuggestionWithTitle:(NSString*)title
                            urlString:(NSString*)urlString
                            groupName:(NSString*)groupName
                        tabIdentifier:(NSString*)tabIdentifier
                                action:(NSString*)action
                              seenKeys:(NSMutableSet<NSString*>*)seenKeys;

- (NSImage*)faviconImageForSuggestionTitle:(NSString*)title urlString:(NSString*)urlString;

- (void)showOmniboxSuggestions;

- (void)hideOmniboxSuggestions;

- (void)selectNextOmniboxSuggestion;

- (void)selectPreviousOmniboxSuggestion;

- (void)selectOmniboxSuggestionFromRow:(BabelOmniboxSuggestionRowView*)row;

- (BOOL)acceptSelectedOmniboxSuggestion;

- (NSString*)compactTitleForString:(NSString*)value;

- (BOOL)shouldPropagateBrowserClose;

- (void)refreshBabelChromeFileTypeCapabilities;

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser title:(NSString*)title;

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser urlString:(NSString*)urlString;

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser statusText:(NSString*)statusText;

- (void)copyURLStringToPasteboard:(NSString*)urlString;

- (void)updateBrowser:(CefRefPtr<CefBrowser>)browser faviconImage:(NSImage*)faviconImage;

- (void)attachCreatedBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)attachCreatedPopupBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)detachClosedBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)removeSelectedGroupTab:(BabelBrowserTab*)tab;

- (void)removeTab:(BabelBrowserTab*)tab;

- (void)removeTab:(BabelBrowserTab*)tab
        fromGroup:(BabelBrowserGroup*)group
   allowSelection:(BOOL)allowSelection;

- (BOOL)isInternalPageTab:(BabelBrowserTab*)tab;

- (void)openDeveloperToolsForSelectedTab;

- (void)openDeveloperToolsForBrowser:(CefRefPtr<CefBrowser>)browser x:(int)x y:(int)y;

- (BOOL)canOpenDeveloperToolsForSelectedTab;

- (BOOL)canOpenDeveloperToolsForBrowser:(CefRefPtr<CefBrowser>)browser;

- (BOOL)canOpenViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)openViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)revealViewerSourceForBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)closeDeveloperToolsFromButton:(NSButton*)sender;

- (void)changeDeveloperToolsDockFromButton:(NSButton*)sender;

- (void)resizeDeveloperToolsFromHandle:(BabelDeveloperToolsResizeHandleView*)sender;

- (void)resizeSidebarFromHandle:(BabelDeveloperToolsResizeHandleView*)sender;

- (void)toggleSidebarCollapsed:(id)sender;

- (BabelBrowserTab*)tabForDeveloperToolsControl:(NSView*)control;

- (NSString*)restoredDeveloperToolsDockMode;

- (CGFloat)restoredDeveloperToolsSizeRatio;

- (BOOL)developerToolsDockModeIsHorizontal;

- (void)navigateSelectedTabBack;

- (void)navigateSelectedTabForward;

- (void)reloadSelectedTab;

- (void)reloadSelectedTabFromButton:(id)sender;

- (void)reloadSelectedTabIgnoringCache;

- (void)reloadSelectedTabIgnoringCache:(BOOL)ignoringCache;

- (void)reloadMarkdownViewerTabsUsingCurrentTheme;

- (void)loadDeveloperToolsForTab:(BabelBrowserTab*)tab
                inspectingBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)createDeveloperToolsBrowserForTab:(BabelBrowserTab*)tab
                                urlString:(NSString*)urlString;

- (void)hideDeveloperToolsForTab:(BabelBrowserTab*)tab;

- (void)closeDeveloperToolsForTab:(BabelBrowserTab*)tab;

- (void)reparentDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              intoTab:(BabelBrowserTab*)tab;

- (void)layoutBrowserViewsForTab:(BabelBrowserTab*)tab;

- (void)restoreSessionGroupsFromState:(NSDictionary*)state;

- (void)restoreGroupsFromState:(NSDictionary*)state;

- (BabelBrowserGroup*)createGroupWithName:(NSString*)name identifier:(NSString*)identifier;

- (BabelBrowserGroup*)groupWithIdentifier:(NSString*)identifier;

- (BabelBrowserGroup*)groupWithName:(NSString*)name;

- (BabelBrowserGroup*)ensureGroupNamed:(NSString*)name;

- (BabelBrowserGroup*)targetGroupForModuleIdentifier:(NSString*)moduleIdentifier
                                      fallbackGroup:(BabelBrowserGroup*)fallbackGroup;

- (NSString*)nextManualGroupName;

- (void)addGroupFromButton:(id)sender;

- (void)selectGroupFromItem:(BabelGroupItemView*)groupItemView;

- (void)dragGroupFromItem:(BabelGroupItemView*)groupItemView;

- (NSUInteger)groupInsertionIndexForListY:(CGFloat)y;

- (void)finishDraggingGroupFromItem:(BabelGroupItemView*)groupItemView;

- (void)selectGroup:(BabelBrowserGroup*)group;

- (void)deleteGroupFromMenu:(NSMenuItem*)menuItem;

- (void)renameGroupFromMenu:(NSMenuItem*)menuItem;

- (BabelBrowserGroup*)groupToSelectAfterDeletingGroupAtIndex:(NSUInteger)groupIndex;

- (void)deleteGroup:(BabelBrowserGroup*)group selectingGroup:(BabelBrowserGroup*)nextGroup;

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier inGroup:(BabelBrowserGroup*)group;

- (BabelBrowserTab*)tabWithURLString:(NSString*)urlString inGroup:(BabelBrowserGroup*)group;

- (void)saveGroupsState;

- (void)showMainWindow;

- (BabelBrowserTab*)makeTabForURL:(NSString*)urlString
                        identifier:(NSString*)identifier
                             title:(NSString*)title;

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString inGroup:(BabelBrowserGroup*)group;

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab;

- (BabelBrowserTab*)createTabForURL:(NSString*)urlString
                inGroup:(BabelBrowserGroup*)group
              parentTab:(BabelBrowserTab*)parentTab
   respectingUserStrategy:(BOOL)respectingUserStrategy;

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab;

- (void)insertTab:(BabelBrowserTab*)tab
          inGroup:(BabelBrowserGroup*)group
        parentTab:(BabelBrowserTab*)parentTab
 respectingUserStrategy:(BOOL)respectingUserStrategy;

- (NSString*)tabOpeningStrategy;

- (NSString*)addressSuggestionsMode;

- (NSString*)markdownTheme;

- (BOOL)googleSuggestEnabled;

- (void)createBrowserForTabIfNeeded:(BabelBrowserTab*)tab;

- (void)scheduleBrowserCreationAfterKeyboardNavigationForTab:(BabelBrowserTab*)tab;

- (void)createInitialRestoredBrowserIfNeeded;

- (void)scheduleAdjacentTabPreloadForSelectedTab;

- (NSArray<BabelBrowserTab*>*)adjacentTabsToPreloadAroundTab:(BabelBrowserTab*)tab;

- (void)touchRecentlyUsedTab:(BabelBrowserTab*)tab;

- (void)closeBrowserForTabKeepingNativeTab:(BabelBrowserTab*)tab;

- (void)enforceLivePageBrowserLimit;

- (void)selectTabFromItem:(BabelTabItemView*)tabItemView;

- (void)dragTabFromItem:(BabelTabItemView*)tabItemView;

- (BabelBrowserTab*)tabWithIdentifier:(NSString*)identifier;

- (BabelBrowserGroup*)groupContainingTab:(BabelBrowserTab*)tab;

- (void)finishDraggingTabFromItem:(BabelTabItemView*)tabItemView;

- (void)closeTabFromItem:(BabelTabItemView*)tabItemView;

- (void)reopenLastClosedTab;

- (void)reopenClosedTabAtIndex:(NSUInteger)closedTabIndex;

- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab;

- (void)selectNextTab;

- (void)selectPreviousTab;

- (void)openURLStringInNewTab:(NSString*)urlString;

- (void)openURLStringInNewTab:(NSString*)urlString openerBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)openHistoryPage;

- (void)openSettingsPage;

- (void)openSettingsPageForBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)openModuleSettingsPageForIdentifier:(NSString*)moduleIdentifier;

- (void)openModuleSettingsPageForIdentifier:(NSString*)moduleIdentifier browser:(CefRefPtr<CefBrowser>)browser;

- (void)openExtensionsPage;

- (void)openExtensionsPageForBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)openModulesPage;

- (void)openModulesPageForBrowser:(CefRefPtr<CefBrowser>)browser;

- (NSString*)modulesPageHTML;

- (NSString*)moduleDetailsPageHTMLForIdentifier:(NSString*)moduleIdentifier;

- (NSString*)moduleUpdatesPageHTML;

- (void)openPHPModuleWithIdentifier:(NSString*)moduleIdentifier route:(NSString*)route;

- (void)openPHPModuleWithIdentifier:(NSString*)moduleIdentifier
                              route:(NSString*)route
                    sourceURLString:(NSString*)sourceURLString
                 requestedURLString:(NSString*)requestedURLString;

- (BOOL)openPHPModuleURLString:(NSString*)urlString;

- (void)importProjectLauncherJSONFromPanel;

- (BOOL)handleInternalNavigationURLString:(NSString*)urlString;

- (BOOL)navigateBrowser:(CefRefPtr<CefBrowser>)browser toInternalURLStringInSameTab:(NSString*)urlString;

- (BOOL)handleInternalNavigationURLString:(NSString*)urlString browser:(CefRefPtr<CefBrowser>)browser;

- (void)navigateSelectedTabToViewerURLString:(NSString*)urlString;

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html;

- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html
                              browser:(CefRefPtr<CefBrowser>)browser;

- (NSString*)dataURLStringForHTML:(NSString*)html;

- (NSString*)historyPageHTML;

- (NSString*)settingsPageHTML;

- (NSString*)moduleSettingsPageHTMLForIdentifier:(NSString*)moduleIdentifier;

- (NSString*)extensionsPageHTML;

- (void)openChromeWebStoreSearchForQuery:(NSString*)query;

- (void)showLocalServiceStartupAlert:(NSError*)error;

- (NSString*)queryEscapedString:(NSString*)value;

- (NSString*)pathEscapedString:(NSString*)value;

- (NSString*)trashIconHTML;

- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML;

- (void)restartApplication;

- (NSString*)internalPageHTMLWithTitle:(NSString*)title body:(NSString*)body;

- (void)browser:(CefRefPtr<CefBrowser>)browser didReceiveLocalDragPaths:(NSArray<NSString*>*)paths;

- (BOOL)pageContainerSupportsLocalDrop:(BabelPageContainerView*)container;

- (void)pageContainerDidReceiveLocalDrop:(BabelPageContainerView*)container;

- (void)browserDidFinishLoading:(CefRefPtr<CefBrowser>)browser;

- (BOOL)shouldSuppressLocalFileNavigationForBrowser:(CefRefPtr<CefBrowser>)browser;

- (void)appendLocalDropLogLine:(NSString*)line;

- (BOOL)tabSupportsLocalDropPaths:(BabelBrowserTab*)tab;

- (BOOL)URLStringSupportsLocalDropPaths:(NSString*)urlString;

- (void)openURLs:(NSArray<NSURL*>*)urls;

- (void)openNewTab;

- (void)openAdjacentNewTab;

- (void)openNewTabFromButton:(id)sender;

- (void)scheduleQueuedURLOpening;

- (void)drainQueuedURLOpening;

- (void)openURL:(NSURL*)url;

- (void)openBabelChromeCommandURL:(NSURL*)url;

- (BOOL)openCompactBabelChromeCommandString:(NSString*)urlString;

- (void)openURLString:(NSString*)urlString groupName:(NSString*)groupName;

- (NSString*)viewerURLStringForSupportedURLString:(NSString*)urlString;

- (NSString*)noViewerInstalledPageURLStringForStableViewerURLString:(NSString*)urlString;

- (NSString*)stableViewerURLStringForSupportedURLString:(NSString*)urlString;

- (NSString*)navigationURLStringForStableBabelChromeURLString:(NSString*)urlString;

- (BOOL)isStableBabelChromeURLString:(NSString*)urlString;

- (BOOL)isStableServerURLString:(NSString*)urlString;

- (BOOL)stableServerURLStringRequestsStart:(NSString*)urlString;

- (NSArray<NSString*>*)refreshURLStringsForStableURLString:(NSString*)urlString;

- (NSString*)stableURLStringByRemovingInternalQueryParameters:(NSString*)urlString;

- (NSString*)stableServerProjectPathForURLComponents:(NSURLComponents*)components;

- (NSString*)stableServerReloadURLStringForTab:(BabelBrowserTab*)tab;

- (NSString*)moduleNavigationURLStringForStableBabelChromeURLString:(NSString*)urlString;

- (BabelBrowserTab*)tabForBrowser:(CefRefPtr<CefBrowser>)browser;

- (BOOL)isLocalServiceModuleURLString:(NSString*)urlString;

- (BOOL)isLocalServiceRuntimeURLString:(NSString*)urlString;

- (BOOL)isProjectLauncherModuleURLString:(NSString*)urlString;

- (BOOL)tab:(BabelBrowserTab*)tab matchesRefreshURLString:(NSString*)requestedURLString;

- (void)reloadTabsWithRequestedURLString:(NSString*)requestedURLString excludingTab:(BabelBrowserTab*)excludedTab;

- (void)reloadRequestedURLStrings:(NSArray<NSString*>*)requestedURLStrings excludingTab:(BabelBrowserTab*)excludedTab;

- (NSString*)serverProjectIdentifierForStableURLString:(NSString*)urlString;

- (void)reloadServerTabsWithProjectIdentifiers:(NSArray<NSString*>*)projectIdentifiers;

- (void)restoreSessionByPriority;

- (void)restoreSessionPositionState;

- (void)restoreSessionWindowFrame;

- (void)restoreSessionWindowZoom;

- (void)restoreSessionSidebarCollapsedState;

- (void)restoreSessionSidebarExpandedWidth;

- (void)restoreSessionSidebarState;

- (void)applySessionSidebarDividerPosition;

- (void)restoreSessionSidebarAfterInitialLayout;

- (void)restoreSessionInitialBrowsers;

- (void)restoreSessionModulesLifecycle;

- (void)maximizeWindowToVisibleFrame:(id)sender;

- (void)dispatchApplicationDidStartModuleLifecycleHook;

- (void)dispatchApplicationWillQuitModuleLifecycleHook;

- (void)buildInterface;

- (void)layoutTabItemsSelectingLastTab:(BOOL)selectLastTab;

- (NSColor*)accentColorForGroup:(BabelBrowserGroup*)group;

- (void)layoutGroupItems;

- (NSUInteger)totalTabCount;

- (CGFloat)sidebarWidth;

- (CGFloat)restoredExpandedSidebarWidth;

- (CGFloat)normalizedExpandedSidebarWidth:(CGFloat)width;

- (void)saveExpandedSidebarWidth:(CGFloat)width;

- (CGFloat)minimumExpandedSidebarWidth;

- (CGFloat)sidebarTitleWidth;

- (CGFloat)targetSidebarWidth;

- (void)restoreMainWindowFrame;

- (void)restoreMainWindowZoomStateIfNeeded;

- (void)saveMainWindowState;

- (void)applyThemeColors;

- (void)layoutInterfaceForCurrentSplitViewSize;

- (void)requestApplicationTermination;

- (void)windowDidResize:(NSNotification*)notification;

- (void)windowDidMove:(NSNotification*)notification;

- (void)closeAllBrowsersForTermination;

- (BOOL)windowShouldClose:(NSWindow*)sender;

@end
