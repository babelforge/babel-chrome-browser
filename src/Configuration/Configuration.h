#ifndef BABEL_CHROME_CONFIGURATION_H_
#define BABEL_CHROME_CONFIGURATION_H_

#import <Foundation/Foundation.h>

/**
 * Defines static runtime configuration for the BabelChrome application.
 */
@interface BabelChromeConfiguration : NSObject

/**
 * Returns the display name used by menus, alerts, and window titles.
 *
 * @return The application display name.
 */
+ (NSString*)applicationName;

/**
 * Returns the isolated CEF profile directory.
 *
 * @return The profile directory URL.
 */
+ (NSURL*)profileDirectoryURL;

/**
 * Returns the Chromium disk cache root directory.
 *
 * @return The disk cache root directory URL.
 */
+ (NSURL*)diskCacheRootDirectoryURL;

/**
 * Returns the maximum Chromium HTTP disk cache size in bytes.
 *
 * @return The HTTP disk cache size string.
 */
+ (NSString*)httpDiskCacheSizeBytes;

/**
 * Returns the maximum Chromium media disk cache size in bytes.
 *
 * @return The media disk cache size string.
 */
+ (NSString*)mediaDiskCacheSizeBytes;

/**
 * Returns the directory used to preserve Chrome profile extension packages.
 *
 * @return The extension backup directory URL.
 */
+ (NSURL*)profileExtensionBackupDirectoryURL;

/**
 * Returns the persisted browser groups state file.
 *
 * @return The browser groups JSON file URL.
 */
+ (NSURL*)groupsStateFileURL;

/**
 * Returns the persisted favicon store file.
 *
 * @return The favicon JSON file URL.
 */
+ (NSURL*)faviconStoreFileURL;

/**
 * Returns the application support directory.
 *
 * @return The application support directory URL.
 */
+ (NSURL*)applicationSupportDirectoryURL;

/**
 * Returns the default page loaded when no URL is provided.
 *
 * @return The default page URL string.
 */
+ (NSString*)defaultURLString;

/**
 * Returns the local remote debugging port used by embedded developer tools.
 *
 * @return The remote debugging port.
 */
+ (int)remoteDebuggingPort;

/**
 * Returns the defaults key storing unpacked extension directory paths.
 *
 * @return The user defaults key.
 */
+ (NSString*)extensionPathsDefaultsKey;

/**
 * Returns the defaults key storing disabled Chrome profile extension identifiers.
 *
 * @return The user defaults key.
 */
+ (NSString*)disabledProfileExtensionIdentifiersDefaultsKey;

/**
 * Returns the defaults key storing extension state changes waiting for restart.
 *
 * @return The user defaults key.
 */
+ (NSString*)pendingProfileExtensionRestartStatesDefaultsKey;

@end

#endif
