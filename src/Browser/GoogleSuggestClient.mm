#import "Browser/GoogleSuggestClient.h"

@implementation BabelGoogleSuggestClient {
  NSMutableDictionary<NSString*, NSArray<NSString*>*>* suggestionsByQuery_;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    suggestionsByQuery_ = [NSMutableDictionary dictionary];
  }
  return self;
}

- (NSArray<NSString*>*)cachedSuggestionsForQuery:(NSString*)query {
  return suggestionsByQuery_[[self cacheKeyForQuery:query]];
}

- (void)fetchSuggestionsForQuery:(NSString*)query completion:(BabelGoogleSuggestCompletion)completion {
  NSArray<NSString*>* cachedSuggestions = [self cachedSuggestionsForQuery:query];
  if (cachedSuggestions) {
    [self completeOnMainQueue:completion suggestions:cachedSuggestions];
    return;
  }

  NSURL* url = [self googleSuggestURLForQuery:query];
  if (!url) {
    [self completeOnMainQueue:completion suggestions:@[]];
    return;
  }

  NSURLSessionConfiguration* configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  configuration.timeoutIntervalForRequest = 1.5;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:configuration];
  NSURLSessionDataTask* task =
      [session dataTaskWithURL:url
             completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
    NSArray<NSString*>* suggestions = @[];
    if (!error && data.length > 0) {
      suggestions = [self googleSuggestionsFromData:data];
    }

    self->suggestionsByQuery_[[self cacheKeyForQuery:query]] = suggestions ?: @[];
    [self completeOnMainQueue:completion suggestions:suggestions ?: @[]];
    [session finishTasksAndInvalidate];
  }];
  [task resume];
}

- (NSString*)googleSearchURLStringForQuery:(NSString*)query {
  NSString* encodedQuery = [self googleQueryEscapedString:query];
  return [@"https://www.google.com/search?q=" stringByAppendingString:(encodedQuery ?: @"")];
}

- (void)completeOnMainQueue:(BabelGoogleSuggestCompletion)completion
                suggestions:(NSArray<NSString*>*)suggestions {
  if (!completion) {
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    completion(suggestions ?: @[]);
  });
}

- (NSURL*)googleSuggestURLForQuery:(NSString*)query {
  NSString* encodedQuery = [self googleQueryEscapedString:query];
  if (encodedQuery.length == 0) {
    return nil;
  }

  NSString* urlString =
      [NSString stringWithFormat:@"https://suggestqueries.google.com/complete/search?client=firefox&q=%@",
                                 encodedQuery];
  return [NSURL URLWithString:urlString];
}

- (NSString*)googleQueryEscapedString:(NSString*)query {
  NSMutableCharacterSet* allowedCharacters = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
  [allowedCharacters removeCharactersInString:@"&+=?"];
  return [query stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

- (NSArray<NSString*>*)googleSuggestionsFromData:(NSData*)data {
  NSError* error = nil;
  id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (error || ![json isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSArray* root = (NSArray*)json;
  if (root.count < 2 || ![root[1] isKindOfClass:NSArray.class]) {
    return @[];
  }

  NSMutableArray<NSString*>* suggestions = [NSMutableArray array];
  for (id value in (NSArray*)root[1]) {
    if (![value isKindOfClass:NSString.class] || [suggestions containsObject:value]) {
      continue;
    }
    [suggestions addObject:value];
  }
  return suggestions;
}

- (NSString*)cacheKeyForQuery:(NSString*)query {
  return query.lowercaseString ?: @"";
}

@end
