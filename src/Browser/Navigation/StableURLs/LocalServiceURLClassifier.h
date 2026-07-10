#ifndef BABEL_CHROME_BROWSER_LOCAL_SERVICE_URL_CLASSIFIER_H_
#define BABEL_CHROME_BROWSER_LOCAL_SERVICE_URL_CLASSIFIER_H_

#import <Foundation/Foundation.h>

/**
 * Classifies tokenized module runtime URLs.
 */
@interface BabelLocalServiceURLClassifier : NSObject

/**
 * Returns whether the URL string points to a tokenized module route.
 *
 * @param urlString The URL string to inspect.
 *
 * @return YES when the URL points to a module runtime route.
 */
- (BOOL)isLocalServiceModuleURLString:(NSString*)urlString;

/**
 * Returns whether the URL string points to a tokenized module runtime URL.
 *
 * @param urlString The URL string to inspect.
 *
 * @return YES when the URL is a local runtime URL carrying a token.
 */
- (BOOL)isLocalServiceRuntimeURLString:(NSString*)urlString;

/**
 * Returns whether the URL string points to the Project Launcher module index route.
 *
 * @param urlString The URL string to inspect.
 *
 * @return YES when the URL points to the Project Launcher module index route.
 */
- (BOOL)isProjectLauncherModuleURLString:(NSString*)urlString;

@end

#endif
