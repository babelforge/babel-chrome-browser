#ifndef BABEL_CHROME_BROWSER_THEME_H_
#define BABEL_CHROME_BROWSER_THEME_H_

#import <Cocoa/Cocoa.h>

extern NSString* const BabelThemeAppearanceDefaultsKey;
extern NSString* const BabelThemeAppearanceSystem;
extern NSString* const BabelThemeAppearanceLight;
extern NSString* const BabelThemeAppearanceDark;

/**
 * Resolves BabelChrome UI color tokens from bundled theme JSON files.
 */
@interface BabelTheme : NSObject

/**
 * Returns the shared browser theme resolver.
 *
 * @return The shared theme resolver.
 */
+ (instancetype)sharedTheme;

/**
 * Resolves a color token for a view effective appearance.
 *
 * @param token The theme token name.
 * @param view The view whose appearance should drive light/dark selection.
 * @return The resolved color, or the system label color when no token exists.
 */
- (NSColor*)colorForToken:(NSString*)token view:(NSView*)view;

/**
 * Resolves a color token for a view effective appearance and returns a CGColor.
 *
 * @param token The theme token name.
 * @param view The view whose appearance should drive light/dark selection.
 * @return The resolved CGColor.
 */
- (CGColorRef)cgColorForToken:(NSString*)token view:(NSView*)view;

/**
 * Returns the configured appearance mode.
 *
 * @return The configured appearance mode.
 */
- (NSString*)appearanceMode;

/**
 * Returns whether an appearance mode is supported.
 *
 * @param mode The appearance mode to validate.
 * @return YES when the mode is supported.
 */
- (BOOL)isSupportedAppearanceMode:(NSString*)mode;

/**
 * Returns the forced AppKit appearance for the configured mode.
 *
 * @return The forced appearance, or nil when the system appearance should be used.
 */
- (NSAppearance*)forcedAppearance;

/**
 * Resolves a color-list token for a view effective appearance.
 *
 * @param token The theme token name.
 * @param view The view whose appearance should drive light/dark selection.
 * @return The resolved color list.
 */
- (NSArray<NSColor*>*)colorListForToken:(NSString*)token view:(NSView*)view;

@end

#endif
