#ifndef BABEL_CHROME_BROWSER_MODELS_H_
#define BABEL_CHROME_BROWSER_MODELS_H_

#import <Cocoa/Cocoa.h>

#include "include/cef_browser.h"

@class BabelBrowserHostView;
@class BabelPageContainerView;
@class BabelDeveloperToolsResizeHandleView;
@class BabelGroupItemView;
@class BabelTabItemView;

/**
 * Represents one tab in the native tab strip and one CEF browser.
 */
@interface BabelBrowserTab : NSObject

@property(nonatomic, strong) NSString* identifier;
@property(nonatomic, strong) NSString* title;
@property(nonatomic, strong) NSString* urlString;
@property(nonatomic, strong) NSString* requestedURLString;
@property(nonatomic, strong) NSString* parentTabIdentifier;
@property(nonatomic, strong) NSImage* faviconImage;
@property(nonatomic, strong) BabelTabItemView* tabItemView;
@property(nonatomic, strong) BabelPageContainerView* hostView;
@property(nonatomic, strong) NSView* developerToolsPanelView;
@property(nonatomic, strong) NSView* developerToolsToolbarView;
@property(nonatomic, strong) BabelBrowserHostView* developerToolsHostView;
@property(nonatomic, strong) BabelDeveloperToolsResizeHandleView* developerToolsResizeHandleView;
@property(nonatomic, strong) NSWindow* developerToolsSourceWindow;
@property(nonatomic, assign) BOOL developerToolsVisible;

/**
 * Assigns the CEF browser owned by the tab.
 *
 * @param browser The browser instance.
 */
- (void)setBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Returns the CEF browser owned by the tab.
 *
 * @return The browser instance.
 */
- (CefRefPtr<CefBrowser>)browser;

/**
 * Assigns the CEF developer tools browser owned by the tab.
 *
 * @param browser The developer tools browser instance.
 */
- (void)setDeveloperToolsBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Returns the CEF developer tools browser owned by the tab.
 *
 * @return The developer tools browser instance.
 */
- (CefRefPtr<CefBrowser>)developerToolsBrowser;

@end

/**
 * Represents one persisted group containing its own tab list.
 */
@interface BabelBrowserGroup : NSObject

@property(nonatomic, strong) NSString* identifier;
@property(nonatomic, strong) NSString* name;
@property(nonatomic, strong) NSMutableArray<BabelBrowserTab*>* tabs;
@property(nonatomic, strong) NSString* selectedTabIdentifier;
@property(nonatomic, strong) BabelGroupItemView* groupItemView;

@end

/**
 * Captures enough state to reopen a recently closed tab.
 */
@interface BabelClosedTab : NSObject

@property(nonatomic, strong) NSString* urlString;
@property(nonatomic, strong) NSString* requestedURLString;
@property(nonatomic, strong) NSString* title;
@property(nonatomic, strong) NSString* groupIdentifier;
@property(nonatomic, strong) NSString* groupName;

@end

#endif
