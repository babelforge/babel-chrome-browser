#import "Browser/DeveloperToolsLayoutCalculator.h"

static NSString* const kBabelDeveloperToolsDockModeTop = @"top";
static NSString* const kBabelDeveloperToolsDockModeLeft = @"left";
static NSString* const kBabelDeveloperToolsDockModeRight = @"right";

@implementation BabelDeveloperToolsPageLayout

@synthesize browserFrame = _browserFrame;
@synthesize panelFrame = _panelFrame;

- (instancetype)initWithBrowserFrame:(NSRect)browserFrame
                          panelFrame:(NSRect)panelFrame {
  self = [super init];
  if (self) {
    _browserFrame = browserFrame;
    _panelFrame = panelFrame;
  }
  return self;
}

@end

@implementation BabelDeveloperToolsPanelLayout

@synthesize toolbarFrame = _toolbarFrame;
@synthesize resizeHandleFrame = _resizeHandleFrame;
@synthesize hostFrame = _hostFrame;

- (instancetype)initWithToolbarFrame:(NSRect)toolbarFrame
                   resizeHandleFrame:(NSRect)resizeHandleFrame
                           hostFrame:(NSRect)hostFrame {
  self = [super init];
  if (self) {
    _toolbarFrame = toolbarFrame;
    _resizeHandleFrame = resizeHandleFrame;
    _hostFrame = hostFrame;
  }
  return self;
}

@end

@implementation BabelDeveloperToolsLayoutCalculator

- (BabelDeveloperToolsPageLayout*)pageLayoutForBounds:(NSRect)bounds
                                             dockMode:(NSString*)dockMode
                                            sizeRatio:(CGFloat)sizeRatio {
  CGFloat developerToolsHeight = [self developerToolsHeightForBounds:bounds
                                                           sizeRatio:sizeRatio];
  CGFloat developerToolsWidth = [self developerToolsWidthForBounds:bounds
                                                         sizeRatio:sizeRatio];
  NSRect browserFrame = bounds;
  NSRect panelFrame = NSZeroRect;

  if ([dockMode isEqualToString:kBabelDeveloperToolsDockModeTop]) {
    browserFrame = NSMakeRect(0,
                              0,
                              bounds.size.width,
                              MAX(0.0, bounds.size.height - developerToolsHeight));
    panelFrame = NSMakeRect(0,
                            bounds.size.height - developerToolsHeight,
                            bounds.size.width,
                            developerToolsHeight);
  } else if ([dockMode isEqualToString:kBabelDeveloperToolsDockModeLeft]) {
    panelFrame = NSMakeRect(0,
                            0,
                            developerToolsWidth,
                            bounds.size.height);
    browserFrame = NSMakeRect(developerToolsWidth,
                              0,
                              MAX(0.0, bounds.size.width - developerToolsWidth),
                              bounds.size.height);
  } else if ([dockMode isEqualToString:kBabelDeveloperToolsDockModeRight]) {
    browserFrame = NSMakeRect(0,
                              0,
                              MAX(0.0, bounds.size.width - developerToolsWidth),
                              bounds.size.height);
    panelFrame = NSMakeRect(bounds.size.width - developerToolsWidth,
                            0,
                            developerToolsWidth,
                            bounds.size.height);
  } else {
    panelFrame = NSMakeRect(0,
                            0,
                            bounds.size.width,
                            developerToolsHeight);
    browserFrame = NSMakeRect(0,
                              developerToolsHeight,
                              bounds.size.width,
                              MAX(0.0, bounds.size.height - developerToolsHeight));
  }

  return [[BabelDeveloperToolsPageLayout alloc] initWithBrowserFrame:browserFrame
                                                          panelFrame:panelFrame];
}

- (BabelDeveloperToolsPanelLayout*)panelLayoutForBounds:(NSRect)bounds
                                               dockMode:(NSString*)dockMode
                                          toolbarHeight:(CGFloat)toolbarHeight
                                  resizeHandleThickness:(CGFloat)resizeHandleThickness {
  CGFloat resolvedToolbarHeight = MIN(toolbarHeight, bounds.size.height);
  NSRect toolbarFrame = NSMakeRect(0,
                                   MAX(0.0, bounds.size.height - resolvedToolbarHeight),
                                   bounds.size.width,
                                   resolvedToolbarHeight);
  NSRect resizeHandleFrame = NSZeroRect;

  if ([dockMode isEqualToString:kBabelDeveloperToolsDockModeTop]) {
    resizeHandleFrame = NSMakeRect(0, 0, bounds.size.width, resizeHandleThickness);
  } else if ([dockMode isEqualToString:kBabelDeveloperToolsDockModeLeft]) {
    resizeHandleFrame = NSMakeRect(MAX(0.0, bounds.size.width - resizeHandleThickness),
                                   0,
                                   resizeHandleThickness,
                                   bounds.size.height);
  } else if ([dockMode isEqualToString:kBabelDeveloperToolsDockModeRight]) {
    resizeHandleFrame = NSMakeRect(0, 0, resizeHandleThickness, bounds.size.height);
  } else {
    resizeHandleFrame = NSMakeRect(0,
                                   MAX(0.0, bounds.size.height - resizeHandleThickness),
                                   bounds.size.width,
                                   resizeHandleThickness);
  }

  NSRect hostFrame = NSMakeRect(0,
                                0,
                                bounds.size.width,
                                MAX(0.0, bounds.size.height - resolvedToolbarHeight));

  return [[BabelDeveloperToolsPanelLayout alloc] initWithToolbarFrame:toolbarFrame
                                                    resizeHandleFrame:resizeHandleFrame
                                                            hostFrame:hostFrame];
}

- (CGFloat)developerToolsHeightForBounds:(NSRect)bounds sizeRatio:(CGFloat)sizeRatio {
  CGFloat maximumHeight = MAX(160.0, bounds.size.height - 180.0);
  return MIN(MAX(180.0, bounds.size.height * sizeRatio), maximumHeight);
}

- (CGFloat)developerToolsWidthForBounds:(NSRect)bounds sizeRatio:(CGFloat)sizeRatio {
  CGFloat maximumWidth = MAX(260.0, bounds.size.width - 360.0);
  return MIN(MAX(320.0, bounds.size.width * sizeRatio), maximumWidth);
}

@end
