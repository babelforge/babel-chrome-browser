#import "Browser/Groups/Creation/BrowserGroupFactory.h"

#import "Browser/UI/Models/BrowserModels.h"
#import "Browser/UI/Views/BrowserViews.h"

@implementation BabelBrowserGroupFactory {
  __weak id actionTarget_;
}

- (instancetype)initWithActionTarget:(id)actionTarget {
  self = [super init];
  if (self) {
    actionTarget_ = actionTarget;
  }
  return self;
}

- (BabelBrowserGroup*)makeGroupWithName:(NSString*)name identifier:(NSString*)identifier {
  BabelBrowserGroup* group = [[BabelBrowserGroup alloc] init];
  group.identifier = identifier;
  group.name = name;
  group.groupItemView = [[BabelGroupItemView alloc] initWithIdentifier:identifier title:name];
  group.groupItemView.target = actionTarget_;
  group.groupItemView.action = @selector(selectGroupFromItem:);
  group.groupItemView.renameTarget = actionTarget_;
  group.groupItemView.renameAction = @selector(renameGroupFromMenu:);
  group.groupItemView.deleteTarget = actionTarget_;
  group.groupItemView.deleteAction = @selector(deleteGroupFromMenu:);
  group.groupItemView.dragTarget = actionTarget_;
  group.groupItemView.dragAction = @selector(dragGroupFromItem:);
  group.groupItemView.dragEndTarget = actionTarget_;
  group.groupItemView.dragEndAction = @selector(finishDraggingGroupFromItem:);
  return group;
}

@end
