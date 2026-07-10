#ifndef BABEL_CHROME_BROWSER_INTERNAL_PAGE_HTML_COMPOSER_H_
#define BABEL_CHROME_BROWSER_INTERNAL_PAGE_HTML_COMPOSER_H_

#import <Foundation/Foundation.h>

@class BabelAppSettingsPageRenderer;
@class BabelExtensionsPageDataSource;
@class BabelExtensionsPageRenderer;
@class BabelHistoryPageDataSource;
@class BabelHistoryPageRenderer;
@class BabelInternalPageRenderer;
@class BabelModuleSettingsPageRenderer;

/**
 * Composes complete HTML documents for non-module internal pages.
 */
@interface BabelInternalPageHTMLComposer : NSObject

/**
 * Creates an internal page HTML composer.
 *
 * @param internalPageRenderer The shared internal page shell renderer.
 * @param historyPageRenderer The History page body renderer.
 * @param historyPageDataSource The History page data source.
 * @param appSettingsPageRenderer The app Settings page body renderer.
 * @param moduleSettingsPageRenderer The module Settings page body renderer.
 * @param extensionsPageRenderer The Extensions page body renderer.
 * @param extensionsPageDataSource The Extensions page data source.
 * @return The initialized composer.
 */
- (instancetype)initWithInternalPageRenderer:(BabelInternalPageRenderer*)internalPageRenderer
                         historyPageRenderer:(BabelHistoryPageRenderer*)historyPageRenderer
                       historyPageDataSource:(BabelHistoryPageDataSource*)historyPageDataSource
                     appSettingsPageRenderer:(BabelAppSettingsPageRenderer*)appSettingsPageRenderer
                  moduleSettingsPageRenderer:(BabelModuleSettingsPageRenderer*)moduleSettingsPageRenderer
                      extensionsPageRenderer:(BabelExtensionsPageRenderer*)extensionsPageRenderer
                    extensionsPageDataSource:(BabelExtensionsPageDataSource*)extensionsPageDataSource;

/**
 * Builds the History page HTML.
 *
 * @param groups The current browser groups.
 * @return The complete History page HTML.
 */
- (NSString*)historyPageHTMLWithGroups:(NSArray*)groups;

/**
 * Builds the app Settings page HTML.
 *
 * @param defaultURLString The configured default URL.
 * @param appearanceTheme The selected appearance mode.
 * @param longQuitShortcutEnabled Whether long Cmd+Q is enabled.
 * @param tabOpeningStrategy The selected tab opening strategy.
 * @param addressSuggestionsMode The selected address suggestions mode.
 * @return The complete Settings page HTML.
 */
- (NSString*)settingsPageHTMLWithDefaultURLString:(NSString*)defaultURLString
                                  appearanceTheme:(NSString*)appearanceTheme
                         longQuitShortcutEnabled:(BOOL)longQuitShortcutEnabled
                              tabOpeningStrategy:(NSString*)tabOpeningStrategy
                          addressSuggestionsMode:(NSString*)addressSuggestionsMode;

/**
 * Builds a module Settings page HTML.
 *
 * @param moduleIdentifier The normalized module identifier.
 * @param moduleName The display name of the module.
 * @param markdownTheme The selected Markdown theme.
 * @param requiredSettingsStatus The host-rendered runtime requirements status.
 * @return The complete module Settings page HTML.
 */
- (NSString*)moduleSettingsPageHTMLForIdentifier:(NSString*)moduleIdentifier
                                      moduleName:(NSString*)moduleName
                                   markdownTheme:(NSString*)markdownTheme
                          requiredSettingsStatus:(NSDictionary*)requiredSettingsStatus;

/**
 * Builds the Extensions page HTML.
 *
 * @return The complete Extensions page HTML.
 */
- (NSString*)extensionsPageHTML;

@end

#endif
