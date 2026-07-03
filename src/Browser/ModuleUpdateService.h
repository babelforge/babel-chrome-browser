#ifndef BABEL_CHROME_BROWSER_MODULE_UPDATE_SERVICE_H_
#define BABEL_CHROME_BROWSER_MODULE_UPDATE_SERVICE_H_

#import <Foundation/Foundation.h>

/**
 * Resolves module update sources, manifests, local zip indexes, and update zip paths.
 */
@interface BabelModuleUpdateService : NSObject

/**
 * Creates a module update service.
 *
 * @param userDefaults The defaults storage used for update source preferences.
 * @param updateURLDefaultsKey The defaults key for the remote update URL.
 * @param updateLocalDirectoryDefaultsKey The defaults key for the local update folder.
 * @param localIndexFilePath The persisted local zip index file path.
 * @return The initialized module update service.
 */
- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults
                 updateURLDefaultsKey:(NSString*)updateURLDefaultsKey
       updateLocalDirectoryDefaultsKey:(NSString*)updateLocalDirectoryDefaultsKey
                    localIndexFilePath:(NSString*)localIndexFilePath;

/**
 * Returns the configured remote update URL string.
 *
 * @return The trimmed remote update URL string.
 */
- (NSString*)updateURLString;

/**
 * Persists the remote update URL string.
 *
 * @param updateURLString The remote update URL string. Empty values clear the preference.
 */
- (void)setUpdateURLString:(NSString*)updateURLString;

/**
 * Returns the configured local update folder path.
 *
 * @return The trimmed local update folder path.
 */
- (NSString*)localDirectoryPath;

/**
 * Persists the local update folder path.
 *
 * @param localDirectoryPath The local update folder path. Empty values clear the preference.
 */
- (void)setLocalDirectoryPath:(NSString*)localDirectoryPath;

/**
 * Loads the best available module update manifest result.
 *
 * @return A manifest result dictionary, or an error result dictionary.
 */
- (NSDictionary*)releaseManifestResult;

/**
 * Builds a lookup table from release modules.
 *
 * @param releaseModules The release module dictionaries.
 * @return A dictionary keyed by module identifier.
 */
- (NSDictionary*)releaseModulesByIdentifier:(NSArray*)releaseModules;

/**
 * Finds one release module in an update result.
 *
 * @param moduleIdentifier The module identifier.
 * @param updateResult The update result dictionary.
 * @return The release module dictionary, or nil when it is missing.
 */
- (NSDictionary*)releaseModuleWithIdentifier:(NSString*)moduleIdentifier
                                updateResult:(NSDictionary*)updateResult;

/**
 * Resolves or downloads the zip path for a release module.
 *
 * @param releaseModule The release module dictionary.
 * @param updateResult The update result dictionary.
 * @param error The optional error pointer.
 * @return The local zip path, or an empty string on failure.
 */
- (NSString*)resolvedUpdateZipPathForReleaseModule:(NSDictionary*)releaseModule
                                      updateResult:(NSDictionary*)updateResult
                                             error:(NSError**)error;

/**
 * Compares two version strings using numeric search.
 *
 * @param leftVersion The left version string.
 * @param rightVersion The right version string.
 * @return The version comparison result.
 */
- (NSComparisonResult)compareVersion:(NSString*)leftVersion toVersion:(NSString*)rightVersion;

@end

#endif
