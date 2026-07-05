#ifndef BABEL_CHROME_BROWSER_CLOSED_TAB_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_CLOSED_TAB_CONTROLLER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelClosedTabReopenCoordinator;
@class BabelRecentlyClosedTabStore;
@class BabelTabContentViewAttacher;
@class BabelTabDefaultPageResetter;
@class NSView;

typedef NSArray<BabelBrowserTab*>* (^BabelClosedTabVisibleTabsProvider)(void);
typedef BabelBrowserGroup* (^BabelClosedTabSelectedGroupProvider)(void);
typedef BabelBrowserGroup* (^BabelClosedTabGroupLookupProvider)(NSString* identifier);
typedef BabelBrowserGroup* (^BabelClosedTabGroupCreateHandler)(NSString* name, NSString* identifier);
typedef BabelBrowserTab* (^BabelClosedTabCreateHandler)(NSString* urlString, NSString* identifier, NSString* title);
typedef void (^BabelClosedTabTabHandler)(BabelBrowserTab* tab);
typedef void (^BabelClosedTabGroupHandler)(BabelBrowserGroup* group);
typedef void (^BabelClosedTabVoidHandler)(void);

/**
 * Coordinates closing, resetting, and reopening browser tabs.
 */
@interface BabelBrowserClosedTabController : NSObject

/**
 * Creates a closed-tab controller.
 *
 * @param recentlyClosedTabStore The recently closed tab store.
 * @param closedTabReopenCoordinator The restoration plan coordinator.
 * @param tabDefaultPageResetter The default page resetter.
 * @param tabContentViewAttacher The native content view attacher.
 * @param pagesPanel The panel that owns page containers.
 * @param defaultGroupName The default group name used in restoration snapshots.
 * @param visibleTabsProvider The visible tab provider.
 * @param selectedGroupProvider The selected group provider.
 * @param groupLookupProvider The group lookup provider.
 * @param groupCreateHandler The group creation callback.
 * @param tabCreateHandler The native tab creation callback.
 * @param hideDeveloperToolsHandler The callback used before resetting a live tab.
 * @param removeSelectedGroupTabHandler The callback used to remove a tab from the selected group.
 * @param selectGroupHandler The callback used to select a group.
 * @param selectTabHandler The callback used to select a tab.
 * @param showWindowHandler The callback used to show the main window.
 * @param saveStateHandler The callback used to persist state.
 * @return The initialized controller.
 */
- (instancetype)initWithRecentlyClosedTabStore:(BabelRecentlyClosedTabStore*)recentlyClosedTabStore
                    closedTabReopenCoordinator:(BabelClosedTabReopenCoordinator*)closedTabReopenCoordinator
                       tabDefaultPageResetter:(BabelTabDefaultPageResetter*)tabDefaultPageResetter
                      tabContentViewAttacher:(BabelTabContentViewAttacher*)tabContentViewAttacher
                                  pagesPanel:(NSView*)pagesPanel
                            defaultGroupName:(NSString*)defaultGroupName
                         visibleTabsProvider:(BabelClosedTabVisibleTabsProvider)visibleTabsProvider
                       selectedGroupProvider:(BabelClosedTabSelectedGroupProvider)selectedGroupProvider
                         groupLookupProvider:(BabelClosedTabGroupLookupProvider)groupLookupProvider
                           groupCreateHandler:(BabelClosedTabGroupCreateHandler)groupCreateHandler
                             tabCreateHandler:(BabelClosedTabCreateHandler)tabCreateHandler
                   hideDeveloperToolsHandler:(BabelClosedTabTabHandler)hideDeveloperToolsHandler
               removeSelectedGroupTabHandler:(BabelClosedTabTabHandler)removeSelectedGroupTabHandler
                           selectGroupHandler:(BabelClosedTabGroupHandler)selectGroupHandler
                             selectTabHandler:(BabelClosedTabTabHandler)selectTabHandler
                            showWindowHandler:(BabelClosedTabVoidHandler)showWindowHandler
                             saveStateHandler:(BabelClosedTabVoidHandler)saveStateHandler;

/**
 * Closes the tab matching an item identifier.
 *
 * @param identifier The tab item identifier.
 */
- (void)closeTabWithIdentifier:(NSString*)identifier;

/**
 * Reopens the last recently closed tab.
 */
- (void)reopenLastClosedTab;

/**
 * Reopens a recently closed tab by stack index.
 *
 * @param closedTabIndex The closed tab stack index.
 */
- (void)reopenClosedTabAtIndex:(NSUInteger)closedTabIndex;

/**
 * Resets a tab to the default page.
 *
 * @param tab The tab to reset.
 */
- (void)resetTabToDefaultPage:(BabelBrowserTab*)tab;

@end

#endif
