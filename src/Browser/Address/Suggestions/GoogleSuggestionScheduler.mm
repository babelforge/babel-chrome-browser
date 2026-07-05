#import "Browser/Address/Suggestions/GoogleSuggestionScheduler.h"

#import "Browser/Address/Suggestions/GoogleSuggestClient.h"

@implementation BabelGoogleSuggestionScheduler {
  BabelGoogleSuggestClient* googleSuggestClient_;
  NSUInteger generation_;
}

- (instancetype)initWithGoogleSuggestClient:(BabelGoogleSuggestClient*)googleSuggestClient {
  self = [super init];
  if (self) {
    googleSuggestClient_ = googleSuggestClient;
  }

  return self;
}

- (void)cancelPendingSuggestions {
  generation_++;
}

- (void)scheduleSuggestionsForQuery:(NSString*)query
                   delayNanoseconds:(int64_t)delayNanoseconds
               currentQueryProvider:(BabelGoogleSuggestionCurrentQueryProvider)currentQueryProvider
                     enabledProvider:(BabelGoogleSuggestionEnabledProvider)enabledProvider
                       resultHandler:(BabelGoogleSuggestionResultHandler)resultHandler {
  if (!googleSuggestClient_ || !currentQueryProvider || !enabledProvider || !resultHandler) {
    return;
  }

  NSUInteger generation = ++generation_;
  if (!enabledProvider() || query.length < 2) {
    return;
  }

  NSArray<NSString*>* cachedSuggestions = [googleSuggestClient_ cachedSuggestionsForQuery:query];
  if (cachedSuggestions) {
    resultHandler(query, cachedSuggestions);
    return;
  }

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayNanoseconds), dispatch_get_main_queue(), ^{
    if (generation != generation_ ||
        !enabledProvider() ||
        ![query isEqualToString:currentQueryProvider()]) {
      return;
    }

    [googleSuggestClient_ fetchSuggestionsForQuery:query
                                        completion:^(NSArray<NSString*>* suggestions) {
      if (generation != generation_ ||
          !enabledProvider() ||
          ![query isEqualToString:currentQueryProvider()]) {
        return;
      }

      resultHandler(query, suggestions ?: @[]);
    }];
  });
}

@end
