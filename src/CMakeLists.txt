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
  Browser/Address/Bar/AddressBarDisplayResolver.h
  Browser/Address/Bar/AddressBarDisplayResolver.mm
  Browser/Address/Bar/AddressFieldLayoutCalculator.h
  Browser/Address/Bar/AddressFieldLayoutCalculator.mm
  Browser/Address/Bar/AddressFieldNavigationResolver.h
  Browser/Address/Bar/AddressFieldNavigationResolver.mm
  Browser/Address/Bar/AddressNavigationRequestResolver.h
  Browser/Address/Bar/AddressNavigationRequestResolver.mm
  Browser/Tabs/Selection/AdjacentTabPreloadPlanner.h
  Browser/Tabs/Selection/AdjacentTabPreloadPlanner.mm
  Browser/InternalPages/Settings/AppSettingsPageRenderer.h
  Browser/InternalPages/Settings/AppSettingsPageRenderer.mm
  Browser/Utilities/Application/ApplicationRelauncher.h
  Browser/Utilities/Application/ApplicationRelauncher.mm
  Browser/Address/Bar/AddressNavigationNormalizer.h
  Browser/Address/Bar/AddressNavigationNormalizer.mm
  Browser/CEF/Client/BrowserClient.h
  Browser/CEF/Client/BrowserClient.mm
  Browser/Tabs/Closing/BrowserClosedTabController.h
  Browser/Tabs/Closing/BrowserClosedTabController.mm
  Browser/CEF/Attachment/BrowserAttachmentCoordinator.h
  Browser/CEF/Attachment/BrowserAttachmentCoordinator.mm
  Browser/Tabs/Creation/BrowserCreationScheduler.h
  Browser/Tabs/Creation/BrowserCreationScheduler.mm
  Browser/Tabs/Selection/BrowserPageLifecycleController.h
  Browser/Tabs/Selection/BrowserPageLifecycleController.mm
  Browser/Groups/Model/BrowserGroupCollection.h
  Browser/Groups/Model/BrowserGroupCollection.mm
  Browser/Tabs/Lifecycle/BrowserSessionRestorationCoordinator.h
  Browser/Tabs/Lifecycle/BrowserSessionRestorationCoordinator.mm
  Browser/Groups/Creation/BrowserGroupFactory.h
  Browser/Groups/Creation/BrowserGroupFactory.mm
  Browser/Groups/Management/BrowserGroupManager.h
  Browser/Groups/Management/BrowserGroupManager.mm
  Browser/Groups/Management/BrowserGroupSelectionController.h
  Browser/Groups/Management/BrowserGroupSelectionController.mm
  Browser/Groups/Management/BrowserGroupMoveCoordinator.h
  Browser/Groups/Management/BrowserGroupMoveCoordinator.mm
  Browser/CEF/Events/BrowserMetadataEventController.h
  Browser/CEF/Events/BrowserMetadataEventController.mm
  Browser/UI/Pasteboard/BrowserPasteboardWriter.h
  Browser/UI/Pasteboard/BrowserPasteboardWriter.mm
  Browser/State/Settings/BrowserSettingsStore.h
  Browser/State/Settings/BrowserSettingsStore.mm
  Browser/UI/Formatting/BrowserStringFormatter.h
  Browser/UI/Formatting/BrowserStringFormatter.mm
  Browser/Tabs/Model/BrowserTabCollection.h
  Browser/Tabs/Model/BrowserTabCollection.mm
  Browser/Tabs/Creation/BrowserTabCreationCoordinator.h
  Browser/Tabs/Creation/BrowserTabCreationCoordinator.mm
  Browser/Tabs/Movement/BrowserTabDragSessionController.h
  Browser/Tabs/Movement/BrowserTabDragSessionController.mm
  Browser/Tabs/Creation/BrowserTabFactory.h
  Browser/Tabs/Creation/BrowserTabFactory.mm
  Browser/Tabs/Creation/BrowserTabInsertionCoordinator.h
  Browser/Tabs/Creation/BrowserTabInsertionCoordinator.mm
  Browser/Tabs/Model/BrowserTabLookupService.h
  Browser/Tabs/Model/BrowserTabLookupService.mm
  Browser/Tabs/Model/BrowserTabMetadataUpdater.h
  Browser/Tabs/Model/BrowserTabMetadataUpdater.mm
  Browser/Tabs/Movement/BrowserTabMoveCoordinator.h
  Browser/Tabs/Movement/BrowserTabMoveCoordinator.mm
  Browser/UI/Theme/BrowserThemeApplier.h
  Browser/UI/Theme/BrowserThemeApplier.mm
  Browser/Navigation/Commands/ChromeCommandParser.h
  Browser/Navigation/Commands/ChromeCommandParser.mm
  Browser/Tabs/Closing/ClosedTabRestorationPlanner.h
  Browser/Tabs/Closing/ClosedTabRestorationPlanner.mm
  Browser/Tabs/Closing/ClosedTabReopenCoordinator.h
  Browser/Tabs/Closing/ClosedTabReopenCoordinator.mm
  Browser/Extensions/Install/ExtensionFolderController.h
  Browser/Extensions/Install/ExtensionFolderController.mm
  Browser/Extensions/Profile/ExtensionProfileStore.h
  Browser/Extensions/Profile/ExtensionProfileStore.mm
  Browser/InternalPages/Extensions/ExtensionsPageDataSource.h
  Browser/InternalPages/Extensions/ExtensionsPageDataSource.mm
  Browser/InternalPages/Extensions/ExtensionsPageRenderer.h
  Browser/InternalPages/Extensions/ExtensionsPageRenderer.mm
  Browser/State/Favicons/FaviconStore.h
  Browser/State/Favicons/FaviconStore.mm
  Browser/Address/Suggestions/GoogleSuggestClient.h
  Browser/Address/Suggestions/GoogleSuggestClient.mm
  Browser/Address/Suggestions/GoogleSuggestionScheduler.h
  Browser/Address/Suggestions/GoogleSuggestionScheduler.mm
  Browser/Groups/UI/GroupListCoordinator.h
  Browser/Groups/UI/GroupListCoordinator.mm
  Browser/Groups/UI/GroupRenameController.h
  Browser/Groups/UI/GroupRenameController.mm
  Browser/State/Sessions/GroupSessionStore.h
  Browser/State/Sessions/GroupSessionStore.mm
  Browser/InternalPages/History/HistoryPageDataSource.h
  Browser/InternalPages/History/HistoryPageDataSource.mm
  Browser/InternalPages/History/HistoryPageRenderer.h
  Browser/InternalPages/History/HistoryPageRenderer.mm
  Browser/Utilities/HTML/HTMLDataURLBuilder.h
  Browser/Utilities/HTML/HTMLDataURLBuilder.mm
  Browser/InternalPages/Navigation/InternalNavigationActionParser.h
  Browser/InternalPages/Navigation/InternalNavigationActionParser.mm
  Browser/InternalPages/Navigation/InternalExtensionsNavigationHandler.h
  Browser/InternalPages/Navigation/InternalExtensionsNavigationHandler.mm
  Browser/InternalPages/Navigation/InternalModuleNavigationHandler.h
  Browser/InternalPages/Navigation/InternalModuleNavigationHandler.mm
  Browser/InternalPages/Rendering/InternalPageAssetProvider.h
  Browser/InternalPages/Rendering/InternalPageAssetProvider.mm
  Browser/InternalPages/Rendering/InternalPageHTMLComposer.h
  Browser/InternalPages/Rendering/InternalPageHTMLComposer.mm
  Browser/InternalPages/Navigation/InternalPageNavigator.h
  Browser/InternalPages/Navigation/InternalPageNavigator.mm
  Browser/InternalPages/Rendering/InternalPageRenderer.h
  Browser/InternalPages/Rendering/InternalPageRenderer.mm
  Browser/InternalPages/Navigation/InternalPageTabClassifier.h
  Browser/InternalPages/Navigation/InternalPageTabClassifier.mm
  Browser/InternalPages/Navigation/InternalSettingsNavigationHandler.h
  Browser/InternalPages/Navigation/InternalSettingsNavigationHandler.mm
  Browser/Tabs/Lifecycle/LiveBrowserEvictionPolicy.h
  Browser/Tabs/Lifecycle/LiveBrowserEvictionPolicy.mm
  Browser/Tabs/Lifecycle/LiveBrowserLimitEnforcer.h
  Browser/Tabs/Lifecycle/LiveBrowserLimitEnforcer.mm
  Browser/Address/Status/LinkStatusBarController.h
  Browser/Address/Status/LinkStatusBarController.mm
  Browser/DragDrop/Bridge/LocalDropBridgeScriptBuilder.h
  Browser/DragDrop/Bridge/LocalDropBridgeScriptBuilder.mm
  Browser/DragDrop/Session/LocalDropCoordinator.h
  Browser/DragDrop/Session/LocalDropCoordinator.mm
  Browser/DragDrop/Logging/LocalDropLogWriter.h
  Browser/DragDrop/Logging/LocalDropLogWriter.mm
  Browser/DragDrop/Payload/LocalDropPayloadBuilder.h
  Browser/DragDrop/Payload/LocalDropPayloadBuilder.mm
  Browser/DragDrop/Session/LocalDropSessionController.h
  Browser/DragDrop/Session/LocalDropSessionController.mm
  Browser/DragDrop/Session/LocalDropSupportResolver.h
  Browser/DragDrop/Session/LocalDropSupportResolver.mm
  Browser/Navigation/StableURLs/LocalServiceURLClassifier.h
  Browser/Navigation/StableURLs/LocalServiceURLClassifier.mm
  Browser/Modules/Core/ModuleActionService.h
  Browser/Modules/Core/ModuleActionService.mm
  Browser/InternalPages/Modules/ModuleInternalPageHTMLBuilder.h
  Browser/InternalPages/Modules/ModuleInternalPageHTMLBuilder.mm
  Browser/Modules/Lifecycle/ModuleLifecycleDispatcher.h
  Browser/Modules/Lifecycle/ModuleLifecycleDispatcher.mm
  Browser/Modules/Navigation/ModuleNavigationURLResolver.h
  Browser/Modules/Navigation/ModuleNavigationURLResolver.mm
  Browser/InternalPages/Modules/ModulePageRenderer.h
  Browser/InternalPages/Modules/ModulePageRenderer.mm
  Browser/InternalPages/Modules/ModuleSettingsPageRenderer.h
  Browser/InternalPages/Modules/ModuleSettingsPageRenderer.mm
  Browser/Modules/Navigation/ModuleSettingsRouteResolver.h
  Browser/Modules/Navigation/ModuleSettingsRouteResolver.mm
  Browser/Modules/Updates/ModuleUpdateService.h
  Browser/Modules/Updates/ModuleUpdateService.mm
  Browser/Modules/Navigation/ModuleUIActionCoordinator.h
  Browser/Modules/Navigation/ModuleUIActionCoordinator.mm
  Browser/Tabs/Creation/NewTabURLResolver.h
  Browser/Tabs/Creation/NewTabURLResolver.mm
  Browser/InternalPages/Rendering/NoViewerPageRenderer.h
  Browser/InternalPages/Rendering/NoViewerPageRenderer.mm
  Browser/Address/Suggestions/OmniboxLocalSuggestionBuilder.h
  Browser/Address/Suggestions/OmniboxLocalSuggestionBuilder.mm
  Browser/Address/Suggestions/OmniboxSuggestionContextBuilder.h
  Browser/Address/Suggestions/OmniboxSuggestionContextBuilder.mm
  Browser/Address/Suggestions/OmniboxSuggestionsController.h
  Browser/Address/Suggestions/OmniboxSuggestionsController.mm
  Browser/Modules/Projects/ProjectLauncherJSONImporter.h
  Browser/Modules/Projects/ProjectLauncherJSONImporter.mm
  Browser/Modules/Lifecycle/ProjectLifecycleResponseParser.h
  Browser/Modules/Lifecycle/ProjectLifecycleResponseParser.mm
  Browser/Tabs/Closing/RecentlyClosedTabStore.h
  Browser/Tabs/Closing/RecentlyClosedTabStore.mm
  Browser/Navigation/Refresh/RuntimeRefreshCoordinator.h
  Browser/Navigation/Refresh/RuntimeRefreshCoordinator.mm
  Browser/Navigation/Refresh/RuntimeRefreshTabMatcher.h
  Browser/Navigation/Refresh/RuntimeRefreshTabMatcher.mm
  Browser/InternalPages/Rendering/SettingsOptionRenderer.h
  Browser/InternalPages/Rendering/SettingsOptionRenderer.mm
  Browser/Window/Layout/SidebarLayoutCalculator.h
  Browser/Window/Layout/SidebarLayoutCalculator.mm
  Browser/Navigation/StableURLs/StableServerURLResolver.h
  Browser/Navigation/StableURLs/StableServerURLResolver.mm
  Browser/Navigation/StableURLs/StableURLTabReloader.h
  Browser/Navigation/StableURLs/StableURLTabReloader.mm
  Browser/Navigation/StableURLs/StableViewerURLResolver.h
  Browser/Navigation/StableURLs/StableViewerURLResolver.mm
  Browser/Tabs/UI/TabContentViewAttacher.h
  Browser/Tabs/UI/TabContentViewAttacher.mm
  Browser/Tabs/Closing/TabDefaultPageResetter.h
  Browser/Tabs/Closing/TabDefaultPageResetter.mm
  Browser/Tabs/Movement/TabDragCoordinator.h
  Browser/Tabs/Movement/TabDragCoordinator.mm
  Browser/Tabs/Movement/TabDragHoverScheduler.h
  Browser/Tabs/Movement/TabDragHoverScheduler.mm
  Browser/Tabs/Creation/TabPlacementPolicy.h
  Browser/Tabs/Creation/TabPlacementPolicy.mm
  Browser/Tabs/UI/TabStripLayoutCalculator.h
  Browser/Tabs/UI/TabStripLayoutCalculator.mm
  Browser/Tabs/UI/TabURLMatcher.h
  Browser/Tabs/UI/TabURLMatcher.mm
  Browser/Navigation/Viewer/ViewerSourceResolver.h
  Browser/Navigation/Viewer/ViewerSourceResolver.mm
  Browser/Navigation/Viewer/ViewerSourceActionHandler.h
  Browser/Navigation/Viewer/ViewerSourceActionHandler.mm
  Browser/Navigation/Viewer/ViewerNavigationURLResolver.h
  Browser/Navigation/Viewer/ViewerNavigationURLResolver.mm
  Browser/State/Sessions/WindowStateStore.h
  Browser/State/Sessions/WindowStateStore.mm
  Browser/Window/Layout/MainWindowViewFactory.h
  Browser/Window/Layout/MainWindowViewFactory.mm
  Browser/UI/Models/BrowserModels.h
  Browser/UI/Models/BrowserModels.mm
  Browser/Navigation/Browser/BrowserNavigationController.h
  Browser/Navigation/Browser/BrowserNavigationController.mm
  Browser/UI/Formatting/BrowserPresentationFormatter.h
  Browser/UI/Formatting/BrowserPresentationFormatter.mm
  Browser/UI/Views/BrowserSupportViews.h
  Browser/UI/Views/BrowserSupportViews.mm
  Browser/UI/Theme/BrowserTheme.h
  Browser/UI/Theme/BrowserTheme.mm
  Browser/UI/Views/BrowserViews.h
  Browser/UI/Views/BrowserViews.mm
  Browser/DeveloperTools/Docking/DeveloperToolsDockingStore.h
  Browser/DeveloperTools/Docking/DeveloperToolsDockingStore.mm
  Browser/DeveloperTools/Docking/DeveloperToolsDockingPolicy.h
  Browser/DeveloperTools/Docking/DeveloperToolsDockingPolicy.mm
  Browser/DeveloperTools/Layout/DeveloperToolsLayoutCalculator.h
  Browser/DeveloperTools/Layout/DeveloperToolsLayoutCalculator.mm
  Browser/DeveloperTools/Panel/DeveloperToolsPanelController.h
  Browser/DeveloperTools/Panel/DeveloperToolsPanelController.mm
  Browser/DeveloperTools/Targeting/DeveloperToolsTargetResolver.h
  Browser/DeveloperTools/Targeting/DeveloperToolsTargetResolver.mm
  Browser/Window/Controller/BrowserWindowController.h
  Browser/Window/Controller/BrowserWindowController.mm
  Browser/Window/Actions/Address/BabelBrowserWindowAddressAndSuggestionsActions.h
  Browser/Window/Actions/Address/BabelBrowserWindowAddressAndSuggestionsActions.mm
  Browser/Window/Actions/Browser/BabelBrowserWindowBrowserAttachmentActions.h
  Browser/Window/Actions/Browser/BabelBrowserWindowBrowserAttachmentActions.mm
  Browser/Window/Actions/Browser/BabelBrowserWindowBrowserControlsActions.h
  Browser/Window/Actions/Browser/BabelBrowserWindowBrowserControlsActions.mm
  Browser/Window/Actions/DeveloperTools/BabelBrowserWindowDeveloperToolsActions.h
  Browser/Window/Actions/DeveloperTools/BabelBrowserWindowDeveloperToolsActions.mm
  Browser/Window/Actions/Groups/BabelBrowserWindowGroupsAndTabsActions.h
  Browser/Window/Actions/Groups/BabelBrowserWindowGroupsAndTabsActions.mm
  Browser/Window/Actions/InternalPages/BabelBrowserWindowInternalPagesActions.h
  Browser/Window/Actions/InternalPages/BabelBrowserWindowInternalPagesActions.mm
  Browser/Window/Actions/DragDrop/BabelBrowserWindowLocalDropActions.h
  Browser/Window/Actions/DragDrop/BabelBrowserWindowLocalDropActions.mm
  Browser/Window/Actions/Navigation/BabelBrowserWindowURLRoutingActions.h
  Browser/Window/Actions/Navigation/BabelBrowserWindowURLRoutingActions.mm
  Browser/Window/Actions/Lifecycle/BabelBrowserWindowLifecycleActions.h
  Browser/Window/Actions/Lifecycle/BabelBrowserWindowLifecycleActions.mm
  Browser/Window/Controller/BrowserWindowControllerPrivate.h
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
