#ifndef BABEL_CHROME_BROWSER_MODULE_SETTINGS_PAGE_RENDERER_H_
#define BABEL_CHROME_BROWSER_MODULE_SETTINGS_PAGE_RENDERER_H_

#import <Foundation/Foundation.h>

@class BabelSettingsOptionRenderer;

/**
 * Renders module-specific Settings internal page bodies.
 */
@interface BabelModuleSettingsPageRenderer : NSObject

/**
 * Creates a module settings page renderer.
 *
 * @param optionRenderer The renderer used for reusable settings option controls.
 * @return The initialized module settings page renderer.
 */
- (instancetype)initWithOptionRenderer:(BabelSettingsOptionRenderer*)optionRenderer;

/**
 * Renders a module Settings page body.
 *
 * @param moduleIdentifier The normalized module identifier.
 * @param moduleName The display name for the module.
 * @param markdownTheme The currently selected Markdown theme.
 * @return The rendered module Settings page body HTML.
 */
- (NSString*)moduleSettingsPageBodyForIdentifier:(NSString*)moduleIdentifier
                                      moduleName:(NSString*)moduleName
                                   markdownTheme:(NSString*)markdownTheme;

@end

#endif
