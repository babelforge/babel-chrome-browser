#import "Browser/Window/Controller/BrowserWindowController.h"

#import "Browser/Address/Bar/AddressBarDisplayResolver.h"
#import "Browser/Address/Bar/AddressFieldLayoutCalculator.h"
#import "Browser/Address/Bar/AddressFieldNavigationResolver.h"
#import "Browser/Address/Bar/AddressNavigationRequestResolver.h"
#import "Browser/Address/Bar/AddressNavigationNormalizer.h"
#import "Browser/Tabs/Selection/AdjacentTabPreloadPlanner.h"
#import "Browser/InternalPages/Settings/AppSettingsPageRenderer.h"
#import "Browser/Utilities/Application/ApplicationRelauncher.h"
#import "Browser/CEF/Client/BrowserClient.h"
#import "Browser/CEF/Attachment/BrowserAttachmentCoordinator.h"
#import "Browser/Tabs/Closing/BrowserClosedTabController.h"
#import "Browser/Tabs/Creation/BrowserCreationScheduler.h"
#import "Browser/Groups/Model/BrowserGroupCollection.h"
#import "Browser/Groups/Creation/BrowserGroupFactory.h"
#import "Browser/Groups/Management/BrowserGroupManager.h"
#import "Browser/Groups/Management/BrowserGroupMoveCoordinator.h"
#import "Browser/Groups/Management/BrowserGroupSelectionController.h"
#import "Browser/UI/Pasteboard/BrowserPasteboardWriter.h"
#import "Browser/Tabs/Selection/BrowserPageLifecycleController.h"
#import "Browser/State/Settings/BrowserSettingsStore.h"
#import "Browser/UI/Formatting/BrowserStringFormatter.h"
#import "Browser/Tabs/Model/BrowserTabCollection.h"
#import "Browser/Tabs/Creation/BrowserTabCreationCoordinator.h"
#import "Browser/Tabs/Movement/BrowserTabDragSessionController.h"
#import "Browser/Tabs/Creation/BrowserTabFactory.h"
#import "Browser/Tabs/Creation/BrowserTabInsertionCoordinator.h"
#import "Browser/Tabs/Model/BrowserTabLookupService.h"
#import "Browser/Tabs/Model/BrowserTabMetadataUpdater.h"
#import "Browser/Tabs/Movement/BrowserTabMoveCoordinator.h"
#import "Browser/UI/Theme/BrowserThemeApplier.h"
#import "Browser/Navigation/Commands/ChromeCommandParser.h"
#import "Browser/Tabs/Closing/ClosedTabReopenCoordinator.h"
#import "Browser/Tabs/Closing/ClosedTabRestorationPlanner.h"
#import "Browser/DeveloperTools/Docking/DeveloperToolsDockingPolicy.h"
#import "Browser/DeveloperTools/Docking/DeveloperToolsDockingStore.h"
#import "Browser/DeveloperTools/Layout/DeveloperToolsLayoutCalculator.h"
#import "Browser/DeveloperTools/Panel/DeveloperToolsPanelController.h"
#import "Browser/DeveloperTools/Targeting/DeveloperToolsTargetResolver.h"
#import "Browser/Extensions/Install/ExtensionFolderController.h"
#import "Browser/Extensions/Profile/ExtensionProfileStore.h"
#import "Browser/InternalPages/Extensions/ExtensionsPageDataSource.h"
#import "Browser/InternalPages/Extensions/ExtensionsPageRenderer.h"
#import "Browser/State/Favicons/FaviconStore.h"
#import "Browser/Address/Suggestions/GoogleSuggestClient.h"
#import "Browser/Groups/UI/GroupListCoordinator.h"
#import "Browser/Groups/UI/GroupRenameController.h"
#import "Browser/State/Sessions/GroupSessionStore.h"
#import "Browser/InternalPages/History/HistoryPageDataSource.h"
#import "Browser/InternalPages/History/HistoryPageRenderer.h"
#import "Browser/Utilities/HTML/HTMLDataURLBuilder.h"
#import "Browser/Address/Suggestions/GoogleSuggestionScheduler.h"
#import "Browser/InternalPages/Navigation/InternalNavigationActionParser.h"
#import "Browser/InternalPages/Navigation/InternalModuleNavigationHandler.h"
#import "Browser/InternalPages/Navigation/InternalExtensionsNavigationHandler.h"
#import "Browser/InternalPages/Rendering/InternalPageAssetProvider.h"
#import "Browser/InternalPages/Rendering/InternalPageHTMLComposer.h"
#import "Browser/InternalPages/Navigation/InternalPageNavigator.h"
#import "Browser/InternalPages/Rendering/InternalPageRenderer.h"
#import "Browser/InternalPages/Navigation/InternalPageTabClassifier.h"
#import "Browser/InternalPages/Navigation/InternalSettingsNavigationHandler.h"
#import "Browser/Tabs/Lifecycle/LiveBrowserEvictionPolicy.h"
#import "Browser/Tabs/Lifecycle/LiveBrowserLimitEnforcer.h"
#import "Browser/Address/Status/LinkStatusBarController.h"
#import "Browser/DragDrop/Bridge/LocalDropBridgeScriptBuilder.h"
#import "Browser/CEF/Events/BrowserMetadataEventController.h"
#import "Browser/DragDrop/Session/LocalDropCoordinator.h"
#import "Browser/DragDrop/Logging/LocalDropLogWriter.h"
#import "Browser/DragDrop/Payload/LocalDropPayloadBuilder.h"
#import "Browser/DragDrop/Session/LocalDropSessionController.h"
#import "Browser/DragDrop/Session/LocalDropSupportResolver.h"
#import "Browser/Navigation/StableURLs/LocalServiceURLClassifier.h"
#import "Browser/Window/Layout/MainWindowViewFactory.h"
#import "Browser/Modules/Core/ModuleActionService.h"
#import "Browser/InternalPages/Modules/ModuleInternalPageHTMLBuilder.h"
#import "Browser/Modules/Lifecycle/ModuleLifecycleDispatcher.h"
#import "Browser/Modules/Navigation/ModuleNavigationURLResolver.h"
#import "Browser/Modules/Navigation/RestoredTabModuleDependencyResolver.h"
#import "Browser/InternalPages/Modules/ModulePageRenderer.h"
#import "Browser/InternalPages/Modules/ModuleSettingsPageRenderer.h"
#import "Browser/Modules/Navigation/ModuleSettingsRouteResolver.h"
#import "Browser/Modules/Updates/ModuleUpdateService.h"
#import "Browser/Modules/Navigation/ModuleUIActionCoordinator.h"
#import "Browser/Tabs/Creation/NewTabURLResolver.h"
#import "Browser/InternalPages/Rendering/NoViewerPageRenderer.h"
#import "Browser/Address/Suggestions/OmniboxLocalSuggestionBuilder.h"
#import "Browser/Address/Suggestions/OmniboxSuggestionContextBuilder.h"
#import "Browser/Address/Suggestions/OmniboxSuggestionsController.h"
#import "Browser/Modules/Projects/ProjectLauncherJSONImporter.h"
#import "Browser/Modules/Lifecycle/ProjectLifecycleResponseParser.h"
#import "Browser/Tabs/Closing/RecentlyClosedTabStore.h"
#import "Browser/Navigation/Refresh/RuntimeRefreshCoordinator.h"
#import "Browser/Navigation/Refresh/RuntimeRefreshTabMatcher.h"
#import "Browser/InternalPages/Rendering/SettingsOptionRenderer.h"
#import "Browser/Window/Layout/SidebarLayoutCalculator.h"
#import "Browser/Navigation/StableURLs/StableServerURLResolver.h"
#import "Browser/Navigation/StableURLs/StableURLTabReloader.h"
#import "Browser/Navigation/StableURLs/StableViewerURLResolver.h"
#import "Browser/Tabs/UI/TabContentViewAttacher.h"
#import "Browser/Tabs/Closing/TabDefaultPageResetter.h"
#import "Browser/Tabs/Movement/TabDragCoordinator.h"
#import "Browser/Tabs/Movement/TabDragHoverScheduler.h"
#import "Browser/Tabs/Creation/TabPlacementPolicy.h"
#import "Browser/Tabs/UI/TabStripLayoutCalculator.h"
#import "Browser/Tabs/UI/TabURLMatcher.h"
#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/Navigation/Browser/BrowserNavigationController.h"
#import "Browser/UI/Formatting/BrowserPresentationFormatter.h"
#import "Browser/Tabs/Lifecycle/BrowserSessionRestorationCoordinator.h"
#import "Browser/UI/Views/BrowserSupportViews.h"
#import "Browser/UI/Theme/BrowserTheme.h"
#import "Browser/UI/Views/BrowserViews.h"
#import "Browser/Navigation/Viewer/ViewerSourceResolver.h"
#import "Browser/Navigation/Viewer/ViewerNavigationURLResolver.h"
#import "Browser/Navigation/Viewer/ViewerSourceActionHandler.h"
#import "Browser/State/Sessions/WindowStateStore.h"
#import "Configuration/Configuration.h"

