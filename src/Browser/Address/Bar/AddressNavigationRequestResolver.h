#ifndef BABEL_CHROME_BROWSER_ADDRESS_NAVIGATION_REQUEST_RESOLVER_H_
#define BABEL_CHROME_BROWSER_ADDRESS_NAVIGATION_REQUEST_RESOLVER_H_

#import <Foundation/Foundation.h>

@class BabelAddressBarDisplayResolver;
@class BabelAddressFieldNavigationResolver;
@class BabelAddressNavigationNormalizer;
@class BabelBrowserTab;
@class BabelStableViewerURLResolver;

typedef NSString* (^BabelAddressURLResolutionBlock)(NSString* urlString);

@interface BabelAddressNavigationRequest : NSObject

@property(nonatomic, copy) NSString* requestedURLString;
@property(nonatomic, copy) NSString* navigationURLString;
@property(nonatomic, assign) BOOL shouldRestoreAddressBar;

@end

@interface BabelAddressNavigationRequestResolver : NSObject

- (instancetype)initWithDefaultURLString:(NSString*)defaultURLString
                    navigationNormalizer:(BabelAddressNavigationNormalizer*)navigationNormalizer
                 fieldNavigationResolver:(BabelAddressFieldNavigationResolver*)fieldNavigationResolver
                addressBarDisplayResolver:(BabelAddressBarDisplayResolver*)addressBarDisplayResolver
                  stableViewerURLResolver:(BabelStableViewerURLResolver*)stableViewerURLResolver
               supportedViewerURLResolver:(BabelAddressURLResolutionBlock)supportedViewerURLResolver
             stableNavigationURLResolver:(BabelAddressURLResolutionBlock)stableNavigationURLResolver;

- (BabelAddressNavigationRequest*)navigationRequestForAddressString:(NSString*)addressString
                                                        selectedTab:(BabelBrowserTab*)selectedTab;

@end

#endif  // BABEL_CHROME_BROWSER_ADDRESS_NAVIGATION_REQUEST_RESOLVER_H_
