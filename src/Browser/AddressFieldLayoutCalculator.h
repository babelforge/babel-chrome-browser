#ifndef BABEL_CHROME_BROWSER_ADDRESS_FIELD_LAYOUT_CALCULATOR_H_
#define BABEL_CHROME_BROWSER_ADDRESS_FIELD_LAYOUT_CALCULATOR_H_

#import <Cocoa/Cocoa.h>

/**
 * Holds calculated frames for the address badge and text field.
 */
@interface BabelAddressFieldLayout : NSObject

@property(nonatomic, assign) NSRect badgeFrame;
@property(nonatomic, assign) NSRect textFieldFrame;

@end

/**
 * Calculates address field subview frames.
 */
@interface BabelAddressFieldLayoutCalculator : NSObject

/**
 * Calculates frames for the address field content.
 *
 * @param bounds The address field container bounds.
 * @param hasBadge YES when a badge is visible.
 *
 * @return The calculated address field layout.
 */
- (BabelAddressFieldLayout*)layoutForBounds:(NSRect)bounds hasBadge:(BOOL)hasBadge;

@end

#endif
