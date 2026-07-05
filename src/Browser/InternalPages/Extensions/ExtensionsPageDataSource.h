#ifndef BABEL_CHROME_BROWSER_EXTENSIONS_PAGE_DATA_SOURCE_H_
#define BABEL_CHROME_BROWSER_EXTENSIONS_PAGE_DATA_SOURCE_H_

#import <Foundation/Foundation.h>

@class BabelExtensionProfileStore;

/**
 * Builds the data rows consumed by the Extensions internal page renderer.
 */
@interface BabelExtensionsPageDataSource : NSObject

/**
 * Creates an Extensions page data source.
 *
 * @param extensionProfileStore The profile extension store to inspect.
 *
 * @return The initialized Extensions page data source.
 */
- (instancetype)initWithExtensionProfileStore:(BabelExtensionProfileStore*)extensionProfileStore;

/**
 * Builds installed profile extension rows.
 *
 * @return The profile extension row dictionaries.
 */
- (NSArray<NSDictionary*>*)profileExtensionRows;

/**
 * Builds unpacked extension rows.
 *
 * @return The unpacked extension row dictionaries.
 */
- (NSArray<NSDictionary*>*)unpackedExtensionRows;

@end

#endif
