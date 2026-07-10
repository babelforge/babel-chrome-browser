#ifndef BABEL_CHROME_BROWSER_MODULES_SETTINGS_NATIVE_MODULE_REQUIRED_SETTINGS_SERVICE_H_
#define BABEL_CHROME_BROWSER_MODULES_SETTINGS_NATIVE_MODULE_REQUIRED_SETTINGS_SERVICE_H_

#import <Foundation/Foundation.h>

@class BabelNativeModuleManifest;

/**
 * Validates and persists host-rendered settings required before a module runtime can start.
 */
@interface BabelNativeModuleRequiredSettingsService : NSObject

/**
 * Creates a required settings service backed by user defaults.
 *
 * @param userDefaults The user defaults storage.
 * @return The initialized service.
 */
- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults;

/**
 * Returns the current required settings status for a module.
 *
 * @param module The module manifest.
 * @return A serializable status dictionary.
 */
- (NSDictionary*)statusForModule:(BabelNativeModuleManifest*)module;

/**
 * Returns whether all required settings are valid for a module.
 *
 * @param module The module manifest.
 * @return YES when the module can start.
 */
- (BOOL)requiredSettingsAreSatisfiedForModule:(BabelNativeModuleManifest*)module;

/**
 * Persists one required setting value after validation.
 *
 * @param value The value to persist.
 * @param key The required setting key.
 * @param module The module manifest.
 * @param error The optional error pointer.
 * @return YES when the value was persisted.
 */
- (BOOL)setValue:(NSString*)value
          forKey:(NSString*)key
          module:(BabelNativeModuleManifest*)module
           error:(NSError**)error;

/**
 * Returns resolved required setting values for command interpolation.
 *
 * @param module The module manifest.
 * @return A dictionary keyed by manifest required setting keys.
 */
- (NSDictionary<NSString*, NSString*>*)resolvedValuesForModule:(BabelNativeModuleManifest*)module;

/**
 * Returns environment variables exposing resolved setting values to a module runtime.
 *
 * @param module The module manifest.
 * @return A dictionary of environment variables.
 */
- (NSDictionary<NSString*, NSString*>*)runtimeEnvironmentForModule:(BabelNativeModuleManifest*)module;

/**
 * Returns a settings URL for a module with missing runtime settings.
 *
 * @param module The module manifest.
 * @return The stable module settings URL.
 */
- (NSURL*)settingsURLForModule:(BabelNativeModuleManifest*)module;

@end

#endif
