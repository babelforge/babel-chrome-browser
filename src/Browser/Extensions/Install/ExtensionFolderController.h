#ifndef BABEL_CHROME_BROWSER_EXTENSION_FOLDER_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_EXTENSION_FOLDER_CONTROLLER_H_

#import <Foundation/Foundation.h>

@class BabelExtensionProfileStore;

/**
 * Handles user-driven unpacked extension folder selection.
 */
@interface BabelExtensionFolderController : NSObject

/**
 * Creates an extension folder controller.
 *
 * @param extensionProfileStore The store used to persist selected extension folders.
 * @return The initialized extension folder controller.
 */
- (instancetype)initWithExtensionProfileStore:(BabelExtensionProfileStore*)extensionProfileStore;

/**
 * Opens a native folder picker and stores a valid unpacked extension folder.
 */
- (void)addUnpackedExtensionFromPanel;

@end

#endif
