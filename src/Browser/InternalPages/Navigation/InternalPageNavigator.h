#ifndef BABEL_CHROME_BROWSER_INTERNAL_PAGE_NAVIGATOR_H_
#define BABEL_CHROME_BROWSER_INTERNAL_PAGE_NAVIGATOR_H_

#import <Cocoa/Cocoa.h>

#include "include/cef_browser.h"

@class BabelBrowserGroup;
@class BabelBrowserTab;
@class BabelTabContentViewAttacher;

typedef BabelBrowserTab* (^BabelInternalPageBrowserTabProvider)(CefRefPtr<CefBrowser> browser);
typedef BabelBrowserGroup* (^BabelInternalPageDefaultGroupProvider)(void);
typedef BabelBrowserTab* (^BabelInternalPageExistingTabProvider)(NSString* urlString, BabelBrowserGroup* group);
typedef BabelBrowserTab* (^BabelInternalPageTabFactoryBlock)(NSString* urlString, NSString* identifier, NSString* title);
typedef NSString* (^BabelInternalPageHTMLDataURLBuilderBlock)(NSString* html);
typedef NSString* (^BabelInternalPageCompactTitleBlock)(NSString* title);
typedef void (^BabelInternalPageGroupHandler)(BabelBrowserGroup* group);
typedef void (^BabelInternalPageTabHandler)(BabelBrowserTab* tab);
typedef void (^BabelInternalPageVoidHandler)(void);

/**
 * Opens BabelChrome internal HTML pages in existing or new tabs.
 */
@interface BabelInternalPageNavigator : NSObject

/**
 * Creates an internal page navigator.
 *
 * @param pagesPanel The panel containing tab content views.
 * @param tabContentViewAttacher The service used to attach tab views.
 * @param browserTabProvider The block resolving a browser to a tab.
 * @param defaultGroupProvider The block resolving the target default group.
 * @param existingTabProvider The block finding an existing internal tab.
 * @param tabFactoryBlock The block creating a native tab.
 * @param dataURLBuilderBlock The block converting HTML to a data URL.
 * @param compactTitleBlock The block compacting tab titles.
 * @param selectGroupHandler The callback selecting a group.
 * @param selectTabHandler The callback selecting a tab.
 * @param showWindowHandler The callback showing the main window.
 * @param saveStateHandler The callback persisting groups.
 * @return The initialized navigator.
 */
- (instancetype)initWithPagesPanel:(NSView*)pagesPanel
             tabContentViewAttacher:(BabelTabContentViewAttacher*)tabContentViewAttacher
                 browserTabProvider:(BabelInternalPageBrowserTabProvider)browserTabProvider
                defaultGroupProvider:(BabelInternalPageDefaultGroupProvider)defaultGroupProvider
                existingTabProvider:(BabelInternalPageExistingTabProvider)existingTabProvider
                    tabFactoryBlock:(BabelInternalPageTabFactoryBlock)tabFactoryBlock
                 dataURLBuilderBlock:(BabelInternalPageHTMLDataURLBuilderBlock)dataURLBuilderBlock
                   compactTitleBlock:(BabelInternalPageCompactTitleBlock)compactTitleBlock
                   selectGroupHandler:(BabelInternalPageGroupHandler)selectGroupHandler
                     selectTabHandler:(BabelInternalPageTabHandler)selectTabHandler
                    showWindowHandler:(BabelInternalPageVoidHandler)showWindowHandler
                     saveStateHandler:(BabelInternalPageVoidHandler)saveStateHandler;

/**
 * Opens an internal page.
 *
 * @param internalURLString The stable internal page URL.
 * @param title The tab title.
 * @param html The page HTML.
 * @param browser The browser that should navigate in-place, or null.
 */
- (void)openInternalPageWithURLString:(NSString*)internalURLString
                                title:(NSString*)title
                                 html:(NSString*)html
                              browser:(CefRefPtr<CefBrowser>)browser;

@end

#endif
