#ifndef BABEL_CHROME_BROWSER_TAB_DRAG_SESSION_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_TAB_DRAG_SESSION_CONTROLLER_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelBrowserTabCollection;
@class BabelBrowserTabMoveCoordinator;
@class BabelTabDragCoordinator;
@class BabelTabDragHoverScheduler;

typedef NSArray<BabelBrowserTab*>* (^BabelTabDragVisibleTabsProvider)(void);
typedef BabelBrowserGroup* (^BabelTabDragSelectedGroupProvider)(void);
typedef BabelBrowserTab* (^BabelTabDragTabLookupProvider)(NSString* identifier);
typedef NSString* (^BabelTabDragGroupNameProvider)(void);
typedef BabelBrowserGroup* (^BabelTabDragGroupCreateHandler)(NSString* groupName, NSString* identifier);
typedef void (^BabelTabDragGroupHandler)(BabelBrowserGroup* group);
typedef void (^BabelTabDragTabHandler)(BabelBrowserTab* tab);
typedef void (^BabelTabDragLayoutHandler)(void);
typedef void (^BabelTabDragSaveHandler)(void);

/**
 * Coordinates an active tab drag session across the tab strip and sidebar groups.
 */
@interface BabelBrowserTabDragSessionController : NSObject

/**
 * Returns the tab currently being dragged.
 */
@property(nonatomic, readonly) BabelBrowserTab* draggingTab;

/**
 * Creates a tab drag session controller.
 *
 * @param groups The ordered browser groups.
 * @param window The containing browser window.
 * @param groupsListView The sidebar group list view.
 * @param sidebarView The sidebar root view.
 * @param tabsItemsPanel The visible tab strip items panel.
 * @param tabCollection The service used to locate tab owners.
 * @param dragCoordinator The hit-testing and insertion-index service.
 * @param hoverScheduler The delayed group-selection scheduler.
 * @param moveCoordinator The tab move service.
 * @param visibleTabsProvider The visible tabs provider.
 * @param selectedGroupProvider The selected group provider.
 * @param tabLookupProvider The provider used to find a tab by identifier.
 * @param manualGroupNameProvider The provider used to name a new drop-created group.
 * @param groupCreateHandler The callback used to create a new group.
 * @param selectGroupHandler The callback used to select a group.
 * @param selectTabHandler The callback used to select a tab.
 * @param layoutTabsHandler The callback used to relayout visible tabs.
 * @param saveStateHandler The callback used to persist group state.
 * @param hoverDelayNanoseconds The group-hover delay while dragging.
 * @return The initialized controller.
 */
- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                         window:(NSWindow*)window
                 groupsListView:(NSView*)groupsListView
                    sidebarView:(NSView*)sidebarView
                 tabsItemsPanel:(NSView*)tabsItemsPanel
                  tabCollection:(BabelBrowserTabCollection*)tabCollection
                dragCoordinator:(BabelTabDragCoordinator*)dragCoordinator
                 hoverScheduler:(BabelTabDragHoverScheduler*)hoverScheduler
                moveCoordinator:(BabelBrowserTabMoveCoordinator*)moveCoordinator
            visibleTabsProvider:(BabelTabDragVisibleTabsProvider)visibleTabsProvider
          selectedGroupProvider:(BabelTabDragSelectedGroupProvider)selectedGroupProvider
              tabLookupProvider:(BabelTabDragTabLookupProvider)tabLookupProvider
        manualGroupNameProvider:(BabelTabDragGroupNameProvider)manualGroupNameProvider
             groupCreateHandler:(BabelTabDragGroupCreateHandler)groupCreateHandler
             selectGroupHandler:(BabelTabDragGroupHandler)selectGroupHandler
               selectTabHandler:(BabelTabDragTabHandler)selectTabHandler
              layoutTabsHandler:(BabelTabDragLayoutHandler)layoutTabsHandler
               saveStateHandler:(BabelTabDragSaveHandler)saveStateHandler
          hoverDelayNanoseconds:(int64_t)hoverDelayNanoseconds;

/**
 * Handles a drag update for a tab item.
 *
 * @param identifier The dragged tab identifier.
 */
- (void)dragTabWithIdentifier:(NSString*)identifier;

/**
 * Returns the group under a point expressed in window coordinates.
 *
 * @param windowPoint The point in window coordinates.
 * @return The group under the point, or nil.
 */
- (BabelBrowserGroup*)groupAtWindowPoint:(NSPoint)windowPoint;

/**
 * Returns whether a point is inside the sidebar.
 *
 * @param windowPoint The point in window coordinates.
 * @return YES when the point is inside the sidebar.
 */
- (BOOL)isWindowPointInsideSidebar:(NSPoint)windowPoint;

/**
 * Returns whether a point is inside the tab strip.
 *
 * @param windowPoint The point in window coordinates.
 * @return YES when the point is inside the tab strip.
 */
- (BOOL)isWindowPointInsideTabStrip:(NSPoint)windowPoint;

/**
 * Computes a tab insertion index from a tab-strip coordinate.
 *
 * @param x The X coordinate in tab-strip coordinates.
 * @return The insertion index.
 */
- (NSUInteger)tabInsertionIndexForTabStripX:(CGFloat)x;

/**
 * Finishes the current tab drag session.
 */
- (void)finishDraggingTab;

@end

#endif
