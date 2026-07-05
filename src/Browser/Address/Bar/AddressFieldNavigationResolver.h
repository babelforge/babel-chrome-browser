#ifndef BABEL_CHROME_BROWSER_ADDRESS_FIELD_NAVIGATION_RESOLVER_H_
#define BABEL_CHROME_BROWSER_ADDRESS_FIELD_NAVIGATION_RESOLVER_H_

#import <Foundation/Foundation.h>

/**
 * Resolves the URL string that should be navigated from the address field.
 */
@interface BabelAddressFieldNavigationResolver : NSObject

/**
 * Returns the navigation string represented by the current address field value.
 *
 * @param addressString The current address field text.
 * @param displayedURLString The URL string currently displayed to the user.
 * @param actualURLString The actual URL string stored by the selected tab.
 * @return The string to normalize and navigate.
 */
- (NSString*)navigationStringForAddressString:(NSString*)addressString
                           displayedURLString:(NSString*)displayedURLString
                              actualURLString:(NSString*)actualURLString;

@end

#endif
