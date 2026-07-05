#ifndef BABEL_CHROME_BROWSER_OMNIBOX_LOCAL_SUGGESTION_BUILDER_H_
#define BABEL_CHROME_BROWSER_OMNIBOX_LOCAL_SUGGESTION_BUILDER_H_

#import <Foundation/Foundation.h>

extern NSString* const BabelOmniboxLocalRowTitleKey;
extern NSString* const BabelOmniboxLocalRowURLStringKey;
extern NSString* const BabelOmniboxLocalRowRequestedURLStringKey;
extern NSString* const BabelOmniboxLocalRowGroupNameKey;
extern NSString* const BabelOmniboxLocalRowTabIdentifierKey;

/**
 * Builds local address-bar suggestions from open and recently closed tabs.
 */
@interface BabelOmniboxLocalSuggestionBuilder : NSObject

/**
 * Builds local omnibox suggestions for a query.
 *
 * @param query The user query.
 * @param openTabRows The open tab row dictionaries.
 * @param closedTabRows The recently closed tab row dictionaries.
 * @param maximumCount The maximum number of suggestions to return.
 * @return Suggestion dictionaries suitable for the omnibox UI.
 */
- (NSArray<NSDictionary*>*)localSuggestionsForQuery:(NSString*)query
                                       openTabRows:(NSArray<NSDictionary*>*)openTabRows
                                     closedTabRows:(NSArray<NSDictionary*>*)closedTabRows
                                      maximumCount:(NSUInteger)maximumCount;

@end

#endif
