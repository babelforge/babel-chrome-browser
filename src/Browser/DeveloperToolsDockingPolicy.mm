#import "Browser/DeveloperToolsDockingPolicy.h"

@implementation BabelDeveloperToolsDockingPolicy {
  NSString* bottomMode_;
  NSString* topMode_;
  NSString* leftMode_;
  NSString* rightMode_;
  NSInteger leftTag_;
  NSInteger rightTag_;
  NSInteger bottomTag_;
  NSInteger topTag_;
}

- (instancetype)initWithBottomMode:(NSString*)bottomMode
                           topMode:(NSString*)topMode
                          leftMode:(NSString*)leftMode
                         rightMode:(NSString*)rightMode
                           leftTag:(NSInteger)leftTag
                          rightTag:(NSInteger)rightTag
                         bottomTag:(NSInteger)bottomTag
                            topTag:(NSInteger)topTag {
  self = [super init];
  if (self) {
    bottomMode_ = [bottomMode copy];
    topMode_ = [topMode copy];
    leftMode_ = [leftMode copy];
    rightMode_ = [rightMode copy];
    leftTag_ = leftTag;
    rightTag_ = rightTag;
    bottomTag_ = bottomTag;
    topTag_ = topTag;
  }
  return self;
}

- (NSString*)dockModeForTag:(NSInteger)tag {
  if (tag == leftTag_) {
    return leftMode_;
  }
  if (tag == rightTag_) {
    return rightMode_;
  }
  if (tag == topTag_) {
    return topMode_;
  }
  if (tag == bottomTag_) {
    return bottomMode_;
  }
  return nil;
}

- (BOOL)isHorizontalDockMode:(NSString*)dockMode {
  return [dockMode isEqualToString:bottomMode_] || [dockMode isEqualToString:topMode_];
}

- (NSSet<NSString*>*)allowedDockModes {
  return [NSSet setWithObjects:bottomMode_, topMode_, leftMode_, rightMode_, nil];
}

@end
