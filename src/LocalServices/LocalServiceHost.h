#ifndef BABEL_CHROME_LOCAL_SERVICES_LOCAL_SERVICE_HOST_H_
#define BABEL_CHROME_LOCAL_SERVICES_LOCAL_SERVICE_HOST_H_

#import <Foundation/Foundation.h>

/**
 * Starts and owns the local PHP service used by built-in file viewers.
 */
@interface BabelLocalServiceHost : NSObject

/**
 * Returns the shared local service host.
 *
 * @return The shared host instance.
 */
+ (instancetype)sharedHost;

/**
 * Starts the local service when needed.
 *
 * @param error Receives startup errors.
 * @return YES when the service is running.
 */
- (BOOL)startIfNeededWithError:(NSError**)error;

/**
 * Stops the local service when it is running.
 */
- (void)stop;

/**
 * Returns whether the local viewer service supports the URL.
 *
 * @param url The URL to check.
 * @return YES when a built-in viewer can open the URL.
 */
- (BOOL)supportsURL:(NSURL*)url;

/**
 * Returns whether the local viewer service supports the file URL.
 *
 * @param fileURL The local file URL.
 * @return YES when a built-in viewer can open the file.
 */
- (BOOL)supportsFileURL:(NSURL*)fileURL;

/**
 * Returns the viewer kind that supports a URL.
 *
 * @param url The original URL.
 * @return The viewer route host when supported, otherwise nil.
 */
- (NSString*)viewerKindForURL:(NSURL*)url;

/**
 * Returns the address badge metadata contributed by the module handling a URL.
 *
 * @param url The user-facing URL.
 * @return A badge metadata dictionary, otherwise nil.
 */
- (NSDictionary*)addressBadgeForURL:(NSURL*)url;

/**
 * Returns the viewer URL for a supported URL.
 *
 * @param url The original URL.
 * @return A local service URL when a viewer supports the URL, otherwise nil.
 */
- (NSURL*)viewerURLForURL:(NSURL*)url;

/**
 * Returns the viewer URL for a local file URL.
 *
 * @param fileURL The local file URL.
 * @return A local service URL when a viewer supports the file, otherwise nil.
 */
- (NSURL*)viewerURLForFileURL:(NSURL*)fileURL;

/**
 * Returns registered PHP modules from the local service.
 *
 * @param error Receives request or decoding errors.
 * @return A decoded JSON dictionary, otherwise nil.
 */
- (NSDictionary*)modulesSnapshotWithError:(NSError**)error;

/**
 * Returns the HTTP header value that advertises file types handled by enabled modules.
 *
 * @param error Receives request or decoding errors.
 * @return A comma-separated header value, otherwise nil.
 */
- (NSString*)fileTypeHeaderValueWithError:(NSError**)error;

/**
 * Dispatches one application lifecycle hook to installed PHP modules.
 *
 * @param hook The lifecycle hook name.
 * @param error Receives request or decoding errors.
 * @return A decoded JSON dictionary, otherwise nil.
 */
- (NSDictionary*)dispatchModuleLifecycleHook:(NSString*)hook error:(NSError**)error;

/**
 * Returns a local service URL for an installed PHP module route.
 *
 * @param moduleIdentifier The module identifier.
 * @param route The module route.
 * @param error Receives startup or URL creation errors.
 * @return A local service URL, otherwise nil.
 */
- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                           error:(NSError**)error;

/**
 * Returns a local service URL for an installed PHP module route and forwards the original URL.
 *
 * @param moduleIdentifier The module identifier.
 * @param route The module route.
 * @param sourceURLString The original user-facing URL.
 * @param error Receives startup or URL creation errors.
 * @return A local service URL, otherwise nil.
 */
- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                 sourceURLString:(NSString*)sourceURLString
                           error:(NSError**)error;

/**
 * Installs a PHP module zip through the local service.
 *
 * @param zipPath The local zip archive path.
 * @param error Receives request or install errors.
 * @return A decoded JSON dictionary, otherwise nil.
 */
- (NSDictionary*)installModuleZipAtPath:(NSString*)zipPath error:(NSError**)error;

/**
 * Enables or disables a PHP module through the local service.
 *
 * @param moduleIdentifier The module identifier.
 * @param enabled Whether the module should be enabled.
 * @param error Receives request or update errors.
 * @return A decoded JSON dictionary, otherwise nil.
 */
- (NSDictionary*)setModuleWithIdentifier:(NSString*)moduleIdentifier
                                 enabled:(BOOL)enabled
                                   error:(NSError**)error;

/**
 * Removes a PHP module through the local service.
 *
 * @param moduleIdentifier The module identifier.
 * @param error Receives request or removal errors.
 * @return A decoded JSON dictionary, otherwise nil.
 */
- (NSDictionary*)removeModuleWithIdentifier:(NSString*)moduleIdentifier error:(NSError**)error;

@end

#endif
