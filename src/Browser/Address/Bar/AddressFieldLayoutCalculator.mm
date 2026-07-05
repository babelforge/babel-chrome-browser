#import "Browser/Address/Bar/AddressFieldLayoutCalculator.h"

@implementation BabelAddressFieldLayout
@synthesize badgeFrame;
@synthesize textFieldFrame;
@end

@implementation BabelAddressFieldLayoutCalculator

- (BabelAddressFieldLayout*)layoutForBounds:(NSRect)bounds hasBadge:(BOOL)hasBadge {
  CGFloat badgeWidth = hasBadge ? 30.0 : 0.0;
  CGFloat leftInset = 8.0;
  CGFloat horizontalGap = hasBadge ? 8.0 : 0.0;
  CGFloat textX = leftInset + badgeWidth + horizontalGap;

  BabelAddressFieldLayout* layout = [[BabelAddressFieldLayout alloc] init];
  layout.badgeFrame = NSMakeRect(leftInset,
                                 6.0,
                                 badgeWidth,
                                 MAX(0.0, bounds.size.height - 12.0));
  layout.textFieldFrame = NSMakeRect(textX,
                                     4.0,
                                     MAX(0.0, bounds.size.width - textX - 8.0),
                                     MAX(0.0, bounds.size.height - 8.0));
  return layout;
}

@end
