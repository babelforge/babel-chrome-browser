#ifndef BABEL_CHROME_BROWSER_MODULE_PAGE_RENDERER_H_
#define BABEL_CHROME_BROWSER_MODULE_PAGE_RENDERER_H_

#import <Foundation/Foundation.h>

/**
 * Renders module internal page bodies.
 */
@interface BabelModulePageRenderer : NSObject

/**
 * Creates a module page renderer.
 *
 * @param gearIconHTML The gear icon HTML used by the modules page.
 * @param trashIconHTML The trash icon HTML used by module removal buttons.
 * @return The initialized module page renderer.
 */
- (instancetype)initWithGearIconHTML:(NSString*)gearIconHTML trashIconHTML:(NSString*)trashIconHTML;

/**
 * Renders the modules page body.
 *
 * @param modules The installed module dictionaries.
 * @param error The optional snapshot error.
 * @param updateURLString The configured update URL string.
 * @param updateLocalDirectory The configured local update folder path.
 * @return The page body HTML.
 */
- (NSString*)modulesPageBodyWithModules:(NSArray*)modules
                                  error:(NSError*)error
                        updateURLString:(NSString*)updateURLString
                   updateLocalDirectory:(NSString*)updateLocalDirectory;

/**
 * Renders the module details page body.
 *
 * @param moduleIdentifier The requested module identifier.
 * @param modules The installed module dictionaries.
 * @param error The optional snapshot error.
 * @return The page body HTML.
 */
- (NSString*)moduleDetailsPageBodyForIdentifier:(NSString*)moduleIdentifier
                                        modules:(NSArray*)modules
                                          error:(NSError*)error;

/**
 * Renders the module updates page body.
 *
 * @param updateResult The update result dictionary.
 * @param releaseModulesByIdentifier The release modules keyed by identifier.
 * @param installedModules The installed module dictionaries.
 * @param snapshotError The optional installed modules snapshot error.
 * @param updateURLString The configured update URL string.
 * @param localDirectory The configured local update folder path.
 * @return The page body HTML.
 */
- (NSString*)moduleUpdatesPageBodyWithUpdateResult:(NSDictionary*)updateResult
                        releaseModulesByIdentifier:(NSDictionary*)releaseModulesByIdentifier
                                  installedModules:(NSArray*)installedModules
                                     snapshotError:(NSError*)snapshotError
                                   updateURLString:(NSString*)updateURLString
                                    localDirectory:(NSString*)localDirectory;

@end

#endif
