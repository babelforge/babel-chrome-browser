#import "Browser/DeveloperTools/Docking/DeveloperToolsDockingStore.h"

static const CGFloat kBabelDeveloperToolsDefaultSizeRatio = 0.38;
static const CGFloat kBabelDeveloperToolsMinimumSizeRatio = 0.20;
static const CGFloat kBabelDeveloperToolsMaximumSizeRatio = 0.78;

@implementation BabelDeveloperToolsDockingStore {
  NSUserDefaults* userDefaults_;
  NSString* dockModeDefaultsKey_;
  NSString* sizeRatioDefaultsKey_;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults
                 dockModeDefaultsKey:(NSString*)dockModeDefaultsKey
                 sizeRatioDefaultsKey:(NSString*)sizeRatioDefaultsKey {
  self = [super init];
  if (self) {
    userDefaults_ = userDefaults ?: NSUserDefaults.standardUserDefaults;
    dockModeDefaultsKey_ = dockModeDefaultsKey ?: @"";
    sizeRatioDefaultsKey_ = sizeRatioDefaultsKey ?: @"";
  }
  return self;
}

- (NSString*)restoredDockModeWithFallback:(NSString*)fallbackMode
                             allowedModes:(NSSet<NSString*>*)allowedModes {
  NSString* mode = [userDefaults_ stringForKey:dockModeDefaultsKey_];
  return [allowedModes containsObject:mode] ? mode : fallbackMode;
}

- (BOOL)setDockMode:(NSString*)dockMode allowedModes:(NSSet<NSString*>*)allowedModes {
  if (![allowedModes containsObject:dockMode]) {
    return NO;
  }

  [userDefaults_ setObject:dockMode forKey:dockModeDefaultsKey_];
  return YES;
}

- (CGFloat)restoredSizeRatio {
  double ratio = [userDefaults_ doubleForKey:sizeRatioDefaultsKey_];
  if (ratio <= 0.0) {
    return kBabelDeveloperToolsDefaultSizeRatio;
  }
  return [self clampedSizeRatio:(CGFloat)ratio];
}

- (CGFloat)setSizeRatio:(CGFloat)sizeRatio {
  CGFloat clampedSizeRatio = [self clampedSizeRatio:sizeRatio];
  [userDefaults_ setDouble:clampedSizeRatio forKey:sizeRatioDefaultsKey_];
  return clampedSizeRatio;
}

- (CGFloat)clampedSizeRatio:(CGFloat)sizeRatio {
  return MIN(kBabelDeveloperToolsMaximumSizeRatio,
             MAX(kBabelDeveloperToolsMinimumSizeRatio, sizeRatio));
}

@end
