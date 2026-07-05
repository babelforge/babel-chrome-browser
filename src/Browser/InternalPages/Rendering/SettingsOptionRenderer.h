#ifndef BABEL_CHROME_BROWSER_SETTINGS_OPTION_RENDERER_H_
#define BABEL_CHROME_BROWSER_SETTINGS_OPTION_RENDERER_H_

#import <Foundation/Foundation.h>

/**
 * Renders reusable option controls for BabelChrome settings pages.
 */
@interface BabelSettingsOptionRenderer : NSObject

/**
 * Renders tab opening strategy options.
 *
 * @param selectedStrategy The currently selected strategy.
 * @return The rendered HTML.
 */
- (NSString*)tabOpeningStrategyHTMLWithSelectedStrategy:(NSString*)selectedStrategy;

/**
 * Renders address suggestion mode options.
 *
 * @param selectedMode The currently selected mode.
 * @return The rendered HTML.
 */
- (NSString*)addressSuggestionsHTMLWithSelectedMode:(NSString*)selectedMode;

/**
 * Renders application appearance theme options.
 *
 * @param selectedTheme The currently selected appearance mode.
 * @return The rendered HTML.
 */
- (NSString*)appearanceThemeHTMLWithSelectedTheme:(NSString*)selectedTheme;

/**
 * Renders long quit shortcut options.
 *
 * @param enabled YES when the long quit shortcut is enabled.
 * @return The rendered HTML.
 */
- (NSString*)longQuitShortcutHTMLWithEnabledState:(BOOL)enabled;

/**
 * Renders Markdown theme options.
 *
 * @param selectedTheme The currently selected Markdown theme.
 * @param settingsURLString The settings URL that receives the option query.
 * @return The rendered HTML.
 */
- (NSString*)markdownThemeHTMLWithSelectedTheme:(NSString*)selectedTheme
                              settingsURLString:(NSString*)settingsURLString;

@end

#endif
