#ifndef BABEL_CHROME_BABELBROWSERWINDOWDEVELOPERTOOLSACTIONS_H_
#define BABEL_CHROME_BABELBROWSERWINDOWDEVELOPERTOOLSACTIONS_H_

#import <Foundation/Foundation.h>

@class BabelBrowserWindowController;

/**
 * Handles one responsibility slice for the browser window controller.
 */
@interface BabelBrowserWindowDeveloperToolsActions : NSObject

/**
 * Creates the action handler.
 *
 * @param owner The owning browser window controller.
 * @return The initialized action handler.
 */
- (instancetype)initWithOwner:(BabelBrowserWindowController*)owner;

@end

#endif
