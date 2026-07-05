#ifndef BABEL_CHROME_BROWSER_INTERNAL_PAGE_RENDERER_H_
#define BABEL_CHROME_BROWSER_INTERNAL_PAGE_RENDERER_H_

#import <Foundation/Foundation.h>

/**
 * Renders shared HTML shells and escaping helpers for native internal pages.
 */
@interface BabelInternalPageRenderer : NSObject

/**
 * Renders a complete internal page HTML document.
 *
 * @param title The browser page title.
 * @param body The already-rendered page body.
 * @return The complete internal page HTML document.
 */
- (NSString*)internalPageHTMLWithTitle:(NSString*)title body:(NSString*)body;

/**
 * Escapes a string for safe HTML text insertion.
 *
 * @param value The value to escape.
 * @return The escaped string.
 */
- (NSString*)htmlEscapedString:(NSString*)value;

@end

#endif
