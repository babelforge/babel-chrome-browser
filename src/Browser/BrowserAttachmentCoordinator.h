#ifndef BABEL_CHROME_BROWSER_ATTACHMENT_COORDINATOR_H_
#define BABEL_CHROME_BROWSER_ATTACHMENT_COORDINATOR_H_

#import <Foundation/Foundation.h>

#include "include/cef_browser.h"

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelLiveBrowserEvictionPolicy;

typedef void (^BabelBrowserAttachmentTabHandler)(BabelBrowserTab* tab);
typedef void (^BabelBrowserAttachmentGroupHandler)(BabelBrowserGroup* group);
typedef void (^BabelBrowserAttachmentVoidHandler)(void);
typedef NSUInteger (^BabelBrowserAttachmentCountProvider)(void);

/**
 * Coordinates newly created and closed CEF browsers with native tab models.
 */
@interface BabelBrowserAttachmentCoordinator : NSObject

/**
 * Creates a browser attachment coordinator.
 *
 * @param groups The groups containing all tabs.
 * @param pendingTabs The queue of tabs waiting for a page browser.
 * @param evictionPolicy The policy tracking live browser eviction state.
 * @param selectGroupHandler The callback used to select a group.
 * @param removeTabHandler The callback used to remove a closed tab.
 * @param hideDeveloperToolsHandler The callback used to hide closed DevTools.
 * @param layoutDeveloperToolsHandler The callback used to layout embedded DevTools.
 * @param enforceLiveBrowserLimitHandler The callback used after attaching a page browser.
 * @param totalTabCountProvider The callback used to detect termination completion.
 * @return The initialized coordinator.
 */
- (instancetype)initWithGroups:(NSMutableArray<BabelBrowserGroup*>*)groups
                   pendingTabs:(NSMutableArray<BabelBrowserTab*>*)pendingTabs
                evictionPolicy:(BabelLiveBrowserEvictionPolicy*)evictionPolicy
            selectGroupHandler:(BabelBrowserAttachmentGroupHandler)selectGroupHandler
              removeTabHandler:(BabelBrowserAttachmentTabHandler)removeTabHandler
      hideDeveloperToolsHandler:(BabelBrowserAttachmentTabHandler)hideDeveloperToolsHandler
   layoutDeveloperToolsHandler:(BabelBrowserAttachmentTabHandler)layoutDeveloperToolsHandler
 enforceLiveBrowserLimitHandler:(BabelBrowserAttachmentVoidHandler)enforceLiveBrowserLimitHandler
         totalTabCountProvider:(BabelBrowserAttachmentCountProvider)totalTabCountProvider;

/**
 * Attaches a newly created page browser.
 *
 * @param browser The created browser.
 * @return YES when the browser was attached.
 */
- (BOOL)attachPageBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Attaches a newly created DevTools browser.
 *
 * @param browser The created browser.
 * @param tab The pending DevTools tab.
 * @return YES when the browser was attached.
 */
- (BOOL)attachDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser
                              toTab:(BabelBrowserTab*)tab;

/**
 * Detaches a closed browser from its owning tab.
 *
 * @param browser The closed browser.
 * @param selectedGroup The currently selected group.
 * @param isTerminating YES when the app is terminating.
 * @return YES when termination has closed the last tab and CEF may quit.
 */
- (BOOL)detachClosedBrowser:(CefRefPtr<CefBrowser>)browser
              selectedGroup:(BabelBrowserGroup*)selectedGroup
              isTerminating:(BOOL)isTerminating;

/**
 * Removes a tab from its group and native views.
 *
 * @param tab The tab to remove.
 * @param group The group that owns the tab.
 */
- (void)removeTab:(BabelBrowserTab*)tab fromGroup:(BabelBrowserGroup*)group;

@end

#endif
