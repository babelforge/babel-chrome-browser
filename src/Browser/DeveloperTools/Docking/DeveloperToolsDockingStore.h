#ifndef BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_DOCKING_STORE_H_
#define BABEL_CHROME_BROWSER_DEVELOPER_TOOLS_DOCKING_STORE_H_

#import <Cocoa/Cocoa.h>

/**
 * Persists and validates embedded Developer Tools docking preferences.
 */
@interface BabelDeveloperToolsDockingStore : NSObject

/**
 * Creates a docking store.
 *
 * @param userDefaults The defaults storage.
 * @param dockModeDefaultsKey The key used for the dock mode.
 * @param sizeRatioDefaultsKey The key used for the size ratio.
 *
 * @return The initialized store.
 */
- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults
                 dockModeDefaultsKey:(NSString*)dockModeDefaultsKey
                 sizeRatioDefaultsKey:(NSString*)sizeRatioDefaultsKey;

/**
 * Restores a persisted dock mode.
 *
 * @param fallbackMode The fallback mode when the persisted value is invalid.
 * @param allowedModes The allowed dock modes.
 *
 * @return The restored dock mode.
 */
- (NSString*)restoredDockModeWithFallback:(NSString*)fallbackMode
                             allowedModes:(NSSet<NSString*>*)allowedModes;

/**
 * Persists a dock mode when it is allowed.
 *
 * @param dockMode The dock mode to persist.
 * @param allowedModes The allowed dock modes.
 *
 * @return YES when the dock mode was persisted.
 */
- (BOOL)setDockMode:(NSString*)dockMode allowedModes:(NSSet<NSString*>*)allowedModes;

/**
 * Restores the persisted size ratio.
 *
 * @return The clamped size ratio.
 */
- (CGFloat)restoredSizeRatio;

/**
 * Persists a size ratio after clamping.
 *
 * @param sizeRatio The requested size ratio.
 *
 * @return The clamped persisted size ratio.
 */
- (CGFloat)setSizeRatio:(CGFloat)sizeRatio;

/**
 * Clamps a size ratio to supported bounds.
 *
 * @param sizeRatio The requested size ratio.
 *
 * @return The clamped size ratio.
 */
- (CGFloat)clampedSizeRatio:(CGFloat)sizeRatio;

@end

#endif
