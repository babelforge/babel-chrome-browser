#ifndef BABEL_CHROME_BROWSER_VIEWS_H_
#define BABEL_CHROME_BROWSER_VIEWS_H_

#import <Cocoa/Cocoa.h>

#include "include/cef_browser.h"

/**
 * Configures an AppKit button with a bundled SVG icon.
 *
 * @param button The button to configure.
 * @param resourceName The SVG resource name without extension.
 * @param fallbackTitle The title used when the SVG cannot be loaded.
 */
void ConfigureIconButton(NSButton* button, NSString* resourceName, NSString* fallbackTitle);

/**
 * Creates a BabelChrome button with hand cursor support.
 *
 * @param title The visible button title.
 * @param target The action target.
 * @param action The action selector.
 * @return The configured button.
 */
NSButton* BabelButton(NSString* title, id target, SEL action);

/**
 * Hosts the native CEF browser view and resizes it with AppKit layout.
 */
@interface BabelBrowserHostView : NSView

/**
 * Assigns the browser displayed by this host view.
 *
 * @param browser The browser to resize with the host view.
 */
- (void)setBrowser:(CefRefPtr<CefBrowser>)browser;

@end

/**
 * Owns one page surface and provides a stable place for page-level features.
 */
@interface BabelPageContainerView : NSView

@property(nonatomic, copy) BOOL (^canAcceptLocalDrop)(BabelPageContainerView* container);
@property(nonatomic, copy) void (^localDropHandler)(BabelPageContainerView* container);

/**
 * Assigns the browser displayed by this page container.
 *
 * @param browser The browser to display.
 */
- (void)setBrowser:(CefRefPtr<CefBrowser>)browser;

/**
 * Returns the browser displayed by this page container.
 *
 * @return The displayed browser.
 */
- (CefRefPtr<CefBrowser>)browser;

/**
 * Returns the last local file paths dropped on this page container.
 *
 * @return The dropped local file paths.
 */
- (NSArray<NSString*>*)localDropPaths;

@end

/**
 * Uses top-left coordinates for stacked AppKit list content.
 */
@interface BabelFlippedView : NSView

@end

/**
 * Tracks pointer drags on the split edge between the page and developer tools.
 */
@interface BabelDeveloperToolsResizeHandleView : NSView

@property(nonatomic, weak) id resizeTarget;
@property(nonatomic, assign) SEL resizeAction;
@property(nonatomic, assign) CGFloat dragDelta;

@end

/**
 * Draws a Safari-inspired tab item with a close control.
 */
@interface BabelTabItemView : NSControl

@property(nonatomic, strong) NSString* identifier;
@property(nonatomic, strong) NSString* title;
@property(nonatomic, strong) NSImage* faviconImage;
@property(nonatomic, strong) NSColor* accentColor;
@property(nonatomic, assign, getter=isSelected) BOOL selected;
@property(nonatomic, weak) id closeTarget;
@property(nonatomic, assign) SEL closeAction;
@property(nonatomic, weak) id dragTarget;
@property(nonatomic, assign) SEL dragAction;
@property(nonatomic, weak) id dragEndTarget;
@property(nonatomic, assign) SEL dragEndAction;

/**
 * Creates a tab item bound to a tab identifier.
 *
 * @param identifier The stable tab identifier.
 * @param title The visible tab title.
 * @return The initialized tab item.
 */
- (instancetype)initWithIdentifier:(NSString*)identifier title:(NSString*)title;

@end

/**
 * Draws a group selector item in the left panel.
 */
@interface BabelGroupItemView : NSControl

@property(nonatomic, strong) NSString* identifier;
@property(nonatomic, strong) NSString* title;
@property(nonatomic, strong) NSColor* accentColor;
@property(nonatomic, assign, getter=isSelected) BOOL selected;
@property(nonatomic, assign, getter=isCollapsed) BOOL collapsed;
@property(nonatomic, weak) id renameTarget;
@property(nonatomic, assign) SEL renameAction;
@property(nonatomic, weak) id deleteTarget;
@property(nonatomic, assign) SEL deleteAction;
@property(nonatomic, weak) id dragTarget;
@property(nonatomic, assign) SEL dragAction;
@property(nonatomic, weak) id dragEndTarget;
@property(nonatomic, assign) SEL dragEndAction;

/**
 * Creates a group selector item bound to a group identifier.
 *
 * @param identifier The stable group identifier.
 * @param title The visible group title.
 * @return The initialized group item.
 */
- (instancetype)initWithIdentifier:(NSString*)identifier title:(NSString*)title;

@end

#endif
