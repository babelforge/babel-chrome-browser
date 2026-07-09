#ifndef BABEL_CHROME_BROWSER_MODULE_ACTION_SERVICE_H_
#define BABEL_CHROME_BROWSER_MODULE_ACTION_SERVICE_H_

#import <Foundation/Foundation.h>

/**
 * Coordinates module registry actions and native manifest metadata.
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
 * Returns a local runtime URL for one installed module route.
 *
 * @param moduleIdentifier The module identifier.
 * @param route The module route.
 * @param sourceURLString The original source URL to forward.
 * @param error The optional error pointer.
 * @return A local runtime URL, or nil when unavailable.
 */
- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                 sourceURLString:(NSString*)sourceURLString
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
 * Installs or updates a module zip.
 *
 * @param zipPath The module zip path.
 * @param error The optional error pointer.
 * @return YES when the module was installed.
 */
- (BOOL)installModuleZipAtPath:(NSString*)zipPath error:(NSError**)error;

/**
 * Updates a module enabled state.
 *
 * @param moduleIdentifier The module identifier.
 * @param enabled YES to enable the module.
 * @param error The optional error pointer.
 * @return YES when the module state was updated.
 */
- (BOOL)setModuleWithIdentifier:(NSString*)moduleIdentifier enabled:(BOOL)enabled error:(NSError**)error;

/**
 * Removes a module.
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

/**
 * Returns readiness diagnostics for one installed module.
 *
 * @param moduleIdentifier The module identifier.
 * @param error The optional error pointer.
 * @return The readiness status response, or nil on failure.
 */
- (NSDictionary*)readinessStatusForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

/**
 * Returns runtime diagnostics for one installed module.
 *
 * @param moduleIdentifier The module identifier.
 * @param error The optional error pointer.
 * @return The runtime status response, or nil on failure.
 */
- (NSDictionary*)runtimeStatusForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

/**
 * Restarts one module runtime when supported.
 *
 * @param moduleIdentifier The module identifier.
 * @param error The optional error pointer.
 * @return The restart response, or nil on failure.
 */
- (NSDictionary*)restartRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

/**
 * Stops one module runtime when supported.
 *
 * @param moduleIdentifier The module identifier.
 * @param error The optional error pointer.
 * @return The stop response, or nil on failure.
 */
- (NSDictionary*)stopRuntimeForModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

@end

#endif
