#import "Browser/Address/Suggestions/OmniboxSuggestionsController.h"

#import "Browser/UI/Views/BrowserSupportViews.h"

@implementation BabelOmniboxSuggestionsController {
  NSView* panel_;
  NSMutableArray<NSDictionary*>* suggestions_;
  NSInteger selectedSuggestionIndex_;
}

- (instancetype)initWithPanel:(NSView*)panel {
  self = [super init];
  if (self) {
    panel_ = panel;
    suggestions_ = [NSMutableArray array];
    selectedSuggestionIndex_ = -1;
  }
  return self;
}

- (NSUInteger)suggestionCount {
  return suggestions_.count;
}

- (NSArray<NSDictionary*>*)suggestions {
  return [suggestions_ copy];
}

- (void)removeAllSuggestions {
  [suggestions_ removeAllObjects];
  selectedSuggestionIndex_ = -1;
}

- (void)addSuggestion:(NSDictionary*)suggestion {
  if (!suggestion) {
    return;
  }

  [suggestions_ addObject:suggestion];
}

- (void)showWithTarget:(id)target action:(SEL)action rowHeight:(CGFloat)rowHeight {
  if (0 == suggestions_.count) {
    [self hide];
    return;
  }

  [panel_.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
  panel_.hidden = NO;

  CGFloat panelWidth = panel_.bounds.size.width;
  CGFloat panelHeight = panel_.bounds.size.height;
  for (NSUInteger index = 0; index < suggestions_.count; index++) {
    NSDictionary* suggestion = suggestions_[index];
    BabelOmniboxSuggestionRowView* row =
        [[BabelOmniboxSuggestionRowView alloc] initWithFrame:
            NSMakeRect(0,
                       panelHeight - (rowHeight * (index + 1)),
                       panelWidth,
                       rowHeight)];
    row.target = target;
    row.action = action;
    row.tag = (NSInteger)index;
    row.suggestionHighlighted = (NSInteger)index == selectedSuggestionIndex_;
    NSImage* iconImage = [suggestion[@"icon"] isKindOfClass:NSImage.class] ? suggestion[@"icon"] : nil;
    [row configureWithTitle:[self stringValueForKey:@"title" inSuggestion:suggestion]
                   subtitle:[NSString stringWithFormat:@"%@ - %@",
                                                       [self stringValueForKey:@"group" inSuggestion:suggestion],
                                                       [self stringValueForKey:@"url" inSuggestion:suggestion]]
                  iconImage:iconImage];
    [panel_ addSubview:row];
  }
}

- (void)hide {
  [self removeAllSuggestions];
  panel_.hidden = YES;
  [panel_.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
}

- (void)selectNextSuggestion {
  if (0 == suggestions_.count) {
    return;
  }

  selectedSuggestionIndex_ =
      (selectedSuggestionIndex_ + 1) % (NSInteger)suggestions_.count;
  [self refreshHighlight];
}

- (void)selectPreviousSuggestion {
  if (0 == suggestions_.count) {
    return;
  }

  selectedSuggestionIndex_ = selectedSuggestionIndex_ <= 0
      ? (NSInteger)suggestions_.count - 1
      : selectedSuggestionIndex_ - 1;
  [self refreshHighlight];
}

- (void)selectSuggestionAtIndex:(NSInteger)index {
  selectedSuggestionIndex_ = index;
  [self refreshHighlight];
}

- (NSDictionary*)selectedSuggestion {
  if (selectedSuggestionIndex_ < 0 ||
      selectedSuggestionIndex_ >= (NSInteger)suggestions_.count) {
    return nil;
  }

  return suggestions_[(NSUInteger)selectedSuggestionIndex_];
}

- (void)refreshHighlight {
  for (NSView* view in panel_.subviews) {
    if (![view isKindOfClass:BabelOmniboxSuggestionRowView.class]) {
      continue;
    }

    BabelOmniboxSuggestionRowView* row = (BabelOmniboxSuggestionRowView*)view;
    row.suggestionHighlighted = row.tag == selectedSuggestionIndex_;
  }
}

- (NSString*)stringValueForKey:(NSString*)key inSuggestion:(NSDictionary*)suggestion {
  NSString* value = [suggestion[key] isKindOfClass:NSString.class] ? suggestion[key] : @"";
  return value ?: @"";
}

@end
