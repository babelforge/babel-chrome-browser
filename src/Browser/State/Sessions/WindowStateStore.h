#ifndef BABEL_CHROME_BROWSER_WINDOW_STATE_STORE_H_
#define BABEL_CHROME_BROWSER_WINDOW_STATE_STORE_H_

#import <AppKit/AppKit.h>

/**
 * Persists and restores browser window and sidebar state.
 */
@interface BabelWindowStateStore : NSObject

/**
 * Creates a window state store.
 *
 * @param userDefaults The user defaults storage.
 * @return The initialized store.
 */
- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults;

/**
 * Returns the persisted sidebar collapsed state.
 *
 * @return YES when the sidebar should be collapsed.
 */
- (BOOL)restoredSidebarCollapsed;

/**
 * Persists the sidebar collapsed state.
 *
 * @param collapsed YES when the sidebar is collapsed.
 */
- (void)setSidebarCollapsed:(BOOL)collapsed;

/**
 * Returns the persisted expanded sidebar width constrained by UI bounds.
 *
 * @param defaultWidth The default width used when no value is persisted.
 * @param minimumWidth The minimum allowed width.
 * @param maximumWidth The maximum allowed width.
 * @return The restored expanded sidebar width.
 */
- (CGFloat)restoredExpandedSidebarWidthWithDefault:(CGFloat)defaultWidth
                                          minimum:(CGFloat)minimumWidth
                                          maximum:(CGFloat)maximumWidth;

/**
 * Persists the expanded sidebar width.
 *
 * @param width The width to persist.
 */
- (void)setExpandedSidebarWidth:(CGFloat)width;

/**
 * Restores the window frame.
 *
 * @param window The window to restore.
 */
- (void)restoreWindowFrame:(NSWindow*)window;

/**
 * Restores the zoom state when the persisted frame represents a visible-frame zoom.
 *
 * @param window The window to restore.
 */
- (void)restoreWindowZoomIfNeeded:(NSWindow*)window;

/**
 * Persists the current window placement and zoom state.
 *
 * @param window The window to persist.
 */
- (void)saveWindowState:(NSWindow*)window;

@end

#endif
