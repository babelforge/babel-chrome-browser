#import "Browser/State/Sessions/WindowStateStore.h"

#include <cmath>

static NSString* const kSidebarCollapsedDefaultsKey = @"SidebarCollapsed";
static NSString* const kSidebarWidthDefaultsKey = @"SidebarWidth";
static NSString* const kMainWindowFrameDefaultsKey = @"MainWindowFrame";
static NSString* const kMainWindowZoomedDefaultsKey = @"MainWindowZoomed";
static const CGFloat kWindowFrameComparisonTolerance = 2.0;

@implementation BabelWindowStateStore {
  NSUserDefaults* userDefaults_;
}

- (instancetype)initWithUserDefaults:(NSUserDefaults*)userDefaults {
  self = [super init];
  if (self) {
    userDefaults_ = userDefaults ?: NSUserDefaults.standardUserDefaults;
  }
  return self;
}

- (BOOL)restoredSidebarCollapsed {
  return [userDefaults_ boolForKey:kSidebarCollapsedDefaultsKey];
}

- (void)setSidebarCollapsed:(BOOL)collapsed {
  [userDefaults_ setBool:collapsed forKey:kSidebarCollapsedDefaultsKey];
  [userDefaults_ synchronize];
}

- (CGFloat)restoredExpandedSidebarWidthWithDefault:(CGFloat)defaultWidth
                                          minimum:(CGFloat)minimumWidth
                                          maximum:(CGFloat)maximumWidth {
  double storedWidth = [userDefaults_ doubleForKey:kSidebarWidthDefaultsKey];
  CGFloat width = storedWidth > 0.0 ? (CGFloat)storedWidth : defaultWidth;
  return [self normalizedWidth:width minimum:minimumWidth maximum:maximumWidth];
}

- (void)setExpandedSidebarWidth:(CGFloat)width {
  [userDefaults_ setDouble:width forKey:kSidebarWidthDefaultsKey];
  [userDefaults_ synchronize];
}

- (void)restoreWindowFrame:(NSWindow*)window {
  if (!window) {
    return;
  }

  id persistedFrame = [userDefaults_ objectForKey:kMainWindowFrameDefaultsKey];
  if (!persistedFrame) {
    [window center];
    return;
  }

  NSRect frame = [self restoredWindowFrameFromPersistedValue:persistedFrame];
  if (![self windowFrameIsVisible:frame]) {
    NSScreen* fallbackScreen = NSScreen.screens.firstObject ?: NSScreen.mainScreen;
    if (fallbackScreen) {
      [window setFrame:[self centeredWindowFrameForWindow:window onScreen:fallbackScreen]
               display:NO];
    } else {
      [window center];
    }
    return;
  }

  [window setFrame:frame display:NO];
}

- (void)restoreWindowZoomIfNeeded:(NSWindow*)window {
  if (!window) {
    return;
  }

  NSScreen* screen = [self bestScreenForWindow:window frame:window.frame];
  BOOL shouldRestoreZoom = [userDefaults_ boolForKey:kMainWindowZoomedDefaultsKey] &&
      [self windowFrameIsEffectivelyZoomed:window.frame onScreen:screen];
  if (shouldRestoreZoom && !window.isZoomed) {
    [window zoom:nil];
  }
}

- (void)saveWindowState:(NSWindow*)window {
  if (!window) {
    return;
  }

  NSRect frame = window.frame;
  NSScreen* screen = [self bestScreenForWindow:window frame:frame];
  BOOL shouldRestoreZoom = window.isZoomed &&
      [self windowFrameIsEffectivelyZoomed:frame onScreen:screen];
  [userDefaults_ setBool:shouldRestoreZoom forKey:kMainWindowZoomedDefaultsKey];

  if (!window.isMiniaturized) {
    NSRect visibleFrame = screen.visibleFrame;
    NSDictionary* persistedFrame = @{
      @"version": @1,
      @"screenName": screen.localizedName ?: @"",
      @"x": @(frame.origin.x - visibleFrame.origin.x),
      @"y": @(frame.origin.y - visibleFrame.origin.y),
      @"width": @(frame.size.width),
      @"height": @(frame.size.height)
    };
    [userDefaults_ setObject:persistedFrame forKey:kMainWindowFrameDefaultsKey];
  }

  [userDefaults_ synchronize];
}

