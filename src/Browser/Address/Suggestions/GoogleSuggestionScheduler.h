#ifndef BABEL_CHROME_BROWSER_GOOGLE_SUGGESTION_SCHEDULER_H_
#define BABEL_CHROME_BROWSER_GOOGLE_SUGGESTION_SCHEDULER_H_

#import <Foundation/Foundation.h>

@class BabelGoogleSuggestClient;

typedef NSString* (^BabelGoogleSuggestionCurrentQueryProvider)(void);
typedef BOOL (^BabelGoogleSuggestionEnabledProvider)(void);
typedef void (^BabelGoogleSuggestionResultHandler)(NSString* query, NSArray<NSString*>* suggestions);

/**
 * Debounces Google Suggest requests and rejects stale responses.
 */
@interface BabelGoogleSuggestionScheduler : NSObject

/**
 * Initializes the scheduler.
 *
 * @param googleSuggestClient The Google Suggest client.
 * @return An initialized scheduler.
 */
- (instancetype)initWithGoogleSuggestClient:(BabelGoogleSuggestClient*)googleSuggestClient;

/**
 * Cancels pending suggestion work.
 */
- (void)cancelPendingSuggestions;

/**
 * Schedules Google suggestions for a query.
 *
 * @param query The query to suggest.
 * @param delayNanoseconds The debounce delay.
 * @param currentQueryProvider Provides the current address-field query.
 * @param enabledProvider Provides whether Google Suggest is enabled.
 * @param resultHandler Receives fresh suggestions.
 */
- (void)scheduleSuggestionsForQuery:(NSString*)query
                   delayNanoseconds:(int64_t)delayNanoseconds
               currentQueryProvider:(BabelGoogleSuggestionCurrentQueryProvider)currentQueryProvider
                     enabledProvider:(BabelGoogleSuggestionEnabledProvider)enabledProvider
                       resultHandler:(BabelGoogleSuggestionResultHandler)resultHandler;

@end

#endif
