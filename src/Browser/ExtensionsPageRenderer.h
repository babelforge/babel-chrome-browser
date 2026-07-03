#ifndef BABEL_CHROME_BROWSER_EXTENSIONS_PAGE_RENDERER_H_
#define BABEL_CHROME_BROWSER_EXTENSIONS_PAGE_RENDERER_H_

#import <Foundation/Foundation.h>

extern NSString* const BabelExtensionProfileNameKey;
extern NSString* const BabelExtensionProfileIdentifierKey;
extern NSString* const BabelExtensionProfileVersionKey;
extern NSString* const BabelExtensionProfilePathKey;
extern NSString* const BabelExtensionProfileStatusKey;
extern NSString* const BabelExtensionProfileToggleActionKey;
extern NSString* const BabelExtensionProfileToggleLabelKey;
extern NSString* const BabelExtensionProfileRequiresRestartKey;
extern NSString* const BabelUnpackedExtensionNameKey;
extern NSString* const BabelUnpackedExtensionPathKey;
extern NSString* const BabelUnpackedExtensionStatusKey;

/**
 * Renders the Extensions internal page body.
 */
@interface BabelExtensionsPageRenderer : NSObject

/**
 * Creates an extensions page renderer.
 *
 * @param trashIconHTML The trash icon HTML used by removal buttons.
 * @return The initialized extensions page renderer.
 */
- (instancetype)initWithTrashIconHTML:(NSString*)trashIconHTML;

/**
 * Renders the Extensions page body.
 *
 * @param profileExtensionRows The installed Chrome profile extension row dictionaries.
 * @param unpackedExtensionRows The configured unpacked extension row dictionaries.
 * @return The rendered Extensions page body HTML.
 */
- (NSString*)extensionsPageBodyWithProfileExtensionRows:(NSArray<NSDictionary*>*)profileExtensionRows
                                 unpackedExtensionRows:(NSArray<NSDictionary*>*)unpackedExtensionRows;

@end

#endif
