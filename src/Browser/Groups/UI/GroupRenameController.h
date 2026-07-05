#ifndef BABEL_CHROME_BROWSER_GROUP_RENAME_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_GROUP_RENAME_CONTROLLER_H_

#import <Foundation/Foundation.h>

/**
 * Presents native UI for group rename operations.
 */
@interface BabelGroupRenameController : NSObject

/**
 * Prompts the user for a replacement group name.
 *
 * @param currentName The current group name.
 *
 * @return The trimmed replacement name, or nil when the rename is cancelled.
 */
- (NSString*)promptForGroupNameWithCurrentName:(NSString*)currentName;

/**
 * Shows a duplicate group name warning.
 *
 * @param groupName The duplicate group name.
 */
- (void)showDuplicateNameAlertForGroupName:(NSString*)groupName;

@end

#endif
