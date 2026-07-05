#ifndef BABEL_CHROME_BROWSER_MODULE_SETTINGS_ROUTE_RESOLVER_H_
#define BABEL_CHROME_BROWSER_MODULE_SETTINGS_ROUTE_RESOLVER_H_

#import <Foundation/Foundation.h>

@interface BabelModuleSettingsRouteResolver : NSObject

- (NSString*)moduleIdentifierFromSettingsComponents:(NSURLComponents*)components;
- (NSString*)normalizedModuleIdentifier:(NSString*)moduleIdentifier;
- (NSString*)moduleNameForIdentifier:(NSString*)moduleIdentifier;

@end

#endif  // BABEL_CHROME_BROWSER_MODULE_SETTINGS_ROUTE_RESOLVER_H_
