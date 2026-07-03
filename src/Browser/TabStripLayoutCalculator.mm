#import "Browser/TabStripLayoutCalculator.h"

@implementation BabelTabStripLayoutCalculator {
  CGFloat normalWidth_;
  CGFloat activeWidth_;
  CGFloat minimumWidth_;
  CGFloat tabHeight_;
  CGFloat spacing_;
}

- (instancetype)initWithNormalWidth:(CGFloat)normalWidth
                         activeWidth:(CGFloat)activeWidth
                        minimumWidth:(CGFloat)minimumWidth
                            tabHeight:(CGFloat)tabHeight
                              spacing:(CGFloat)spacing {
  self = [super init];
  if (self) {
    normalWidth_ = normalWidth;
    activeWidth_ = activeWidth;
    minimumWidth_ = minimumWidth;
    tabHeight_ = tabHeight;
    spacing_ = spacing;
  }
  return self;
}

- (NSArray<NSValue*>*)tabFramesForAvailableWidth:(CGFloat)availableWidth
                                        tabCount:(NSUInteger)tabCount
                                   selectedIndex:(NSUInteger)selectedIndex {
  if (0 == tabCount) {
    return @[];
  }

  CGFloat selectedWidth = tabCount > 1 ? MIN(activeWidth_, availableWidth) :
                                         MIN(normalWidth_, availableWidth);
  CGFloat inactiveWidth = normalWidth_;

  if (tabCount > 1) {
    CGFloat spacingWidth = spacing_ * (CGFloat)(tabCount - 1);
    CGFloat activeMaximumWidth = availableWidth - spacingWidth -
                                 (minimumWidth_ * (CGFloat)(tabCount - 1));
    selectedWidth = MIN(availableWidth,
                        MAX(normalWidth_, MIN(activeWidth_, activeMaximumWidth)));

    CGFloat inactiveAvailableWidth = MAX(0.0, availableWidth - selectedWidth - spacingWidth);
    inactiveWidth = inactiveAvailableWidth / (CGFloat)(tabCount - 1);
    inactiveWidth = MIN(normalWidth_, inactiveWidth);
    if (inactiveWidth < minimumWidth_) {
      inactiveWidth = MAX(18.0, inactiveWidth);
    }
  }

  NSMutableArray<NSValue*>* frames = [NSMutableArray arrayWithCapacity:tabCount];
  CGFloat x = 0.0;
  for (NSUInteger index = 0; index < tabCount; index++) {
    CGFloat tabWidth = index == selectedIndex ? selectedWidth : inactiveWidth;
    [frames addObject:[NSValue valueWithRect:NSMakeRect(x, 1.0, tabWidth, tabHeight_)]];
    x += tabWidth + spacing_;
  }

  return frames;
}

@end
