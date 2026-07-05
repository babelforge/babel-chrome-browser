set(BABEL_CHROME_TARGET "BabelChrome")
set(BABEL_CHROME_HELPER_TARGET "BabelChrome_Helper")
set(BABEL_CHROME_HELPER_OUTPUT_NAME "BabelChrome Helper")

SET_CEF_TARGET_OUT_DIR()
set(BABEL_CHROME_APP "${CEF_TARGET_OUT_DIR}/${BABEL_CHROME_TARGET}.app")

set(BABEL_CHROME_SOURCES
  App/ApplicationDelegate.h
  App/ApplicationDelegate.mm
  App/MainMenuBuilder.h
  App/MainMenuBuilder.mm
  Browser/AddressBarDisplayResolver.h
  Browser/AddressBarDisplayResolver.mm
  Browser/AddressFieldLayoutCalculator.h
  Browser/AddressFieldLayoutCalculator.mm
  Browser/AddressFieldNavigationResolver.h
  Browser/AddressFieldNavigationResolver.mm
  Browser/AddressNavigationRequestResolver.h
  Browser/AddressNavigationRequestResolver.mm
  Browser/AdjacentTabPreloadPlanner.h
  Browser/AdjacentTabPreloadPlanner.mm
  Browser/AppSettingsPageRenderer.h
  Browser/AppSettingsPageRenderer.mm
  Browser/ApplicationRelauncher.h
  Browser/ApplicationRelauncher.mm
  Browser/AddressNavigationNormalizer.h
  Browser/AddressNavigationNormalizer.mm
  Browser/BrowserClient.h
  Browser/BrowserClient.mm
  Browser/BrowserClosedTabController.h
  Browser/BrowserClosedTabController.mm
  Browser/BrowserAttachmentCoordinator.h
  Browser/BrowserAttachmentCoordinator.mm
  Browser/BrowserCreationScheduler.h
  Browser/BrowserCreationScheduler.mm
  Browser/BrowserPageLifecycleController.h
  Browser/BrowserPageLifecycleController.mm
  Browser/BrowserGroupCollection.h
  Browser/BrowserGroupCollection.mm
  Browser/BrowserSessionRestorationCoordinator.h
  Browser/BrowserSessionRestorationCoordinator.mm
  Browser/BrowserGroupFactory.h
  Browser/BrowserGroupFactory.mm
  Browser/BrowserGroupManager.h
  Browser/BrowserGroupManager.mm
  Browser/BrowserGroupSelectionController.h
  Browser/BrowserGroupSelectionController.mm
  Browser/BrowserGroupMoveCoordinator.h
  Browser/BrowserGroupMoveCoordinator.mm
  Browser/BrowserMetadataEventController.h
  Browser/BrowserMetadataEventController.mm
  Browser/BrowserPasteboardWriter.h
  Browser/BrowserPasteboardWriter.mm
  Browser/BrowserSettingsStore.h
  Browser/BrowserSettingsStore.mm
  Browser/BrowserStringFormatter.h
  Browser/BrowserStringFormatter.mm
  Browser/BrowserTabCollection.h
  Browser/BrowserTabCollection.mm
  Browser/BrowserTabCreationCoordinator.h
  Browser/BrowserTabCreationCoordinator.mm
  Browser/BrowserTabDragSessionController.h
  Browser/BrowserTabDragSessionController.mm
  Browser/BrowserTabFactory.h
  Browser/BrowserTabFactory.mm
  Browser/BrowserTabInsertionCoordinator.h
  Browser/BrowserTabInsertionCoordinator.mm
  Browser/BrowserTabLookupService.h
  Browser/BrowserTabLookupService.mm
  Browser/BrowserTabMetadataUpdater.h
  Browser/BrowserTabMetadataUpdater.mm
  Browser/BrowserTabMoveCoordinator.h
  Browser/BrowserTabMoveCoordinator.mm
  Browser/BrowserThemeApplier.h
  Browser/BrowserThemeApplier.mm
  Browser/ChromeCommandParser.h
  Browser/ChromeCommandParser.mm
  Browser/ClosedTabRestorationPlanner.h
  Browser/ClosedTabRestorationPlanner.mm
  Browser/ClosedTabReopenCoordinator.h
  Browser/ClosedTabReopenCoordinator.mm
  Browser/ExtensionFolderController.h
  Browser/ExtensionFolderController.mm
  Browser/ExtensionProfileStore.h
  Browser/ExtensionProfileStore.mm
  Browser/ExtensionsPageDataSource.h
  Browser/ExtensionsPageDataSource.mm
  Browser/ExtensionsPageRenderer.h
  Browser/ExtensionsPageRenderer.mm
  Browser/FaviconStore.h
  Browser/FaviconStore.mm
  Browser/GoogleSuggestClient.h
  Browser/GoogleSuggestClient.mm
  Browser/GoogleSuggestionScheduler.h
  Browser/GoogleSuggestionScheduler.mm
  Browser/GroupListCoordinator.h
  Browser/GroupListCoordinator.mm
  Browser/GroupRenameController.h
  Browser/GroupRenameController.mm
  Browser/GroupSessionStore.h
  Browser/GroupSessionStore.mm
  Browser/HistoryPageDataSource.h
  Browser/HistoryPageDataSource.mm
  Browser/HistoryPageRenderer.h
  Browser/HistoryPageRenderer.mm
  Browser/HTMLDataURLBuilder.h
  Browser/HTMLDataURLBuilder.mm
  Browser/InternalNavigationActionParser.h
  Browser/InternalNavigationActionParser.mm
  Browser/InternalExtensionsNavigationHandler.h
  Browser/InternalExtensionsNavigationHandler.mm
  Browser/InternalModuleNavigationHandler.h
  Browser/InternalModuleNavigationHandler.mm
  Browser/InternalPageAssetProvider.h
  Browser/InternalPageAssetProvider.mm
  Browser/InternalPageHTMLComposer.h
  Browser/InternalPageHTMLComposer.mm
  Browser/InternalPageNavigator.h
  Browser/InternalPageNavigator.mm
  Browser/InternalPageRenderer.h
  Browser/InternalPageRenderer.mm
  Browser/InternalPageTabClassifier.h
  Browser/InternalPageTabClassifier.mm
  Browser/InternalSettingsNavigationHandler.h
  Browser/InternalSettingsNavigationHandler.mm
  Browser/LiveBrowserEvictionPolicy.h
  Browser/LiveBrowserEvictionPolicy.mm
  Browser/LiveBrowserLimitEnforcer.h
  Browser/LiveBrowserLimitEnforcer.mm
  Browser/LinkStatusBarController.h
  Browser/LinkStatusBarController.mm
  Browser/LocalDropBridgeScriptBuilder.h
  Browser/LocalDropBridgeScriptBuilder.mm
  Browser/LocalDropCoordinator.h
  Browser/LocalDropCoordinator.mm
  Browser/LocalDropLogWriter.h
  Browser/LocalDropLogWriter.mm
  Browser/LocalDropPayloadBuilder.h
  Browser/LocalDropPayloadBuilder.mm
  Browser/LocalDropSessionController.h
  Browser/LocalDropSessionController.mm
  Browser/LocalDropSupportResolver.h
  Browser/LocalDropSupportResolver.mm
  Browser/LocalServiceURLClassifier.h
  Browser/LocalServiceURLClassifier.mm
  Browser/ModuleActionService.h
  Browser/ModuleActionService.mm
  Browser/ModuleInternalPageHTMLBuilder.h
  Browser/ModuleInternalPageHTMLBuilder.mm
  Browser/ModuleLifecycleDispatcher.h
  Browser/ModuleLifecycleDispatcher.mm
  Browser/ModuleNavigationURLResolver.h
  Browser/ModuleNavigationURLResolver.mm
  Browser/ModulePageRenderer.h
  Browser/ModulePageRenderer.mm
  Browser/ModuleSettingsPageRenderer.h
  Browser/ModuleSettingsPageRenderer.mm
  Browser/ModuleSettingsRouteResolver.h
  Browser/ModuleSettingsRouteResolver.mm
  Browser/ModuleUpdateService.h
  Browser/ModuleUpdateService.mm
  Browser/ModuleUIActionCoordinator.h
  Browser/ModuleUIActionCoordinator.mm
  Browser/NewTabURLResolver.h
  Browser/NewTabURLResolver.mm
  Browser/NoViewerPageRenderer.h
  Browser/NoViewerPageRenderer.mm
  Browser/OmniboxLocalSuggestionBuilder.h
  Browser/OmniboxLocalSuggestionBuilder.mm
  Browser/OmniboxSuggestionContextBuilder.h
  Browser/OmniboxSuggestionContextBuilder.mm
  Browser/OmniboxSuggestionsController.h
  Browser/OmniboxSuggestionsController.mm
  Browser/ProjectLauncherJSONImporter.h
  Browser/ProjectLauncherJSONImporter.mm
  Browser/ProjectLifecycleResponseParser.h
  Browser/ProjectLifecycleResponseParser.mm
  Browser/RecentlyClosedTabStore.h
  Browser/RecentlyClosedTabStore.mm
  Browser/RuntimeRefreshCoordinator.h
  Browser/RuntimeRefreshCoordinator.mm
  Browser/RuntimeRefreshTabMatcher.h
  Browser/RuntimeRefreshTabMatcher.mm
  Browser/SettingsOptionRenderer.h
  Browser/SettingsOptionRenderer.mm
  Browser/SidebarLayoutCalculator.h
  Browser/SidebarLayoutCalculator.mm
  Browser/StableServerURLResolver.h
  Browser/StableServerURLResolver.mm
  Browser/StableURLTabReloader.h
  Browser/StableURLTabReloader.mm
  Browser/StableViewerURLResolver.h
  Browser/StableViewerURLResolver.mm
  Browser/TabContentViewAttacher.h
  Browser/TabContentViewAttacher.mm
  Browser/TabDefaultPageResetter.h
  Browser/TabDefaultPageResetter.mm
  Browser/TabDragCoordinator.h
  Browser/TabDragCoordinator.mm
  Browser/TabDragHoverScheduler.h
  Browser/TabDragHoverScheduler.mm
  Browser/TabPlacementPolicy.h
  Browser/TabPlacementPolicy.mm
  Browser/TabStripLayoutCalculator.h
  Browser/TabStripLayoutCalculator.mm
  Browser/TabURLMatcher.h
  Browser/TabURLMatcher.mm
  Browser/ViewerSourceResolver.h
  Browser/ViewerSourceResolver.mm
  Browser/ViewerSourceActionHandler.h
  Browser/ViewerSourceActionHandler.mm
  Browser/ViewerNavigationURLResolver.h
  Browser/ViewerNavigationURLResolver.mm
  Browser/WindowStateStore.h
  Browser/WindowStateStore.mm
  Browser/MainWindowViewFactory.h
  Browser/MainWindowViewFactory.mm
  Browser/BrowserModels.h
  Browser/BrowserModels.mm
  Browser/BrowserNavigationController.h
  Browser/BrowserNavigationController.mm
  Browser/BrowserPresentationFormatter.h
  Browser/BrowserPresentationFormatter.mm
  Browser/BrowserSupportViews.h
  Browser/BrowserSupportViews.mm
  Browser/BrowserTheme.h
  Browser/BrowserTheme.mm
  Browser/BrowserViews.h
  Browser/BrowserViews.mm
  Browser/DeveloperToolsDockingStore.h
  Browser/DeveloperToolsDockingStore.mm
  Browser/DeveloperToolsDockingPolicy.h
  Browser/DeveloperToolsDockingPolicy.mm
  Browser/DeveloperToolsLayoutCalculator.h
  Browser/DeveloperToolsLayoutCalculator.mm
  Browser/DeveloperToolsPanelController.h
  Browser/DeveloperToolsPanelController.mm
  Browser/DeveloperToolsTargetResolver.h
  Browser/DeveloperToolsTargetResolver.mm
  Browser/BrowserWindowController.h
  Browser/BrowserWindowController.mm
  Browser/BabelBrowserWindowAddressAndSuggestionsActions.h
  Browser/BabelBrowserWindowAddressAndSuggestionsActions.mm
  Browser/BabelBrowserWindowBrowserAttachmentActions.h
  Browser/BabelBrowserWindowBrowserAttachmentActions.mm
  Browser/BabelBrowserWindowBrowserControlsActions.h
  Browser/BabelBrowserWindowBrowserControlsActions.mm
  Browser/BabelBrowserWindowDeveloperToolsActions.h
  Browser/BabelBrowserWindowDeveloperToolsActions.mm
  Browser/BabelBrowserWindowGroupsAndTabsActions.h
  Browser/BabelBrowserWindowGroupsAndTabsActions.mm
  Browser/BabelBrowserWindowInternalPagesActions.h
  Browser/BabelBrowserWindowInternalPagesActions.mm
  Browser/BabelBrowserWindowLocalDropActions.h
  Browser/BabelBrowserWindowLocalDropActions.mm
  Browser/BabelBrowserWindowURLRoutingActions.h
  Browser/BabelBrowserWindowURLRoutingActions.mm
  Browser/BabelBrowserWindowLifecycleActions.h
  Browser/BabelBrowserWindowLifecycleActions.mm
  Browser/BrowserWindowControllerPrivate.h
  Configuration/Configuration.h
  Configuration/Configuration.mm
  LocalServices/LocalServiceHost.h
  LocalServices/LocalServiceHost.mm
  Startup/ProfileExtensionStartupSynchronizer.h
  Startup/ProfileExtensionStartupSynchronizer.mm
  main_mac.mm
)

