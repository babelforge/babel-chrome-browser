#ifndef BABEL_CHROME_BROWSER_GOOGLE_SUGGEST_CLIENT_H_
#define BABEL_CHROME_BROWSER_GOOGLE_SUGGEST_CLIENT_H_

#import <Foundation/Foundation.h>

typedef void (^BabelGoogleSuggestCompletion)(NSArray<NSString*>* suggestions);

/**
 * Fetches and caches Google Suggest results for omnibox queries.
 */
@interface BabelGoogleSuggestClient : NSObject

/**
 * Returns cached suggestions for a query.
 *
 * @param query The query string.
 * @return The cached suggestions, or nil when the query is not cached.
 */
- (NSArray<NSString*>*)cachedSuggestionsForQuery:(NSString*)query;

/**
 * Fetches suggestions for a query and caches the result.
 *
 * @param query The query string.
 * @param completion The completion block called on the main queue.
 */
- (void)fetchSuggestionsForQuery:(NSString*)query completion:(BabelGoogleSuggestCompletion)completion;

/**
 * Builds the Google Search URL string for a query.
 *
 * @param query The query string.
 * @return The Google Search URL string.
 */
- (NSString*)googleSearchURLStringForQuery:(NSString*)query;

@end

#endif
