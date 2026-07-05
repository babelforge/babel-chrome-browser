#ifndef BABEL_CHROME_BROWSER_OMNIBOX_SUGGESTIONS_CONTROLLER_H_
#define BABEL_CHROME_BROWSER_OMNIBOX_SUGGESTIONS_CONTROLLER_H_

#import <Cocoa/Cocoa.h>

/**
 * Owns omnibox suggestion state and row rendering.
 */
@interface BabelOmniboxSuggestionsController : NSObject

/**
 * Creates an omnibox suggestions controller.
 *
 * @param panel The panel that hosts suggestion rows.
 * @return The initialized suggestions controller.
 */
- (instancetype)initWithPanel:(NSView*)panel;

/**
 * Returns the current number of suggestions.
 *
 * @return The suggestion count.
 */
- (NSUInteger)suggestionCount;

/**
 * Returns all current suggestion dictionaries.
 *
 * @return The suggestion dictionaries.
 */
- (NSArray<NSDictionary*>*)suggestions;

/**
 * Removes all suggestions and resets the selection.
 */
- (void)removeAllSuggestions;

/**
 * Adds one suggestion dictionary.
 *
 * @param suggestion The suggestion dictionary to add.
 */
- (void)addSuggestion:(NSDictionary*)suggestion;

/**
 * Shows and renders suggestion rows.
 *
 * @param target The row target.
 * @param action The row action.
 * @param rowHeight The row height.
 */
- (void)showWithTarget:(id)target action:(SEL)action rowHeight:(CGFloat)rowHeight;

/**
 * Hides the suggestions panel and removes rows.
 */
- (void)hide;

/**
 * Selects the next suggestion.
 */
- (void)selectNextSuggestion;

/**
 * Selects the previous suggestion.
 */
- (void)selectPreviousSuggestion;

/**
 * Selects the suggestion at the provided index.
 *
 * @param index The selected suggestion index.
 */
- (void)selectSuggestionAtIndex:(NSInteger)index;

/**
 * Returns the selected suggestion.
 *
 * @return The selected suggestion, or nil.
 */
- (NSDictionary*)selectedSuggestion;

@end

#endif