set(BABEL_CHROME_HELPER_SOURCES
  Process/process_helper_mac.cc
)

set(BABEL_CHROME_RESOURCES
  Resources/BabelChrome.icns
  Resources/BabelForgeIcon.png
  Resources/collapse-left.svg
  Resources/collapse-right.svg
  Resources/devtools-close.svg
  Resources/devtools-dock-bottom.svg
  Resources/devtools-dock-left.svg
  Resources/devtools-dock-right.svg
  Resources/devtools-dock-top.svg
  Resources/settings-gear.svg
  Resources/tab-close.svg
  Resources/toolbar-reload.svg
)

option(OPTION_USE_ARC "Build with ARC on macOS." ON)
if(OPTION_USE_ARC)
  list(APPEND CEF_COMPILER_FLAGS -fobjc-arc)
endif()

set(EXECUTABLE_NAME "${BABEL_CHROME_TARGET}")
set(PRODUCT_NAME "${BABEL_CHROME_TARGET}")

add_executable(${BABEL_CHROME_TARGET} MACOSX_BUNDLE ${BABEL_CHROME_RESOURCES} ${BABEL_CHROME_SOURCES})
SET_EXECUTABLE_TARGET_PROPERTIES(${BABEL_CHROME_TARGET})
add_dependencies(${BABEL_CHROME_TARGET} libcef_dll_wrapper)
target_link_libraries(${BABEL_CHROME_TARGET} libcef_dll_wrapper ${CEF_STANDARD_LIBS})
target_include_directories(${BABEL_CHROME_TARGET} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CEF_ROOT})
set_target_properties(${BABEL_CHROME_TARGET} PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Resources/Info.plist.in
  RESOURCE "${BABEL_CHROME_RESOURCES}"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "fr.babelforge.babel-chrome"
)

