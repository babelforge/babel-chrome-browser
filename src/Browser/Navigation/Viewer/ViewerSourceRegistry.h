#ifndef BABEL_CHROME_BROWSER_NAVIGATION_VIEWER_SOURCE_REGISTRY_H_
#define BABEL_CHROME_BROWSER_NAVIGATION_VIEWER_SOURCE_REGISTRY_H_

#import <Foundation/Foundation.h>

/**
 * Stores source references shared by BabelChrome and viewer modules.
 */
@interface BabelViewerSourceRegistry : NSObject

/**
 * Creates a source registry using the default BabelChrome viewer state directory.
 *
 * @return The initialized registry.
 */
- (instancetype)init;

/**
 * Returns the writable state directory path used by viewer modules.
 *
 * @return The viewer state directory path.
 */
- (NSString*)stateDirectoryPath;

/**
 * Registers one source reference.
 *
 * @param type The source type.
 * @param value The source value.
 * @param error The optional error pointer.
 * @return The generated source identifier, or nil when the registry cannot be written.
 */
- (NSString*)registerSourceWithType:(NSString*)type
                               value:(NSString*)value
                               error:(NSError**)error;

/**
 * Finds one registered source reference.
 *
 * @param sourceIdentifier The source identifier.
 * @return The source dictionary, or nil when not found.
 */
- (NSDictionary*)sourceWithIdentifier:(NSString*)sourceIdentifier;

@end

#endif
