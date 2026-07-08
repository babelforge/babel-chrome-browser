#ifndef BABEL_CHROME_APPLICATION_DELEGATE_H_
#define BABEL_CHROME_APPLICATION_DELEGATE_H_

#import <Cocoa/Cocoa.h>

@class BabelBrowserWindowController;

/**
 * Receives macOS application events and routes URLs to the browser window.
 */
@interface BabelApplicationDelegate : NSObject <NSApplicationDelegate, NSUserInterfaceValidations>

/**
 * Initializes the delegate with no browser window.
 *
 * @return The initialized delegate.
 */
- (instancetype)init;

/**
 * Creates the main browser window after CEF is initialized.
 */
- (void)createBrowserWindow;

/**
 * Starts the temporary AppKit event collection loop used before CEF initialization.
 *
 * The delegate stops NSApp once the startup URL queue has been quiet long enough.
 */
- (void)beginStartupEventCollection;

/**
 * Requests orderly shutdown for the embedded browsers.
 */
- (void)tryToTerminateApplication;

/**
 * Handles the application quit command from the menu or Cmd+Q shortcut.
 *
 * @param sender The action sender.
 */
- (void)quitApplication:(id)sender;

/**
 * Shows the BabelChrome about window.
 *
 * @param sender The action sender.
 */
- (void)showAbout:(id)sender;

/**
 * Opens a new browser tab from a menu or keyboard shortcut.
 *
 * @param sender The action sender.
 */
- (void)newTab:(id)sender;

/**
 * Closes the active browser tab from a menu or keyboard shortcut.
 *
 * @param sender The action sender.
 */
- (void)closeTab:(id)sender;

/**
 * Opens developer tools for the active tab.
 *
 * @param sender The action sender.
 */
- (void)openDeveloperTools:(id)sender;

/**
 * Navigates the active tab back.
 *
 * @param sender The action sender.
 */
- (void)navigateBack:(id)sender;

/**
 * Navigates the active tab forward.
 *
 * @param sender The action sender.
 */
- (void)navigateForward:(id)sender;

/**
 * Reloads the active browser tab.
 *
 * @param sender The action sender.
 */
- (void)reloadTab:(id)sender;

/**
 * Reloads the active browser tab after bypassing HTTP cache.
 *
 * @param sender The action sender.
 */
- (void)reloadTabIgnoringCache:(id)sender;

/**
 * Routes a keyboard shortcut before CEF or the menu system can consume it.
 *
 * @param event The key event to inspect.
 * @return YES when the delegate handled the event.
 */
- (BOOL)handleApplicationShortcutEvent:(NSEvent*)event;

@end

#endif
