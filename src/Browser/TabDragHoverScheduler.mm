#import "Browser/TabDragHoverScheduler.h"

#import "Browser/BrowserModels.h"

@implementation BabelTabDragHoverScheduler {
  BabelBrowserGroup* pendingGroup_;
  NSUInteger generation_;
}

- (void)cancelPendingSelection {
  pendingGroup_ = nil;
  generation_++;
}

- (BOOL)isPendingGroup:(BabelBrowserGroup*)group {
  return group && pendingGroup_ == group;
}

- (void)scheduleSelectionForGroup:(BabelBrowserGroup*)group
                 delayNanoseconds:(int64_t)delayNanoseconds
                  validationBlock:(BabelTabDragHoverValidationBlock)validationBlock
                   selectionBlock:(BabelTabDragHoverSelectionBlock)selectionBlock {
  if (!group || !validationBlock || !selectionBlock) {
    return;
  }

  pendingGroup_ = group;
  NSUInteger generation = ++generation_;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayNanoseconds), dispatch_get_main_queue(), ^{
    if (generation != generation_ || pendingGroup_ != group) {
      return;
    }

    if (!validationBlock(group)) {
      return;
    }

    selectionBlock(group);
  });
}

@end
