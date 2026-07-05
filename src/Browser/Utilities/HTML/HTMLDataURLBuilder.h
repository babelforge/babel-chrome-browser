#ifndef BABEL_CHROME_BROWSER_HTML_DATA_URL_BUILDER_H_
#define BABEL_CHROME_BROWSER_HTML_DATA_URL_BUILDER_H_

#import <Foundation/Foundation.h>

/**
 * Builds data URLs for HTML documents.
 */
@interface BabelHTMLDataURLBuilder : NSObject

/**
 * Builds a base64-encoded HTML data URL.
 *
 * @param html The HTML string to encode.
 *
 * @return The encoded data URL string.
 */
- (NSString*)dataURLStringForHTML:(NSString*)html;

@end

#endif
