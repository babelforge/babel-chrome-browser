#ifndef BABEL_CHROME_BROWSER_SUPPORT_VIEWS_H_
#define BABEL_CHROME_BROWSER_SUPPORT_VIEWS_H_

#import <Cocoa/Cocoa.h>

#include "include/cef_browser.h"
#include "include/cef_callback.h"

/**
 * Reloads a browser without cache after an asynchronous cache clear operation.
 */
class BabelReloadIgnoreCacheCallback final : public CefCompletionCallback {
 public:
  /**
   * Creates a reload callback for a browser.
   *
   * @param browser The browser to reload after cache clearing completes.
   */
  explicit BabelReloadIgnoreCacheCallback(CefRefPtr<CefBrowser> browser);

  /**
   * Called by CEF when the cache clear operation completes.
   */
  void OnComplete() override;

 private:
  CefRefPtr<CefBrowser> browser_;

  IMPLEMENT_REFCOUNTING(BabelReloadIgnoreCacheCallback);
};

/**
 * Draws and handles one omnibox suggestion row.
 */
@interface BabelOmniboxSuggestionRowView : NSControl

@property(nonatomic, strong) NSTextField* titleLabel;
@property(nonatomic, strong) NSTextField* subtitleLabel;
@property(nonatomic, strong) NSImage* iconImage;
@property(nonatomic, assign, getter=isSuggestionHighlighted) BOOL suggestionHighlighted;

/**
 * Configures the suggestion row content.
 *
 * @param title The visible title.
 * @param subtitle The visible subtitle.
 * @param iconImage The optional icon image.
 */
- (void)configureWithTitle:(NSString*)title subtitle:(NSString*)subtitle iconImage:(NSImage*)iconImage;

@end

/**
 * Address text field that submits reliably on Return and Enter.
 */
@interface BabelAddressTextField : NSTextField

@end

/**
 * Root view that forwards appearance changes to a target action.
 */
@interface BabelThemeRootView : NSView

@property(nonatomic, weak) id themeTarget;
@property(nonatomic, assign) SEL themeAction;

@end

/**
 * Draws a compact badge inside the address field.
 */
@interface BabelBadgeLabel : NSView

@property(nonatomic, copy) NSString* settingsRoute;
@property(nonatomic, weak) id settingsTarget;
@property(nonatomic, assign) SEL settingsAction;

/**
 * Configures the badge text and colors.
 *
 * @param text The displayed badge text.
 * @param textColor The text color.
 * @param backgroundColor The badge background color.
 */
- (void)configureWithText:(NSString*)text
                textColor:(NSColor*)textColor
          backgroundColor:(NSColor*)backgroundColor;

@end

/**
 * Main application window that avoids unwanted off-screen constraints.
 */
@interface BabelMainWindow : NSWindow

/**
 * Receives browser-level keyboard shortcuts intercepted by the window.
 */
@property(nonatomic, weak) id browserShortcutTarget;

/**
 * Action used for Command+R.
 */
@property(nonatomic, assign) SEL reloadAction;

/**
 * Action used for Shift+Command+R.
 */
@property(nonatomic, assign) SEL reloadIgnoringCacheAction;

@end

#endif
