#ifndef BABEL_CHROME_BROWSER_TAB_STRIP_LAYOUT_CALCULATOR_H_
#define BABEL_CHROME_BROWSER_TAB_STRIP_LAYOUT_CALCULATOR_H_

#import <Cocoa/Cocoa.h>

/**
 * Calculates tab item frames for the browser tab strip.
 */
@interface BabelTabStripLayoutCalculator : NSObject

/**
 * Initializes the calculator with stable tab metrics.
 *
 * @param normalWidth The preferred inactive tab width.
 * @param activeWidth The preferred active tab width.
 * @param minimumWidth The minimum inactive tab width before emergency shrinking.
 * @param tabHeight The tab item height.
 * @param spacing The spacing between tab items.
 *
 * @return The initialized calculator.
 */
- (instancetype)initWithNormalWidth:(CGFloat)normalWidth
                         activeWidth:(CGFloat)activeWidth
                        minimumWidth:(CGFloat)minimumWidth
                            tabHeight:(CGFloat)tabHeight
                              spacing:(CGFloat)spacing;

/**
 * Calculates frames for a tab strip.
 *
 * @param availableWidth The available tab strip width.
 * @param tabCount The number of tabs to position.
 * @param selectedIndex The selected tab index.
 *
 * @return An ordered array of `NSValue` objects containing `NSRect` frames.
 */
- (NSArray<NSValue*>*)tabFramesForAvailableWidth:(CGFloat)availableWidth
                                        tabCount:(NSUInteger)tabCount
                                   selectedIndex:(NSUInteger)selectedIndex;

@end

#endif
