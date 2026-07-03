#ifndef BABEL_CHROME_BROWSER_SIDEBAR_LAYOUT_CALCULATOR_H_
#define BABEL_CHROME_BROWSER_SIDEBAR_LAYOUT_CALCULATOR_H_

#import <Cocoa/Cocoa.h>

/**
 * Describes the calculated frames for the browser sidebar and adjacent content.
 */
@interface BabelSidebarLayout : NSObject

@property(nonatomic, readonly) NSRect sidebarFrame;
@property(nonatomic, readonly) NSRect resizeHandleFrame;
@property(nonatomic, readonly) NSRect rightContentFrame;
@property(nonatomic, readonly) NSRect collapseButtonFrame;
@property(nonatomic, readonly) NSRect newGroupButtonFrame;
@property(nonatomic, readonly) NSRect titleFrame;
@property(nonatomic, readonly) NSRect groupsListFrame;

/**
 * Initializes a sidebar layout result.
 *
 * @param sidebarFrame The sidebar frame.
 * @param resizeHandleFrame The sidebar resize handle frame.
 * @param rightContentFrame The frame for the content area next to the sidebar.
 * @param collapseButtonFrame The collapse or expand button frame.
 * @param newGroupButtonFrame The add group button frame.
 * @param titleFrame The sidebar title frame.
 * @param groupsListFrame The groups list frame.
 *
 * @return The initialized layout result.
 */
- (instancetype)initWithSidebarFrame:(NSRect)sidebarFrame
                   resizeHandleFrame:(NSRect)resizeHandleFrame
                   rightContentFrame:(NSRect)rightContentFrame
                 collapseButtonFrame:(NSRect)collapseButtonFrame
                  newGroupButtonFrame:(NSRect)newGroupButtonFrame
                           titleFrame:(NSRect)titleFrame
                      groupsListFrame:(NSRect)groupsListFrame;

@end

/**
 * Calculates the browser sidebar geometry.
 */
@interface BabelSidebarLayoutCalculator : NSObject

/**
 * Initializes the calculator with stable sidebar metrics.
 *
 * @param headerButtonSize The header button width and height.
 * @param headerLeadingInset The header leading inset.
 * @param headerButtonGap The gap between header controls.
 * @param headerTrailingInset The header trailing inset.
 *
 * @return The initialized calculator.
 */
- (instancetype)initWithHeaderButtonSize:(CGFloat)headerButtonSize
                      headerLeadingInset:(CGFloat)headerLeadingInset
                         headerButtonGap:(CGFloat)headerButtonGap
                     headerTrailingInset:(CGFloat)headerTrailingInset;

/**
 * Returns the minimum expanded sidebar width for a rendered title.
 *
 * @param titleWidth The rendered sidebar title width.
 *
 * @return The minimum expanded width.
 */
- (CGFloat)minimumExpandedWidthForTitleWidth:(CGFloat)titleWidth;

/**
 * Calculates sidebar frames for a given container.
 *
 * @param bounds The split container bounds.
 * @param sidebarWidth The current sidebar width.
 * @param collapsed Whether the sidebar is collapsed.
 * @param titleWidth The rendered sidebar title width.
 *
 * @return The calculated sidebar layout.
 */
- (BabelSidebarLayout*)layoutForBounds:(NSRect)bounds
                          sidebarWidth:(CGFloat)sidebarWidth
                             collapsed:(BOOL)collapsed
                             titleWidth:(CGFloat)titleWidth;

@end

#endif