COPY_MAC_FRAMEWORK("${BABEL_CHROME_TARGET}" "${CEF_BINARY_DIR}" "${BABEL_CHROME_APP}")

add_custom_command(
  TARGET ${BABEL_CHROME_TARGET}
  POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E remove -f
          "${BABEL_CHROME_APP}/Contents/Resources/BabelForgeLogo.png"
  COMMAND ${CMAKE_COMMAND} -E remove_directory
          "${BABEL_CHROME_APP}/Contents/Resources/LocalServices"
  COMMAND ${CMAKE_COMMAND} -E remove_directory
          "${BABEL_CHROME_APP}/Contents/Resources/ExtensionHost"
  COMMAND ${CMAKE_COMMAND} -E remove_directory
          "${BABEL_CHROME_APP}/Contents/Resources/Themes"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
          "${CMAKE_CURRENT_SOURCE_DIR}/ExtensionHost"
          "${BABEL_CHROME_APP}/Contents/Resources/ExtensionHost"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
          "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Themes"
          "${BABEL_CHROME_APP}/Contents/Resources/Themes"
  VERBATIM
)

foreach(_suffix_list ${CEF_HELPER_APP_SUFFIXES})
  string(REPLACE ":" ";" _suffix_list ${_suffix_list})
  list(GET _suffix_list 0 _name_suffix)
  list(GET _suffix_list 1 _target_suffix)
  list(GET _suffix_list 2 _plist_suffix)

  set(_helper_target "${BABEL_CHROME_HELPER_TARGET}${_target_suffix}")
  set(_helper_output_name "${BABEL_CHROME_HELPER_OUTPUT_NAME}${_name_suffix}")

  set(_helper_info_plist "${CMAKE_CURRENT_BINARY_DIR}/helper-Info${_target_suffix}.plist")
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/Resources/helper-Info.plist.in" _plist_contents)
  string(REPLACE "\${EXECUTABLE_NAME}" "${_helper_output_name}" _plist_contents ${_plist_contents})
  string(REPLACE "\${PRODUCT_NAME}" "${_helper_output_name}" _plist_contents ${_plist_contents})
  string(REPLACE "\${BUNDLE_ID_SUFFIX}" "${_plist_suffix}" _plist_contents ${_plist_contents})
  file(WRITE ${_helper_info_plist} ${_plist_contents})

  add_executable(${_helper_target} MACOSX_BUNDLE ${BABEL_CHROME_HELPER_SOURCES})
  SET_EXECUTABLE_TARGET_PROPERTIES(${_helper_target})
  add_dependencies(${_helper_target} libcef_dll_wrapper)
  target_link_libraries(${_helper_target} libcef_dll_wrapper ${CEF_STANDARD_LIBS})
  target_include_directories(${_helper_target} PRIVATE ${CEF_ROOT})
  set_target_properties(${_helper_target} PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${_helper_info_plist}
    OUTPUT_NAME ${_helper_output_name}
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "fr.babelforge.babel-chrome.helper${_plist_suffix}"
  )

  add_dependencies(${BABEL_CHROME_TARGET} "${_helper_target}")
  add_custom_command(
    TARGET ${BABEL_CHROME_TARGET}
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CEF_TARGET_OUT_DIR}/${_helper_output_name}.app"
            "${BABEL_CHROME_APP}/Contents/Frameworks/${_helper_output_name}.app"
    VERBATIM
  )
endforeach()
