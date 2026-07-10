#ifndef BABEL_CHROME_BROWSER_MODULES_REGISTRY_NATIVE_MODULE_MANIFEST_H_
#define BABEL_CHROME_BROWSER_MODULES_REGISTRY_NATIVE_MODULE_MANIFEST_H_

#import <Foundation/Foundation.h>

@class BabelNativeModuleProcessRuntimeDefinition;
@class BabelNativeModuleProcessWebDefinition;

/**
 * Represents one BabelChrome module manifest loaded by the native browser.
 */
@interface BabelNativeModuleManifest : NSObject

@property(nonatomic, readonly, copy) NSString* moduleIdentifier;
@property(nonatomic, readonly, copy) NSString* name;
@property(nonatomic, readonly, copy) NSString* version;
@property(nonatomic, readonly, copy) NSString* moduleDescription;
@property(nonatomic, readonly, copy) NSString* moduleType;
@property(nonatomic, readonly) BOOL enabled;
@property(nonatomic, readonly, copy) NSString* runtimeType;
@property(nonatomic, readonly, copy) NSString* path;
@property(nonatomic, readonly, copy) NSArray<NSDictionary*>* routes;
@property(nonatomic, readonly, copy) NSArray<NSString*>* fileTypes;
@property(nonatomic, readonly, copy) NSArray<NSString*>* fileNameContains;
@property(nonatomic, readonly, copy) NSArray<NSString*>* fileTypeHandlerFileTypes;
@property(nonatomic, readonly, copy) NSArray<NSString*>* hooks;
@property(nonatomic, readonly, copy) NSArray<NSString*>* permissions;
@property(nonatomic, readonly, copy) NSArray<NSDictionary*>* menuItems;
@property(nonatomic, readonly, strong) NSDictionary* badge;
@property(nonatomic, readonly, copy) NSString* settingsRoute;
@property(nonatomic, readonly, copy) NSString* defaultGroup;
@property(nonatomic, readonly, strong) NSDictionary* readiness;
@property(nonatomic, readonly, strong) NSDictionary* setup;
@property(nonatomic, readonly, strong) NSDictionary* runtime;
@property(nonatomic, readonly, strong) BabelNativeModuleProcessWebDefinition* processWeb;
@property(nonatomic, readonly, strong) BabelNativeModuleProcessRuntimeDefinition* processRuntime;
@property(nonatomic, readonly, strong) NSDictionary* requirements;
@property(nonatomic, readonly, strong) NSDictionary* requiredSettings;

/**
 * Creates a native module manifest from decoded JSON.
 *
 * @param data The decoded manifest JSON object.
 * @param modulePath The installed module root path.
 * @param error The optional error pointer.
 * @return The native manifest, or nil when the manifest is invalid.
 */
+ (instancetype)manifestWithDictionary:(NSDictionary*)data
                            modulePath:(NSString*)modulePath
                                 error:(NSError**)error;

/**
 * Exports this manifest to a dictionary compatible with existing module UI renderers.
 *
 * @return The serializable manifest dictionary.
 */
- (NSDictionary*)dictionaryRepresentation;

/**
 * Returns whether this module ships its own Composer vendor autoloader.
 *
 * @return YES when vendor/autoload.php exists in the module root.
 */
- (BOOL)hasIsolatedVendor;

@end

#endif