- (CGFloat)normalizedWidth:(CGFloat)width minimum:(CGFloat)minimumWidth maximum:(CGFloat)maximumWidth {
  return MIN(maximumWidth, MAX(minimumWidth, width));
}

- (BOOL)windowFrameIsVisible:(NSRect)frame {
  if (NSIsEmptyRect(frame) || frame.size.width < 200.0 || frame.size.height < 200.0) {
    return NO;
  }

  for (NSScreen* screen in NSScreen.screens) {
    if (NSIntersectsRect(frame, screen.visibleFrame)) {
      return YES;
    }
  }
  return NO;
}

- (NSRect)restoredWindowFrameFromPersistedValue:(id)persistedValue {
  if ([persistedValue isKindOfClass:NSString.class]) {
    return NSRectFromString((NSString*)persistedValue);
  }

  if (![persistedValue isKindOfClass:NSDictionary.class]) {
    return NSZeroRect;
  }

  NSDictionary* persistedFrame = (NSDictionary*)persistedValue;
  NSScreen* screen = [self screenForPersistedWindowFrame:persistedFrame];
  if (!screen) {
    return NSZeroRect;
  }

  NSRect visibleFrame = screen.visibleFrame;
  CGFloat width = [persistedFrame[@"width"] doubleValue];
  CGFloat height = [persistedFrame[@"height"] doubleValue];
  CGFloat relativeX = [persistedFrame[@"x"] doubleValue];
  CGFloat relativeY = [persistedFrame[@"y"] doubleValue];

  return NSMakeRect(visibleFrame.origin.x + relativeX,
                    visibleFrame.origin.y + relativeY,
                    width,
                    height);
}

- (NSScreen*)screenForPersistedWindowFrame:(NSDictionary*)persistedFrame {
  NSString* screenName = [persistedFrame[@"screenName"] isKindOfClass:NSString.class]
      ? persistedFrame[@"screenName"]
      : @"";
  for (NSScreen* screen in NSScreen.screens) {
    if (screenName.length > 0 && [screen.localizedName isEqualToString:screenName]) {
      return screen;
    }
  }

  return NSScreen.screens.firstObject ?: NSScreen.mainScreen;
}

- (NSRect)centeredWindowFrameForWindow:(NSWindow*)window onScreen:(NSScreen*)screen {
  NSRect visibleFrame = screen.visibleFrame;
  NSSize windowSize = window.frame.size;
  CGFloat width = MIN(MAX(900.0, windowSize.width), visibleFrame.size.width);
  CGFloat height = MIN(MAX(580.0, windowSize.height), visibleFrame.size.height);
  return NSMakeRect(NSMidX(visibleFrame) - (width / 2.0),
                    NSMidY(visibleFrame) - (height / 2.0),
                    width,
                    height);
}

- (NSScreen*)bestScreenForWindow:(NSWindow*)window frame:(NSRect)frame {
  NSScreen* bestScreen = window.screen ?: NSScreen.mainScreen;
  CGFloat bestIntersectionArea = 0.0;
  for (NSScreen* screen in NSScreen.screens) {
    NSRect intersection = NSIntersectionRect(frame, screen.visibleFrame);
    CGFloat intersectionArea = intersection.size.width * intersection.size.height;
    if (intersectionArea > bestIntersectionArea) {
      bestIntersectionArea = intersectionArea;
      bestScreen = screen;
    }
  }

  return bestScreen ?: NSScreen.screens.firstObject;
}

- (BOOL)windowFrameIsEffectivelyZoomed:(NSRect)frame onScreen:(NSScreen*)screen {
  if (!screen) {
    return NO;
  }

  NSRect visibleFrame = screen.visibleFrame;
  return fabs(frame.origin.x - visibleFrame.origin.x) <= kWindowFrameComparisonTolerance &&
      fabs(frame.origin.y - visibleFrame.origin.y) <= kWindowFrameComparisonTolerance &&
      fabs(frame.size.width - visibleFrame.size.width) <= kWindowFrameComparisonTolerance &&
      fabs(frame.size.height - visibleFrame.size.height) <= kWindowFrameComparisonTolerance;
}

@end
