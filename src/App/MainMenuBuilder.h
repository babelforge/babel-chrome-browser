#ifndef BABEL_CHROME_MAIN_MENU_BUILDER_H_
#define BABEL_CHROME_MAIN_MENU_BUILDER_H_

#import <Cocoa/Cocoa.h>

/**
 * Builds the native BabelChrome application menu.
 */
@interface BabelMainMenuBuilder : NSObject

/**
 * Installs the application main menu and routes menu actions to the target.
 *
 * @param target The menu action target.
 */
+ (void)installMainMenuWithTarget:(id)target;

@end

#endif
