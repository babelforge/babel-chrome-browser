#ifndef BABEL_CHROME_BROWSER_GROUP_SELECTION_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_GROUP_SELECTION_CONTROLLER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelBrowserTabCollection;
@class NSView;

typedef BabelBrowserTab* (^BabelGroupSelectionDraggingTabProvider)(void);
typedef void (^BabelGroupSelectionTabHandler)(BabelBrowserTab* tab);
typedef void (^BabelGroupSelectionGroupHandler)(BabelBrowserGroup* group);
typedef void (^BabelGroupSelectionVisibleTabsHandler)(NSMutableArray<BabelBrowserTab*>* tabs);
typedef void (^BabelGroupSelectionVoidHandler)(void);

/**
 * Coordinates switching the visible browser group in the main window.
 */
@interface BabelBrowserGroupSelectionController : NSObject

/**
 * Creates a group selection controller.
 *
 * @param groups The ordered browser groups.
 * @param tabsItemsPanel The tab strip items panel.
 * @param tabCollection The tab lookup service.
 * @param draggingTabProvider The provider for the tab currently being dragged.
 * @param visibleTabsHandler The callback used to publish visible tabs.
 * @param selectedGroupHandler The callback used to publish the selected group.
 * @param selectedTabHandler The callback used to publish a nil selected tab when no tab exists.
 * @param selectTabHandler The callback used to select an existing tab.
 * @param clearAddressHandler The callback used when a group has no tabs.
 * @param updateWindowTitleHandler The callback used when a group has no tabs.
 * @param layoutTabsHandler The callback used to layout tab items.
 * @param layoutGroupsHandler The callback used to layout group items.
 * @return The initialized controller.
 */
- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                tabsItemsPanel:(NSView*)tabsItemsPanel
                 tabCollection:(BabelBrowserTabCollection*)tabCollection
           draggingTabProvider:(BabelGroupSelectionDraggingTabProvider)draggingTabProvider
            visibleTabsHandler:(BabelGroupSelectionVisibleTabsHandler)visibleTabsHandler
          selectedGroupHandler:(BabelGroupSelectionGroupHandler)selectedGroupHandler
            selectedTabHandler:(BabelGroupSelectionTabHandler)selectedTabHandler
              selectTabHandler:(BabelGroupSelectionTabHandler)selectTabHandler
            clearAddressHandler:(BabelGroupSelectionVoidHandler)clearAddressHandler
       updateWindowTitleHandler:(BabelGroupSelectionVoidHandler)updateWindowTitleHandler
             layoutTabsHandler:(BabelGroupSelectionVoidHandler)layoutTabsHandler
            layoutGroupsHandler:(BabelGroupSelectionVoidHandler)layoutGroupsHandler;

/**
 * Selects a browser group and updates visible tab views.
 *
 * @param group The group to select.
 */
- (void)selectGroup:(BabelBrowserGroup*)group;

@end

#endif
