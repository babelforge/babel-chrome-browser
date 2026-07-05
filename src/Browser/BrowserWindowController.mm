#import "Browser/BrowserWindowController+Private.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation BabelBrowserWindowController

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
    addressFieldLayoutCalculator_ = [[BabelAddressFieldLayoutCalculator alloc] init];
    addressFieldNavigationResolver_ = [[BabelAddressFieldNavigationResolver alloc] init];
    adjacentTabPreloadPlanner_ = [[BabelAdjacentTabPreloadPlanner alloc] init];
    applicationRelauncher_ = [[BabelApplicationRelauncher alloc] init];
    browserCreationScheduler_ = [[BabelBrowserCreationScheduler alloc] init];
    browserSettingsStore_ =
        [[BabelBrowserSettingsStore alloc] initWithUserDefaults:NSUserDefaults.standardUserDefaults];
    chromeCommandParser_ =
        [[BabelChromeCommandParser alloc] initWithDefaultGroupName:kDefaultGroupName
                                                  defaultURLString:BabelChromeConfiguration.defaultURLString];
    __weak BabelBrowserWindowController* weakSelf = self;
    addressNavigationNormalizer_ = [[BabelAddressNavigationNormalizer alloc] init];
    closedTabRestorationPlanner_ =
        [[BabelClosedTabRestorationPlanner alloc]
            initWithDefaultGroupName:kDefaultGroupName
             stableNavigationURLResolver:^NSString*(NSString* urlString) {
               return [weakSelf navigationURLStringForStableBabelChromeURLString:urlString];
             }];
    tabDefaultPageResetter_ =
        [[BabelTabDefaultPageResetter alloc]
            initWithDefaultURLString:BabelChromeConfiguration.defaultURLString
                   compactTitleBlock:^NSString*(NSString* title) {
                     BabelBrowserWindowController* strongSelf = weakSelf;
                     return strongSelf ? [strongSelf compactTitleForString:title] : title;
                   }];
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
    developerToolsTargetResolver_ = [[BabelDeveloperToolsTargetResolver alloc] init];
    developerToolsPanelController_ =
        [[BabelDeveloperToolsPanelController alloc]
            initWithTargetResolver:developerToolsTargetResolver_
                  layoutCalculator:developerToolsLayoutCalculator_
                browserLookupBlock:^BabelBrowserTab*(CefRefPtr<CefBrowser> browser) {
                  return [weakSelf tabForBrowser:browser];
                }
                createBrowserBlock:^(BabelBrowserTab* tab, NSString* urlString) {
                  [weakSelf createDeveloperToolsBrowserForTab:tab urlString:urlString];
                }
                     toolbarHeight:kDeveloperToolsToolbarHeight
             resizeHandleThickness:kDeveloperToolsResizeHandleThickness];
    extensionProfileStore_ =
        [[BabelExtensionProfileStore alloc]
            initWithProfileDirectoryURL:BabelChromeConfiguration.profileDirectoryURL
      profileExtensionBackupDirectoryURL:BabelChromeConfiguration.profileExtensionBackupDirectoryURL
                            userDefaults:NSUserDefaults.standardUserDefaults
               extensionPathsDefaultsKey:BabelChromeConfiguration.extensionPathsDefaultsKey
disabledProfileExtensionIdentifiersDefaultsKey:BabelChromeConfiguration.disabledProfileExtensionIdentifiersDefaultsKey
pendingProfileExtensionRestartStatesDefaultsKey:BabelChromeConfiguration.pendingProfileExtensionRestartStatesDefaultsKey];
    extensionFolderController_ =
        [[BabelExtensionFolderController alloc] initWithExtensionProfileStore:extensionProfileStore_];
    extensionsPageRenderer_ =
        [[BabelExtensionsPageRenderer alloc] initWithTrashIconHTML:[self trashIconHTML]];
    extensionsPageDataSource_ =
        [[BabelExtensionsPageDataSource alloc] initWithExtensionProfileStore:extensionProfileStore_];
    faviconStore_ =
        [[BabelFaviconStore alloc] initWithStoreFileURL:BabelChromeConfiguration.faviconStoreFileURL];
    browserTabFactory_ =
        [[BabelBrowserTabFactory alloc]
            initWithFaviconStore:faviconStore_
                    actionTarget:self
               compactTitleBlock:^NSString*(NSString* title) {
                 BabelBrowserWindowController* strongSelf = weakSelf;
                 return [strongSelf->browserPresentationFormatter_ compactTitleForString:title];
               }
        localDropAcceptanceBlock:^BOOL(BabelPageContainerView* container) {
          return [weakSelf pageContainerSupportsLocalDrop:container];
        }
            localDropHandlerBlock:^(BabelPageContainerView* container) {
              [weakSelf pageContainerDidReceiveLocalDrop:container];
            }];
    googleSuggestClient_ = [[BabelGoogleSuggestClient alloc] init];
    googleSuggestionScheduler_ =
        [[BabelGoogleSuggestionScheduler alloc] initWithGoogleSuggestClient:googleSuggestClient_];
    browserGroupCollection_ = [[BabelBrowserGroupCollection alloc] init];
    browserGroupFactory_ = [[BabelBrowserGroupFactory alloc] initWithActionTarget:self];
    browserGroupMoveCoordinator_ = [[BabelBrowserGroupMoveCoordinator alloc] init];
    browserNavigationController_ = [[BabelBrowserNavigationController alloc] init];
    browserPasteboardWriter_ = [[BabelBrowserPasteboardWriter alloc] init];
    browserPresentationFormatter_ = [[BabelBrowserPresentationFormatter alloc] init];
    browserTabCollection_ = [[BabelBrowserTabCollection alloc] init];
    browserTabMetadataUpdater_ = [[BabelBrowserTabMetadataUpdater alloc] init];
    browserThemeApplier_ = [[BabelBrowserThemeApplier alloc] init];
    browserStringFormatter_ = [[BabelBrowserStringFormatter alloc] init];
    BabelTabPlacementPolicy* tabPlacementPolicy = [[BabelTabPlacementPolicy alloc] init];
    browserTabInsertionCoordinator_ =
        [[BabelBrowserTabInsertionCoordinator alloc] initWithPlacementPolicy:tabPlacementPolicy
                                                               tabCollection:browserTabCollection_];
    browserTabLookupService_ = [[BabelBrowserTabLookupService alloc] init];
    groupListCoordinator_ = [[BabelGroupListCoordinator alloc] init];
    groupRenameController_ = [[BabelGroupRenameController alloc] init];
    groupSessionStore_ = [[BabelGroupSessionStore alloc] init];
    historyPageRenderer_ = [[BabelHistoryPageRenderer alloc] init];
    htmlDataURLBuilder_ = [[BabelHTMLDataURLBuilder alloc] init];
    internalNavigationActionParser_ = [[BabelInternalNavigationActionParser alloc] init];
    internalExtensionsNavigationHandler_ =
        [[BabelInternalExtensionsNavigationHandler alloc]
                  initWithActionParser:internalNavigationActionParser_
             extensionFolderController:extensionFolderController_
                  extensionProfileStore:extensionProfileStore_];
    internalPageAssetProvider_ = [[BabelInternalPageAssetProvider alloc] init];
    internalPageRenderer_ = [[BabelInternalPageRenderer alloc] init];
    internalPageTabClassifier_ =
        [[BabelInternalPageTabClassifier alloc]
            initWithInternalPageURLStrings:@[
              kHistoryPageURLString,
              kSettingsPageURLString,
              kExtensionsPageURLString,
              kModulesPageURLString
            ]];
    internalSettingsNavigationHandler_ =
        [[BabelInternalSettingsNavigationHandler alloc] initWithSettingsStore:browserSettingsStore_
                                                                 userDefaults:NSUserDefaults.standardUserDefaults];
    linkStatusBarController_ = [[BabelLinkStatusBarController alloc] init];
    liveBrowserEvictionPolicy_ = [[BabelLiveBrowserEvictionPolicy alloc] init];
    liveBrowserLimitEnforcer_ =
        [[BabelLiveBrowserLimitEnforcer alloc]
            initWithAdjacentTabPreloadPlanner:adjacentTabPreloadPlanner_
                    liveBrowserEvictionPolicy:liveBrowserEvictionPolicy_
                      maximumLivePageBrowsers:kMaximumLivePageBrowsers];
    browserAttachmentCoordinator_ =
        [[BabelBrowserAttachmentCoordinator alloc]
            initWithGroups:groups_
               pendingTabs:pendingTabs_
            evictionPolicy:liveBrowserEvictionPolicy_
        selectGroupHandler:^(BabelBrowserGroup* group) {
          [weakSelf selectGroup:group];
        }
          removeTabHandler:^(BabelBrowserTab* tab) {
            [weakSelf removeTab:tab];
          }
  hideDeveloperToolsHandler:^(BabelBrowserTab* tab) {
    [weakSelf hideDeveloperToolsForTab:tab];
  }
layoutDeveloperToolsHandler:^(BabelBrowserTab* tab) {
  [weakSelf layoutBrowserViewsForTab:tab];
}
enforceLiveBrowserLimitHandler:^{
  [weakSelf enforceLivePageBrowserLimit];
}
     totalTabCountProvider:^NSUInteger{
       return [weakSelf totalTabCount];
     }];
    localDropBridgeScriptBuilder_ = [[BabelLocalDropBridgeScriptBuilder alloc] init];
    localDropCoordinator_ = [[BabelLocalDropCoordinator alloc] init];
    localDropLogWriter_ =
        [[BabelLocalDropLogWriter alloc]
            initWithLogURL:[BabelChromeConfiguration.applicationSupportDirectoryURL
                               URLByAppendingPathComponent:@"local-drop.log"
                                               isDirectory:NO]];
    localDropPayloadBuilder_ = [[BabelLocalDropPayloadBuilder alloc] init];
    localServiceURLClassifier_ = [[BabelLocalServiceURLClassifier alloc] init];
    mainWindowViewFactory_ = [[BabelMainWindowViewFactory alloc] init];
    moduleActionService_ = [[BabelModuleActionService alloc] init];
    moduleNavigationURLResolver_ =
        [[BabelModuleNavigationURLResolver alloc] initWithModuleActionService:moduleActionService_];
    localDropSupportResolver_ =
        [[BabelLocalDropSupportResolver alloc] initWithModuleActionService:moduleActionService_];
    localDropSessionController_ =
        [[BabelLocalDropSessionController alloc]
            initWithCoordinator:localDropCoordinator_
            bridgeScriptBuilder:localDropBridgeScriptBuilder_
                      logWriter:localDropLogWriter_
                 payloadBuilder:localDropPayloadBuilder_
                supportResolver:localDropSupportResolver_
             browserTabProvider:^BabelBrowserTab*(CefRefPtr<CefBrowser> browser) {
               return [weakSelf tabForBrowser:browser];
             }
             currentURLProvider:^NSString*(CefRefPtr<CefBrowser> browser) {
               if (!browser || !browser->GetMainFrame()) {
                 return @"";
               }
               return [NSString stringWithUTF8String:browser->GetMainFrame()->GetURL().ToString().c_str()];
             }];
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
    moduleInternalPageHTMLBuilder_ =
        [[BabelModuleInternalPageHTMLBuilder alloc] initWithModuleActionService:moduleActionService_
                                                             modulePageRenderer:modulePageRenderer_
                                                            moduleUpdateService:moduleUpdateService_
                                                           internalPageRenderer:internalPageRenderer_];
    moduleUIActionCoordinator_ =
        [[BabelModuleUIActionCoordinator alloc] initWithModuleActionService:moduleActionService_
                                                        moduleUpdateService:moduleUpdateService_];
    internalModuleNavigationHandler_ =
        [[BabelInternalModuleNavigationHandler alloc]
            initWithModuleUIActionCoordinator:moduleUIActionCoordinator_];
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
    noViewerPageRenderer_ = [[BabelNoViewerPageRenderer alloc] init];
    omniboxLocalSuggestionBuilder_ = [[BabelOmniboxLocalSuggestionBuilder alloc] init];
    omniboxSuggestionContextBuilder_ = [[BabelOmniboxSuggestionContextBuilder alloc] init];
    projectLauncherJSONImporter_ =
        [[BabelProjectLauncherJSONImporter alloc] initWithLogHandler:^(NSString* line) {
          [weakSelf appendLocalDropLogLine:line];
        }];
    BabelProjectLifecycleResponseParser* projectLifecycleResponseParser =
        [[BabelProjectLifecycleResponseParser alloc] init];
    moduleLifecycleDispatcher_ =
        [[BabelModuleLifecycleDispatcher alloc]
            initWithProjectLifecycleResponseParser:projectLifecycleResponseParser];
    recentlyClosedTabStore_ = [[BabelRecentlyClosedTabStore alloc] init];
    closedTabReopenCoordinator_ =
        [[BabelClosedTabReopenCoordinator alloc]
            initWithRecentlyClosedTabStore:recentlyClosedTabStore_
              closedTabRestorationPlanner:closedTabRestorationPlanner_];
    historyPageDataSource_ =
        [[BabelHistoryPageDataSource alloc]
            initWithInternalPageTabClassifier:internalPageTabClassifier_
                       recentlyClosedTabStore:recentlyClosedTabStore_
                             defaultGroupName:kDefaultGroupName];
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
    moduleSettingsRouteResolver_ = [[BabelModuleSettingsRouteResolver alloc] init];
    internalPageHTMLComposer_ =
        [[BabelInternalPageHTMLComposer alloc] initWithInternalPageRenderer:internalPageRenderer_
                                                        historyPageRenderer:historyPageRenderer_
                                                      historyPageDataSource:historyPageDataSource_
                                                    appSettingsPageRenderer:appSettingsPageRenderer_
                                                 moduleSettingsPageRenderer:moduleSettingsPageRenderer_
                                                     extensionsPageRenderer:extensionsPageRenderer_
                                                   extensionsPageDataSource:extensionsPageDataSource_];
    stableServerURLResolver_ = [[BabelStableServerURLResolver alloc] init];
    runtimeRefreshTabMatcher_ =
        [[BabelRuntimeRefreshTabMatcher alloc]
            initWithStableServerURLResolver:stableServerURLResolver_
                   localServiceURLClassifier:localServiceURLClassifier_];
    stableURLTabReloader_ =
        [[BabelStableURLTabReloader alloc]
            initWithStableServerURLResolver:stableServerURLResolver_
                          refreshTabMatcher:runtimeRefreshTabMatcher_
                    navigationResolverBlock:^NSString*(NSString* stableURLString) {
                      return [weakSelf navigationURLStringForStableBabelChromeURLString:stableURLString];
                    }];
    stableViewerURLResolver_ = [[BabelStableViewerURLResolver alloc] init];
    viewerNavigationURLResolver_ =
        [[BabelViewerNavigationURLResolver alloc] initWithStableViewerURLResolver:stableViewerURLResolver_
                                                             noViewerPageRenderer:noViewerPageRenderer_
                                                               htmlDataURLBuilder:htmlDataURLBuilder_];
    addressBarDisplayResolver_ =
        [[BabelAddressBarDisplayResolver alloc]
            initWithStableViewerURLResolver:stableViewerURLResolver_
                    internalPageTabPredicate:^BOOL(BabelBrowserTab* tab) {
                      return [weakSelf isInternalPageTab:tab];
                    }];
    addressNavigationRequestResolver_ =
        [[BabelAddressNavigationRequestResolver alloc]
            initWithDefaultURLString:BabelChromeConfiguration.defaultURLString
                 navigationNormalizer:addressNavigationNormalizer_
              fieldNavigationResolver:addressFieldNavigationResolver_
            addressBarDisplayResolver:addressBarDisplayResolver_
              stableViewerURLResolver:stableViewerURLResolver_
           supportedViewerURLResolver:^NSString*(NSString* urlString) {
             BabelBrowserWindowController* strongSelf = weakSelf;
             return strongSelf ? [strongSelf stableViewerURLStringForSupportedURLString:urlString] : nil;
           }
        stableNavigationURLResolver:^NSString*(NSString* urlString) {
          BabelBrowserWindowController* strongSelf = weakSelf;
          return strongSelf ? [strongSelf navigationURLStringForStableBabelChromeURLString:urlString] : nil;
        }];
    tabContentViewAttacher_ = [[BabelTabContentViewAttacher alloc] init];
    tabDragCoordinator_ = [[BabelTabDragCoordinator alloc] init];
    tabDragHoverScheduler_ = [[BabelTabDragHoverScheduler alloc] init];
    browserTabMoveCoordinator_ =
        [[BabelBrowserTabMoveCoordinator alloc] initWithDragCoordinator:tabDragCoordinator_];
    tabStripLayoutCalculator_ =
        [[BabelTabStripLayoutCalculator alloc] initWithNormalWidth:kTabNormalWidth
                                                       activeWidth:kTabActiveWidth
                                                      minimumWidth:kTabMinimumWidth
                                                          tabHeight:kTabHeight
                                                            spacing:kTabSpacing];
    tabURLMatcher_ = [[BabelTabURLMatcher alloc] init];
    viewerSourceResolver_ =
        [[BabelViewerSourceResolver alloc] initWithStableViewerURLResolver:stableViewerURLResolver_];
    viewerSourceActionHandler_ =
        [[BabelViewerSourceActionHandler alloc] initWithViewerSourceResolver:viewerSourceResolver_];
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
    isRestoringSession_ = NO;
    isBuildingInterface_ = NO;
    didApplyInitialSidebarRestore_ = NO;
    [extensionProfileStore_ restoreProfileExtensionsMovedByOlderVersions];
    [extensionProfileStore_ clearPendingProfileExtensionRestartStates];
    window.delegate = self;
    browserPageLifecycleController_ =
        [[BabelBrowserPageLifecycleController alloc]
                  initWithGroups:groups_
                     pendingTabs:pendingTabs_
                   browserClient:browserClient_
               creationScheduler:browserCreationScheduler_
        adjacentTabPreloadPlanner:adjacentTabPreloadPlanner_
                  evictionPolicy:liveBrowserEvictionPolicy_
         liveBrowserLimitEnforcer:liveBrowserLimitEnforcer_
         keyboardDelayNanoseconds:kKeyboardTabSelectionBrowserCreationDelayNanoseconds
  adjacentInitialDelayNanoseconds:kAdjacentTabPreloadInitialDelayNanoseconds
     adjacentStepDelayNanoseconds:kAdjacentTabPreloadStepDelayNanoseconds
             visibleTabsProvider:^NSArray<BabelBrowserTab*>*{
               BabelBrowserWindowController* strongSelf = weakSelf;
               return strongSelf ? strongSelf->tabs_ : @[];
             }
              selectedTabProvider:^BabelBrowserTab*{
                BabelBrowserWindowController* strongSelf = weakSelf;
                return strongSelf ? strongSelf->selectedTab_ : nil;
              }
              terminationProvider:^BOOL{
                BabelBrowserWindowController* strongSelf = weakSelf;
                return strongSelf ? strongSelf->isTerminating_ : YES;
              }];
    [self buildInterface];
    browserGroupManager_ =
        [[BabelBrowserGroupManager alloc] initWithGroups:groups_
                                          groupsListView:groupsListView_
                                         groupCollection:browserGroupCollection_
                                            groupFactory:browserGroupFactory_
                                  defaultGroupIdentifier:kDefaultGroupIdentifier
                                        defaultGroupName:kDefaultGroupName
                                           layoutHandler:^{
                                             [weakSelf layoutGroupItems];
                                           }];
    browserTabCreationCoordinator_ =
        [[BabelBrowserTabCreationCoordinator alloc]
            initWithTabFactory:browserTabFactory_
          insertionCoordinator:browserTabInsertionCoordinator_
            contentViewAttacher:tabContentViewAttacher_
                     pagesPanel:pagesPanel_
     tabOpeningStrategyProvider:^NSString*{
       return [weakSelf tabOpeningStrategy];
     }];
    browserTabDragSessionController_ =
        [[BabelBrowserTabDragSessionController alloc]
                  initWithGroups:groups_
                           window:window
                   groupsListView:groupsListView_
                      sidebarView:sidebarView_
                   tabsItemsPanel:tabsItemsPanel_
                    tabCollection:browserTabCollection_
                  dragCoordinator:tabDragCoordinator_
                   hoverScheduler:tabDragHoverScheduler_
                  moveCoordinator:browserTabMoveCoordinator_
              visibleTabsProvider:^NSArray<BabelBrowserTab*>*{
                BabelBrowserWindowController* strongSelf = weakSelf;
                return strongSelf ? strongSelf->tabs_ : @[];
              }
            selectedGroupProvider:^BabelBrowserGroup*{
              BabelBrowserWindowController* strongSelf = weakSelf;
              return strongSelf ? strongSelf->selectedGroup_ : nil;
            }
                tabLookupProvider:^BabelBrowserTab*(NSString* identifier) {
                  return [weakSelf tabWithIdentifier:identifier];
                }
          manualGroupNameProvider:^NSString*{
            return [weakSelf nextManualGroupName];
          }
               groupCreateHandler:^BabelBrowserGroup*(NSString* groupName, NSString* identifier) {
                 return [weakSelf createGroupWithName:groupName identifier:identifier];
               }
               selectGroupHandler:^(BabelBrowserGroup* group) {
                 [weakSelf selectGroup:group];
               }
                 selectTabHandler:^(BabelBrowserTab* tab) {
                   [weakSelf selectTab:tab];
                 }
                layoutTabsHandler:^{
                  [weakSelf layoutTabItemsSelectingLastTab:NO];
                }
                 saveStateHandler:^{
                   [weakSelf saveGroupsState];
                 }
            hoverDelayNanoseconds:kTabDragGroupHoverDelayNanoseconds];
    browserGroupSelectionController_ =
        [[BabelBrowserGroupSelectionController alloc]
                 initWithGroups:groups_
                 tabsItemsPanel:tabsItemsPanel_
                  tabCollection:browserTabCollection_
            draggingTabProvider:^BabelBrowserTab*{
              BabelBrowserWindowController* strongSelf = weakSelf;
              return strongSelf ? strongSelf->browserTabDragSessionController_.draggingTab : nil;
            }
             visibleTabsHandler:^(NSMutableArray<BabelBrowserTab*>* visibleTabs) {
               BabelBrowserWindowController* strongSelf = weakSelf;
               if (strongSelf) {
                 strongSelf->tabs_ = visibleTabs;
               }
             }
           selectedGroupHandler:^(BabelBrowserGroup* group) {
             BabelBrowserWindowController* strongSelf = weakSelf;
             if (strongSelf) {
               strongSelf->selectedGroup_ = group;
             }
           }
             selectedTabHandler:^(BabelBrowserTab* tab) {
               BabelBrowserWindowController* strongSelf = weakSelf;
               if (strongSelf) {
                 strongSelf->selectedTab_ = tab;
               }
             }
               selectTabHandler:^(BabelBrowserTab* tab) {
                 [weakSelf selectTab:tab];
               }
             clearAddressHandler:^{
               [weakSelf clearAddressBar];
             }
        updateWindowTitleHandler:^{
          [weakSelf updateWindowTitleForSelectedTab];
        }
              layoutTabsHandler:^{
                [weakSelf layoutTabItemsSelectingLastTab:NO];
              }
             layoutGroupsHandler:^{
               [weakSelf layoutGroupItems];
             }];
    browserSessionRestorationCoordinator_ =
        [[BabelBrowserSessionRestorationCoordinator alloc]
            initWithGroupSessionStore:groupSessionStore_
              tabContentViewAttacher:tabContentViewAttacher_
                          pagesPanel:pagesPanel_
              defaultGroupIdentifier:kDefaultGroupIdentifier
                     defaultGroupName:kDefaultGroupName
                 groupLookupProvider:^BabelBrowserGroup*(NSString* identifier) {
                   return [weakSelf groupWithIdentifier:identifier];
                 }
                   groupCreateHandler:^BabelBrowserGroup*(NSString* name, NSString* identifier) {
                     return [weakSelf createGroupWithName:name identifier:identifier];
                   }
                    tabLookupProvider:^BabelBrowserTab*(NSString* urlString, BabelBrowserGroup* group) {
                      return [weakSelf tabWithURLString:urlString inGroup:group];
                    }
                     tabCreateHandler:^BabelBrowserTab*(NSString* urlString, NSString* identifier, NSString* title) {
                       return [weakSelf makeTabForURL:urlString identifier:identifier title:title];
                     }
                    stableURLResolver:^NSString*(NSString* urlString) {
                      return [weakSelf navigationURLStringForStableBabelChromeURLString:urlString];
                    }
                   stableURLPredicate:^BOOL(NSString* urlString) {
                     return [weakSelf isStableBabelChromeURLString:urlString];
                   }
                   selectGroupHandler:^(BabelBrowserGroup* group) {
                     [weakSelf selectGroup:group];
                   }
                     saveStateHandler:^{
                       [weakSelf saveGroupsState];
                     }];
    browserClosedTabController_ =
        [[BabelBrowserClosedTabController alloc]
            initWithRecentlyClosedTabStore:recentlyClosedTabStore_
                closedTabReopenCoordinator:closedTabReopenCoordinator_
                   tabDefaultPageResetter:tabDefaultPageResetter_
                  tabContentViewAttacher:tabContentViewAttacher_
                              pagesPanel:pagesPanel_
                        defaultGroupName:kDefaultGroupName
                     visibleTabsProvider:^NSArray<BabelBrowserTab*>*{
                       BabelBrowserWindowController* strongSelf = weakSelf;
                       return strongSelf ? strongSelf->tabs_ : @[];
                     }
                   selectedGroupProvider:^BabelBrowserGroup*{
                     BabelBrowserWindowController* strongSelf = weakSelf;
                     return strongSelf ? strongSelf->selectedGroup_ : nil;
                   }
                     groupLookupProvider:^BabelBrowserGroup*(NSString* identifier) {
                       return [weakSelf groupWithIdentifier:identifier];
                     }
                       groupCreateHandler:^BabelBrowserGroup*(NSString* name, NSString* identifier) {
                         return [weakSelf createGroupWithName:name identifier:identifier];
                       }
                         tabCreateHandler:^BabelBrowserTab*(NSString* urlString, NSString* identifier, NSString* title) {
                           return [weakSelf makeTabForURL:urlString identifier:identifier title:title];
                         }
               hideDeveloperToolsHandler:^(BabelBrowserTab* tab) {
                 [weakSelf hideDeveloperToolsForTab:tab];
               }
           removeSelectedGroupTabHandler:^(BabelBrowserTab* tab) {
             [weakSelf removeSelectedGroupTab:tab];
           }
                       selectGroupHandler:^(BabelBrowserGroup* group) {
                         [weakSelf selectGroup:group];
                       }
                         selectTabHandler:^(BabelBrowserTab* tab) {
                           [weakSelf selectTab:tab];
                         }
                        showWindowHandler:^{
                          [weakSelf showMainWindow];
                        }
                         saveStateHandler:^{
                           [weakSelf saveGroupsState];
                         }];
    browserMetadataEventController_ =
        [[BabelBrowserMetadataEventController alloc]
                    initWithMetadataUpdater:browserTabMetadataUpdater_
                                faviconStore:faviconStore_
                   runtimeRefreshCoordinator:runtimeRefreshCoordinator_
                      linkStatusBarController:linkStatusBarController_
                             pasteboardWriter:browserPasteboardWriter_
                           browserTabProvider:^BabelBrowserTab*(CefRefPtr<CefBrowser> browser) {
                             return [weakSelf tabForBrowser:browser];
                           }
                          selectedTabProvider:^BabelBrowserTab*{
                            BabelBrowserWindowController* strongSelf = weakSelf;
                            return strongSelf ? strongSelf->selectedTab_ : nil;
                          }
                            compactTitleBlock:^NSString*(NSString* value) {
                              return [weakSelf compactTitleForString:value];
                            }
                        stableServerPredicate:^BOOL(NSString* urlString) {
                          return [weakSelf isStableServerURLString:urlString];
                        }
                           stableURLPredicate:^BOOL(NSString* urlString) {
                             return [weakSelf isStableBabelChromeURLString:urlString];
                           }
                 localServiceRuntimePredicate:^BOOL(NSString* urlString) {
                   return [weakSelf isLocalServiceRuntimeURLString:urlString];
                 }
                  localServiceModulePredicate:^BOOL(NSString* urlString) {
                    return [weakSelf isLocalServiceModuleURLString:urlString];
                  }
                stableServerReloadURLProvider:^NSString*(BabelBrowserTab* tab) {
                  return [weakSelf stableServerReloadURLStringForTab:tab];
                }
                    refreshURLStringsProvider:^NSArray<NSString*>*(NSString* urlString) {
                      return [weakSelf refreshURLStringsForStableURLString:urlString];
                    }
             reloadRequestedURLStringsHandler:^(NSArray<NSString*>* requestedURLStrings, BabelBrowserTab* excludedTab) {
               [weakSelf reloadRequestedURLStrings:requestedURLStrings excludingTab:excludedTab];
             }
                             saveStateHandler:^{
                               [weakSelf saveGroupsState];
                             }
                     updateWindowTitleHandler:^{
                       [weakSelf updateWindowTitleForSelectedTab];
                     }
                      updateAddressBarHandler:^(BabelBrowserTab* tab) {
                        [weakSelf updateAddressBarForTab:tab];
                      }
                  addressFieldEditingProvider:^BOOL{
                    BabelBrowserWindowController* strongSelf = weakSelf;
                    return strongSelf ? strongSelf->urlTextField_.currentEditor != nil : NO;
                  }
                                statusBarView:linkStatusBarView_
                                  statusLabel:linkStatusBarLabel_
                                    rightView:rightView_
                                   pagesPanel:pagesPanel_];
    internalPageNavigator_ =
        [[BabelInternalPageNavigator alloc]
            initWithPagesPanel:pagesPanel_
         tabContentViewAttacher:tabContentViewAttacher_
             browserTabProvider:^BabelBrowserTab*(CefRefPtr<CefBrowser> browser) {
               return [weakSelf tabForBrowser:browser];
             }
            defaultGroupProvider:^BabelBrowserGroup*{
              BabelBrowserWindowController* strongSelf = weakSelf;
              if (!strongSelf) {
                return nil;
              }
              return strongSelf->selectedGroup_ ?: [strongSelf ensureGroupNamed:kDefaultGroupName];
            }
            existingTabProvider:^BabelBrowserTab*(NSString* urlString, BabelBrowserGroup* group) {
              return [weakSelf tabWithURLString:urlString inGroup:group];
            }
                tabFactoryBlock:^BabelBrowserTab*(NSString* urlString, NSString* identifier, NSString* title) {
                  return [weakSelf makeTabForURL:urlString identifier:identifier title:title];
                }
             dataURLBuilderBlock:^NSString*(NSString* html) {
               return [weakSelf dataURLStringForHTML:html];
             }
               compactTitleBlock:^NSString*(NSString* title) {
                 return [weakSelf compactTitleForString:title];
               }
               selectGroupHandler:^(BabelBrowserGroup* group) {
                 [weakSelf selectGroup:group];
               }
                 selectTabHandler:^(BabelBrowserTab* tab) {
                   [weakSelf selectTab:tab];
                 }
                showWindowHandler:^{
                  [weakSelf showMainWindow];
                }
                 saveStateHandler:^{
                   [weakSelf saveGroupsState];
                 }];
    omniboxSuggestionsController_ =
        [[BabelOmniboxSuggestionsController alloc] initWithPanel:omniboxSuggestionsPanel_];
    [faviconStore_ restore];
    [self restoreSessionByPriority];
  }
  return self;
}

@end

#pragma clang diagnostic pop
