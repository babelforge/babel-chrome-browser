#ifndef BABEL_CHROME_BROWSER_SETTINGS_STORE_H_
#define BABEL_CHROME_BROWSER_SETTINGS_STORE_H_

#import <Foundation/Foundation.h>

extern NSString* const BabelTabOpeningStrategyAppend;
extern NSString* const BabelTabOpeningStrategyAfterSelected;
extern NSString* const BabelTabOpeningStrategyChildCluster;
extern NSString* const BabelAddressSuggestionsModeLocal;
extern NSString* const BabelAddressSuggestionsModeGoogle;
extern NSString* const BabelMarkdownThemeGitHubLight;
extern NSString* const BabelMarkdownThemeGitHubDark;
extern NSString* const BabelMarkdownThemeReader;
extern NSString* const BabelMarkdownThemeCompact;

/**
 * Owns persisted browser-level user settings and option validation.
 */
@interface BabelBrowserSettingsStore : NSObject

/**
 * Creates a browser settings store.
 *
 * @param userDefaults The user defaults storage used for browser settings.
 * @return The initialized settings store.
 */
- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults;

/**
 * Returns the active tab opening strategy.
 *
 * @return The validated tab opening strategy.
 */
- (NSString*)tabOpeningStrategy;

/**
 * Persists the tab opening strategy when supported.
 *
 * @param strategy The strategy to persist.
 * @return YES when the strategy was accepted.
 */
- (BOOL)setTabOpeningStrategy:(NSString*)strategy;

/**
 * Returns whether a tab opening strategy is supported.
 *
 * @param strategy The strategy to validate.
 * @return YES when the strategy is supported.
 */
- (BOOL)isSupportedTabOpeningStrategy:(NSString*)strategy;

/**
 * Returns the active address suggestions mode.
 *
 * @return The validated address suggestions mode.
 */
- (NSString*)addressSuggestionsMode;

/**
 * Persists the address suggestions mode when supported.
 *
 * @param mode The mode to persist.
 * @return YES when the mode was accepted.
 */
- (BOOL)setAddressSuggestionsMode:(NSString*)mode;

/**
 * Returns whether an address suggestions mode is supported.
 *
 * @param mode The mode to validate.
 * @return YES when the mode is supported.
 */
- (BOOL)isSupportedAddressSuggestionsMode:(NSString*)mode;

/**
 * Returns the active Markdown viewer theme.
 *
 * @return The validated Markdown theme.
 */
- (NSString*)markdownTheme;

/**
 * Persists the Markdown viewer theme when supported.
 *
 * @param theme The theme to persist.
 * @return YES when the theme was accepted.
 */
- (BOOL)setMarkdownTheme:(NSString*)theme;

/**
 * Returns whether a Markdown viewer theme is supported.
 *
 * @param theme The theme to validate.
 * @return YES when the theme is supported.
 */
- (BOOL)isSupportedMarkdownTheme:(NSString*)theme;

/**
 * Returns whether long Cmd+Q is enabled.
 *
 * @return YES when Cmd+Q must be held before quitting.
 */
- (BOOL)longQuitShortcutEnabled;

/**
 * Persists whether long Cmd+Q is enabled.
 *
 * @param enabled YES to require a long Cmd+Q press.
 */
- (void)setLongQuitShortcutEnabled:(BOOL)enabled;

@end

#endif
