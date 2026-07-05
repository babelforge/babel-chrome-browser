#ifndef BABEL_CHROME_BROWSER_APP_SETTINGS_PAGE_RENDERER_H_
#define BABEL_CHROME_BROWSER_APP_SETTINGS_PAGE_RENDERER_H_

#import <Foundation/Foundation.h>

@class BabelSettingsOptionRenderer;

/**
 * Renders the main BabelChrome Settings internal page body.
 */
@interface BabelAppSettingsPageRenderer : NSObject

/**
 * Creates an app settings page renderer.
 *
 * @param optionRenderer The renderer used for reusable settings option controls.
 * @return The initialized app settings page renderer.
 */
- (instancetype)initWithOptionRenderer:(BabelSettingsOptionRenderer*)optionRenderer;

/**
 * Renders the main Settings page body.
 *
 * @param defaultURLString The configured default page URL string.
 * @param appearanceTheme The currently selected application appearance theme.
 * @param longQuitShortcutEnabled YES when long Cmd+Q is enabled.
 * @param tabOpeningStrategy The currently selected tab opening strategy.
 * @param addressSuggestionsMode The currently selected address suggestions mode.
 * @return The rendered Settings page body HTML.
 */
- (NSString*)settingsPageBodyWithDefaultURLString:(NSString*)defaultURLString
                                  appearanceTheme:(NSString*)appearanceTheme
                          longQuitShortcutEnabled:(BOOL)longQuitShortcutEnabled
                               tabOpeningStrategy:(NSString*)tabOpeningStrategy
                           addressSuggestionsMode:(NSString*)addressSuggestionsMode;

@end

#endif
