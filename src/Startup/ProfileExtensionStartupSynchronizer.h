#ifndef BABEL_CHROME_PROFILE_EXTENSION_STARTUP_SYNCHRONIZER_H_
#define BABEL_CHROME_PROFILE_EXTENSION_STARTUP_SYNCHRONIZER_H_

#import <Foundation/Foundation.h>

/**
 * Synchronizes profile extension package directories before CEF starts.
 */
@interface BabelProfileExtensionStartupSynchronizer : NSObject

/**
 * Applies disabled extension state to the profile extension directories.
 */
+ (void)applyProfileExtensionPackageState;

@end

#endif
