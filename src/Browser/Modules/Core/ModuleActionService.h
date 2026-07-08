#ifndef BABEL_CHROME_BROWSER_MODULE_ACTION_SERVICE_H_
#define BABEL_CHROME_BROWSER_MODULE_ACTION_SERVICE_H_

#import <Foundation/Foundation.h>

/**
 * Executes PHP module registry actions through the local service host.
 */
@interface BabelModuleActionService : NSObject

/**
 * Returns the current module registry snapshot.
 *
 * @param error The optional error pointer.
 * @return The module registry snapshot, or nil on failure.
 */
- (NSDictionary*)modulesSnapshotWithError:(NSError**)error;

/**
 * Finds a module route matching BabelChrome URL components.
 *
 * @param components The URL components to match.
 * @param error The optional error pointer.
 * @return A route dictionary, or nil when no route matches.
 */
- (NSDictionary*)moduleRouteForBabelChromeComponents:(NSURLComponents*)components
                                               error:(NSError**)error;

/**
 * Returns the module identifier encoded in a runtime local service URL.
 *
 * @param components The URL components to inspect.
 * @return The module identifier, or nil when the URL is not a module runtime URL.
 */
- (NSString*)localServiceModuleIdentifierForURLComponents:(NSURLComponents*)components;

/**
 * Returns the default group name declared by a module.
 *
 * @param moduleIdentifier The module identifier.
 * @return The default group name, or nil when no group is declared.
 */
- (NSString*)defaultGroupNameForModuleIdentifier:(NSString*)moduleIdentifier;

/**
 * Installs or updates a PHP module zip.
 *
 * @param zipPath The module zip path.
 * @param error The optional error pointer.
 * @return YES when the module was installed.
 */
- (BOOL)installModuleZipAtPath:(NSString*)zipPath error:(NSError**)error;

/**
 * Updates a PHP module enabled state.
 *
 * @param moduleIdentifier The module identifier.
 * @param enabled YES to enable the module.
 * @param error The optional error pointer.
 * @return YES when the module state was updated.
 */
- (BOOL)setModuleWithIdentifier:(NSString*)moduleIdentifier enabled:(BOOL)enabled error:(NSError**)error;

/**
 * Removes a PHP module.
 *
 * @param moduleIdentifier The module identifier.
 * @param error The optional error pointer.
 * @return YES when the module was removed.
 */
- (BOOL)removeModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

/**
 * Runs a user-confirmed module setup command.
 *
 * @param moduleIdentifier The module identifier.
 * @param error The optional error pointer.
 * @return The setup response, or nil on failure.
 */
- (NSDictionary*)setupModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

@end

#endif
