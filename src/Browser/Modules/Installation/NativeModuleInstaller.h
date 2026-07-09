#ifndef BABEL_CHROME_BROWSER_MODULES_INSTALLATION_NATIVE_MODULE_INSTALLER_H_
#define BABEL_CHROME_BROWSER_MODULES_INSTALLATION_NATIVE_MODULE_INSTALLER_H_

#import <Foundation/Foundation.h>

/**
 * Installs, updates, enables, disables, and removes modules without using ExtensionHost.
 */
@interface BabelNativeModuleInstaller : NSObject

/**
 * Creates a native module installer for a specific modules directory.
 *
 * @param modulesDirectoryPath The directory that stores installed modules.
 * @return The native module installer.
 */
- (instancetype)initWithModulesDirectoryPath:(NSString*)modulesDirectoryPath;

/**
 * Installs or updates a module zip archive.
 *
 * @param zipPath The module zip archive path.
 * @param error The optional error pointer.
 * @return YES when the module was installed or updated.
 */
- (BOOL)installModuleZipAtPath:(NSString*)zipPath error:(NSError**)error;

/**
 * Updates an installed module enabled state.
 *
 * @param moduleIdentifier The module identifier.
 * @param enabled YES when the module should be enabled.
 * @param error The optional error pointer.
 * @return YES when the module manifest was updated.
 */
- (BOOL)setModuleWithIdentifier:(NSString*)moduleIdentifier
                        enabled:(BOOL)enabled
                          error:(NSError**)error;

/**
 * Removes an installed module directory.
 *
 * @param moduleIdentifier The module identifier.
 * @param error The optional error pointer.
 * @return YES when the module was removed.
 */
- (BOOL)removeModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

/**
 * Reads the module identifier declared inside a module zip archive.
 *
 * @param zipPath The module zip archive path.
 * @param error The optional error pointer.
 * @return The declared module identifier, or nil when it cannot be read.
 */
- (NSString*)moduleIdentifierInZipAtPath:(NSString*)zipPath error:(NSError**)error;

@end

#endif
