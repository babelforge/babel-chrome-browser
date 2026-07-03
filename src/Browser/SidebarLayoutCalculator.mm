#import "Browser/SidebarLayoutCalculator.h"

@implementation BabelSidebarLayout

@synthesize sidebarFrame = _sidebarFrame;
@synthesize resizeHandleFrame = _resizeHandleFrame;
@synthesize rightContentFrame = _rightContentFrame;
@synthesize collapseButtonFrame = _collapseButtonFrame;
@synthesize newGroupButtonFrame = _newGroupButtonFrame;
@synthesize titleFrame = _titleFrame;
@synthesize groupsListFrame = _groupsListFrame;

- (instancetype)initWithSidebarFrame:(NSRect)sidebarFrame
                   resizeHandleFrame:(NSRect)resizeHandleFrame
                   rightContentFrame:(NSRect)rightContentFrame
                 collapseButtonFrame:(NSRect)collapseButtonFrame
                  newGroupButtonFrame:(NSRect)newGroupButtonFrame
                           titleFrame:(NSRect)titleFrame
                      groupsListFrame:(NSRect)groupsListFrame {
  self = [super init];
  if (self) {
    _sidebarFrame = sidebarFrame;
    _resizeHandleFrame = resizeHandleFrame;
    _rightContentFrame = rightContentFrame;
    _collapseButtonFrame = collapseButtonFrame;
    _newGroupButtonFrame = newGroupButtonFrame;
    _titleFrame = titleFrame;
    _groupsListFrame = groupsListFrame;
  }
  return self;
}

@end

@implementation BabelSidebarLayoutCalculator {
  CGFloat headerButtonSize_;
  CGFloat headerLeadingInset_;
  CGFloat headerButtonGap_;
  CGFloat headerTrailingInset_;
}

- (instancetype)initWithHeaderButtonSize:(CGFloat)headerButtonSize
                      headerLeadingInset:(CGFloat)headerLeadingInset
                         headerButtonGap:(CGFloat)headerButtonGap
                     headerTrailingInset:(CGFloat)headerTrailingInset {
  self = [super init];
  if (self) {
    headerButtonSize_ = headerButtonSize;
    headerLeadingInset_ = headerLeadingInset;
    headerButtonGap_ = headerButtonGap;
    headerTrailingInset_ = headerTrailingInset;
  }
  return self;
}

- (CGFloat)minimumExpandedWidthForTitleWidth:(CGFloat)titleWidth {
  return headerLeadingInset_ + headerButtonSize_ + headerButtonGap_ +
      titleWidth + headerButtonGap_ + headerButtonSize_ + headerTrailingInset_;
}

- (BabelSidebarLayout*)layoutForBounds:(NSRect)bounds
                          sidebarWidth:(CGFloat)sidebarWidth
                             collapsed:(BOOL)collapsed
                             titleWidth:(CGFloat)titleWidth {
  CGFloat totalWidth = bounds.size.width;
  CGFloat totalHeight = bounds.size.height;
  CGFloat rightWidth = MAX(0.0, totalWidth - sidebarWidth);
  CGFloat headerY = MAX(0.0, totalHeight - 42.0);
  CGFloat collapseButtonX = collapsed
      ? MAX(0.0, (sidebarWidth - headerButtonSize_) / 2.0)
      : headerLeadingInset_;
  NSRect collapseButtonFrame = NSMakeRect(collapseButtonX,
                                          headerY,
                                          headerButtonSize_,
                                          headerButtonSize_);
  CGFloat titleX = collapseButtonX + headerButtonSize_ + headerButtonGap_;
  CGFloat titleRightEdge = titleX + titleWidth;
  CGFloat minimumAddButtonX = titleRightEdge + headerButtonGap_;
  CGFloat addButtonX =
      MAX(minimumAddButtonX, sidebarWidth - headerButtonSize_ - headerTrailingInset_);
  NSRect newGroupButtonFrame = NSMakeRect(addButtonX,
                                          headerY,
                                          headerButtonSize_,
                                          headerButtonSize_);
  CGFloat titleAvailableWidth = MAX(0.0, addButtonX - titleX - headerButtonGap_);
  NSRect titleFrame = NSMakeRect(titleX,
                                 MAX(0.0, totalHeight - 40.0),
                                 MIN(titleWidth, titleAvailableWidth),
                                 24.0);
  CGFloat groupListX = 5.0;
  CGFloat groupListY = collapsed ? 12.0 : 24.0;
  CGFloat groupListBottomInset = collapsed ? 12.0 : 24.0;
  CGFloat groupListTopInset = collapsed ? 58.0 : 72.0;
  NSRect groupsListFrame = NSMakeRect(groupListX,
                                      groupListY,
                                      MAX(0.0, sidebarWidth - (groupListX * 2.0)),
                                      MAX(0.0, totalHeight - groupListTopInset -
                                                   groupListBottomInset));

  return [[BabelSidebarLayout alloc]
      initWithSidebarFrame:NSMakeRect(0, 0, sidebarWidth, totalHeight)
         resizeHandleFrame:NSMakeRect(MAX(0.0, sidebarWidth - 3.0),
                                      0,
                                      7.0,
                                      totalHeight)
         rightContentFrame:NSMakeRect(sidebarWidth, 0, rightWidth, totalHeight)
       collapseButtonFrame:collapseButtonFrame
        newGroupButtonFrame:newGroupButtonFrame
                 titleFrame:titleFrame
            groupsListFrame:groupsListFrame];
}

@end
