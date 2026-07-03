#ifndef BABEL_CHROME_BROWSER_INTERNAL_SETTINGS_NAVIGATION_HANDLER_H_
#define BABEL_CHROME_BROWSER_INTERNAL_SETTINGS_NAVIGATION_HANDLER_H_

#import <Foundation/Foundation.h>

@class BabelBrowserSettingsStore;

/**
 * Describes side effects produced by internal settings URL handling.
 */
@interface BabelInternalSettingsNavigationResult : NSObject

/**
 * YES when Markdown viewer tabs must be reloaded.
 */
@property(nonatomic, assign) BOOL markdownThemeDidChange;

/**
 * YES when application chrome theme colors must be reapplied.
 */
@property(nonatomic, assign) BOOL appearanceThemeDidChange;

@end

/**
 * Applies query-string settings mutations from BabelChrome internal settings URLs.
 */
@interface BabelInternalSettingsNavigationHandler : NSObject

/**
 * Creates the settings navigation handler.
 *
 * @param settingsStore The browser settings store to mutate.
 * @param userDefaults The defaults store used for theme appearance settings.
 * @return The initialized handler.
 */
- (instancetype)initWithSettingsStore:(BabelBrowserSettingsStore*)settingsStore
                         userDefaults:(NSUserDefaults*)userDefaults;

/**
 * Applies mutations from a module settings URL.
 *
 * @param components The parsed settings URL components.
 * @param moduleIdentifier The normalized module identifier.
 * @return The mutation result flags.
 */
- (BabelInternalSettingsNavigationResult*)applyModuleSettingsComponents:(NSURLComponents*)components
                                                       moduleIdentifier:(NSString*)moduleIdentifier;

/**
 * Applies mutations from the main application settings URL.
 *
 * @param components The parsed settings URL components.
 * @return The mutation result flags.
 */
- (BabelInternalSettingsNavigationResult*)applyApplicationSettingsComponents:(NSURLComponents*)components;

@end

#endif
