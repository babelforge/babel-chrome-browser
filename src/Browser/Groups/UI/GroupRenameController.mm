#import "Browser/Groups/UI/GroupRenameController.h"

#import <Cocoa/Cocoa.h>

@implementation BabelGroupRenameController

- (NSString*)promptForGroupNameWithCurrentName:(NSString*)currentName {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Rename Group";
  alert.informativeText = @"Enter the new group name.";
  [alert addButtonWithTitle:@"Rename"];
  [alert addButtonWithTitle:@"Cancel"];

  NSTextField* textField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 28)];
  textField.stringValue = currentName ?: @"";
  alert.accessoryView = textField;

  NSModalResponse response = [alert runModal];
  if (response != NSAlertFirstButtonReturn) {
    return nil;
  }

  return [textField.stringValue stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)showDuplicateNameAlertForGroupName:(NSString*)groupName {
  NSAlert* alert = [[NSAlert alloc] init];
  alert.messageText = @"Group Name Already Exists";
  alert.informativeText = [NSString stringWithFormat:@"A group named \"%@\" already exists.",
                                                     groupName ?: @""];
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

@end
