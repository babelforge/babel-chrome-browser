#ifndef BABEL_CHROME_BROWSER_EXTENSION_PROFILE_STORE_H_
#define BABEL_CHROME_BROWSER_EXTENSION_PROFILE_STORE_H_

#import <Foundation/Foundation.h>

/**
 * Owns Chromium profile extension persistence and discovery.
 */
@interface BabelExtensionProfileStore : NSObject

/**
 * Creates an extension profile store.
 *
 * @param profileDirectoryURL The Chromium profile directory URL.
 * @param profileExtensionBackupDirectoryURL The backup directory URL for profile extensions.
 * @param userDefaults The user defaults storage used for BabelChrome extension state.
 * @param extensionPathsDefaultsKey The defaults key for unpacked extension paths.
 * @param disabledProfileExtensionIdentifiersDefaultsKey The defaults key for disabled profile extension identifiers.
 * @param pendingProfileExtensionRestartStatesDefaultsKey The defaults key for restart-pending extension states.
 * @return The initialized extension profile store.
 */
- (instancetype)initWithProfileDirectoryURL:(NSURL*)profileDirectoryURL
         profileExtensionBackupDirectoryURL:(NSURL*)profileExtensionBackupDirectoryURL
                               userDefaults:(NSUserDefaults*)userDefaults
                  extensionPathsDefaultsKey:(NSString*)extensionPathsDefaultsKey
disabledProfileExtensionIdentifiersDefaultsKey:(NSString*)disabledProfileExtensionIdentifiersDefaultsKey
pendingProfileExtensionRestartStatesDefaultsKey:(NSString*)pendingProfileExtensionRestartStatesDefaultsKey;

/**
 * Returns the configured unpacked extension paths.
 *
 * @return The valid configured extension paths.
 */
- (NSArray<NSString*>*)installedExtensionPaths;

/**
 * Persists the configured unpacked extension paths.
 *
 * @param extensionPaths The extension paths to persist.
 */
- (void)saveInstalledExtensionPaths:(NSArray<NSString*>*)extensionPaths;

/**
 * Returns installed Chromium profile extensions.
 *
 * @return The installed extension view dictionaries.
 */
- (NSArray<NSDictionary*>*)profileInstalledExtensions;

/**
 * Returns whether an extension identifier is syntactically valid for Chromium profile operations.
 *
 * @param extensionIdentifier The extension identifier to validate.
 * @return YES when the identifier is valid.
 */
- (BOOL)isValidProfileExtensionIdentifier:(NSString*)extensionIdentifier;

/**
 * Sets a Chromium profile extension enabled state.
 *
 * @param extensionIdentifier The profile extension identifier.
 * @param enabled YES to enable the extension, NO to disable it after restart.
 */
- (void)setProfileExtensionWithIdentifier:(NSString*)extensionIdentifier enabled:(BOOL)enabled;

/**
 * Removes a Chromium profile extension and its profile references.
 *
 * @param extensionIdentifier The profile extension identifier.
 */
- (void)removeProfileExtensionWithIdentifier:(NSString*)extensionIdentifier;

/**
 * Restores disabled profile extensions moved by older BabelChrome versions.
 */
- (void)restoreProfileExtensionsMovedByOlderVersions;

/**
 * Clears restart-pending profile extension state.
 */
- (void)clearPendingProfileExtensionRestartStates;

/**
 * Returns whether a profile extension has a pending restart state.
 *
 * @param extensionIdentifier The profile extension identifier.
 * @return YES when the extension has a pending restart state.
 */
- (BOOL)profileExtensionRequiresRestart:(NSString*)extensionIdentifier;

/**
 * Returns the display status label for a profile extension.
 *
 * @param extensionIdentifier The profile extension identifier.
 * @param enabled The currently detected enabled state.
 * @return The display status label.
 */
- (NSString*)profileExtensionStatusLabelForIdentifier:(NSString*)extensionIdentifier
                                              enabled:(BOOL)enabled;

@end

#endif
