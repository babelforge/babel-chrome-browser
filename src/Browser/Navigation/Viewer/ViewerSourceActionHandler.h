#ifndef BABEL_CHROME_BROWSER_VIEWER_SOURCE_ACTION_HANDLER_H_
#define BABEL_CHROME_BROWSER_VIEWER_SOURCE_ACTION_HANDLER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserTab;
@class BabelViewerSourceResolver;

/**
 * Handles native actions for local viewer source files.
 */
@interface BabelViewerSourceActionHandler : NSObject

/**
 * Creates a viewer source action handler.
 *
 * @param viewerSourceResolver The resolver used to find source files.
 * @return The initialized handler.
 */
- (instancetype)initWithViewerSourceResolver:(BabelViewerSourceResolver*)viewerSourceResolver;

/**
 * Reports whether a viewer source file can be opened.
 *
 * @param tab The inspected browser tab.
 * @return YES when the source file exists.
 */
- (BOOL)canOpenViewerSourceForTab:(BabelBrowserTab*)tab;

/**
 * Opens the viewer source file in its default app.
 *
 * @param tab The inspected browser tab.
 */
- (void)openViewerSourceForTab:(BabelBrowserTab*)tab;

/**
 * Reveals the viewer source file in Finder.
 *
 * @param tab The inspected browser tab.
 */
- (void)revealViewerSourceForTab:(BabelBrowserTab*)tab;

@end

#endif