#include <cmath>
#include <vector>

#include "include/cef_browser.h"
#include "include/cef_app.h"
#include "include/cef_callback.h"
#include "include/wrapper/cef_helpers.h"

@class BabelBrowserWindowAddressAndSuggestionsActions;
@class BabelBrowserWindowBrowserAttachmentActions;
@class BabelBrowserWindowBrowserControlsActions;
@class BabelBrowserWindowDeveloperToolsActions;
@class BabelBrowserWindowGroupsAndTabsActions;
@class BabelBrowserWindowInternalPagesActions;
@class BabelBrowserWindowLifecycleActions;
@class BabelBrowserWindowLocalDropActions;
@class BabelBrowserWindowURLRoutingActions;

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
 @public
  BabelBrowserWindowAddressAndSuggestionsActions* addressAndSuggestionsActions_;
  BabelBrowserWindowBrowserAttachmentActions* browserAttachmentActions_;
  BabelBrowserWindowBrowserControlsActions* browserControlsActions_;
  BabelBrowserWindowDeveloperToolsActions* developerToolsActions_;
  BabelBrowserWindowGroupsAndTabsActions* groupsAndTabsActions_;
  BabelBrowserWindowInternalPagesActions* internalPagesActions_;
  BabelBrowserWindowLifecycleActions* lifecycleActions_;
  BabelBrowserWindowLocalDropActions* localDropActions_;
  BabelBrowserWindowURLRoutingActions* urlRoutingActions_;

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
  BabelRestoredTabModuleDependencyResolver* restoredTabModuleDependencyResolver_;
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

- (void)reloadBrowser:(CefRefPtr<CefBrowser>)browser ignoringCache:(BOOL)ignoringCache;

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

- (NSString*)prewarmSelectedRestoredTabRuntimeIfNeeded;

- (void)scheduleBackgroundModulePrewarmExcludingIdentifiers:(NSSet<NSString*>*)excludedIdentifiers;

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
