#ifndef BABEL_CHROME_BROWSER_INTERNAL_PAGE_ASSET_PROVIDER_H_
#define BABEL_CHROME_BROWSER_INTERNAL_PAGE_ASSET_PROVIDER_H_

#import <Foundation/Foundation.h>

/**
 * Provides inline assets used by internal BabelChrome pages.
 */
@interface BabelInternalPageAssetProvider : NSObject

/**
 * Returns the inline trash icon HTML.
 *
 * @return The trash icon SVG HTML.
 */
- (NSString*)trashIconHTML;

/**
 * Returns an inline SVG resource with normalized button classes.
 *
 * @param resourceName The SVG resource name.
 * @param fallbackHTML The fallback HTML.
 *
 * @return The normalized SVG HTML, or the fallback HTML.
 */
- (NSString*)resourceSVGIconHTMLNamed:(NSString*)resourceName fallback:(NSString*)fallbackHTML;

@end

#endif
