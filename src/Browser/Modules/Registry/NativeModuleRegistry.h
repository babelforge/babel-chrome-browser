#ifndef BABEL_CHROME_BROWSER_MODULES_REGISTRY_NATIVE_MODULE_REGISTRY_H_
#define BABEL_CHROME_BROWSER_MODULES_REGISTRY_NATIVE_MODULE_REGISTRY_H_

#import <Foundation/Foundation.h>

@class BabelNativeModuleManifest;

/**
 * Discovers installed BabelChrome modules from manifest.json files without using ExtensionHost.
 */
@interface BabelNativeModuleRegistry : NSObject

/**
 * Creates a registry that scans the default user modules directory.
 *
 * @return The native module registry.
 */
- (instancetype)init;

/**
 * Creates a registry that scans a specific user modules directory.
 *
 * @param modulesDirectoryPath The modules directory path.
 * @return The native module registry.
 */
- (instancetype)initWithModulesDirectoryPath:(NSString*)modulesDirectoryPath;

/**
 * Returns the resolved user modules directory path.
 *
 * @return The user modules directory path.
 */
- (NSString*)modulesDirectoryPath;

/**
 * Clears cached module manifests.
 */
- (void)reload;

/**
 * Returns all discovered module manifests sorted by identifier.
 *
 * @param error The optional error pointer.
 * @return The discovered manifests, or nil when a manifest cannot be loaded.
 */
- (NSArray<BabelNativeModuleManifest*>*)allModulesWithError:(NSError**)error;

/**
 * Returns enabled discovered module manifests sorted by identifier.
 *
 * @param error The optional error pointer.
 * @return The enabled manifests, or nil when a manifest cannot be loaded.
 */
- (NSArray<BabelNativeModuleManifest*>*)enabledModulesWithError:(NSError**)error;

/**
 * Finds one module by identifier.
 *
 * @param moduleIdentifier The module identifier.
 * @param error The optional error pointer.
 * @return The matching manifest, or nil when not found or when discovery fails.
 */
- (BabelNativeModuleManifest*)moduleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

/**
 * Returns a dictionary snapshot compatible with the existing modules page renderer.
 *
 * @param error The optional error pointer.
 * @return The module snapshot dictionary, or nil when discovery fails.
 */
- (NSDictionary*)modulesSnapshotWithError:(NSError**)error;

/**
 * Returns the HTTP header value that advertises enabled file-type handlers.
 *
 * @param error The optional error pointer.
 * @return The comma-separated file type list.
 */
- (NSString*)fileTypeHeaderValueWithError:(NSError**)error;

/**
 * Returns the enabled viewer route that should handle a source URL.
 *
 * @param url The source URL.
 * @param error The optional error pointer.
 * @return A viewer route dictionary, or nil when no enabled viewer handles the URL.
 */
- (NSDictionary*)viewerRouteForURL:(NSURL*)url error:(NSError**)error;

/**
 * Returns the enabled viewer route that should handle a source URL, optionally constrained to one viewer kind.
 *
 * @param url The source URL.
 * @param preferredViewerKind The requested viewer route host, or nil for generic viewer resolution.
 * @param error The optional error pointer.
 * @return A viewer route dictionary, or nil when no enabled viewer handles the URL.
 */
- (NSDictionary*)viewerRouteForURL:(NSURL*)url
               preferredViewerKind:(NSString*)preferredViewerKind
                              error:(NSError**)error;

/**
 * Returns the address badge metadata for a source URL handled by a viewer.
 *
 * @param url The source URL.
 * @param error The optional error pointer.
 * @return The badge metadata, or nil when no enabled viewer exposes one.
 */
- (NSDictionary*)addressBadgeForViewerURL:(NSURL*)url error:(NSError**)error;

@end

#endif
