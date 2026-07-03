#import "App/MainMenuBuilder.h"

#import "Configuration/Configuration.h"

@implementation BabelMainMenuBuilder

+ (void)installMainMenuWithTarget:(id)target {
  NSMenu* menuBar = [[NSMenu alloc] initWithTitle:@""];
  NSMenuItem* appMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                       action:nil
                                                keyEquivalent:@""];
  [menuBar addItem:appMenuItem];

  NSMenu* appMenu = [[NSMenu alloc] initWithTitle:BabelChromeConfiguration.applicationName];
  NSString* quitTitle =
      [NSString stringWithFormat:@"Quit %@", BabelChromeConfiguration.applicationName];
  NSMenuItem* quitItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                    action:@selector(quitApplication:)
                                             keyEquivalent:@"q"];
  quitItem.target = target;
  [appMenu addItem:quitItem];

  NSMenuItem* settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings..."
                                                        action:@selector(openSettings:)
                                                 keyEquivalent:@","];
  settingsItem.target = target;
  settingsItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
  [appMenu insertItem:settingsItem atIndex:0];
  [appMenuItem setSubmenu:appMenu];

  [menuBar addItem:[self fileMenuItemWithTarget:target]];
  [menuBar addItem:[self editMenuItem]];
  [menuBar addItem:[self windowMenuItemWithTarget:target]];

  [NSApp setMainMenu:menuBar];
}

+ (NSMenuItem*)fileMenuItemWithTarget:(id)target {
  NSMenuItem* fileMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                        action:nil
                                                 keyEquivalent:@""];
  NSMenu* fileMenu = [[NSMenu alloc] initWithTitle:@"File"];

  NSMenuItem* newTabItem = [[NSMenuItem alloc] initWithTitle:@"New Tab"
                                                      action:@selector(newTab:)
                                               keyEquivalent:@"n"];
  newTabItem.target = target;
  [fileMenu addItem:newTabItem];

  NSMenuItem* newAdjacentTabItem = [[NSMenuItem alloc] initWithTitle:@"New Adjacent Tab"
                                                              action:@selector(newAdjacentTab:)
                                                       keyEquivalent:@"t"];
  newAdjacentTabItem.target = target;
  [fileMenu addItem:newAdjacentTabItem];

  NSMenuItem* closeTabItem = [[NSMenuItem alloc] initWithTitle:@"Close Tab"
                                                        action:@selector(closeTab:)
                                                 keyEquivalent:@"w"];
  closeTabItem.target = target;
  [fileMenu addItem:closeTabItem];

  NSMenuItem* reopenTabItem = [[NSMenuItem alloc] initWithTitle:@"Reopen Closed Tab"
                                                         action:@selector(reopenLastClosedTab:)
                                                  keyEquivalent:@"t"];
  reopenTabItem.target = target;
  reopenTabItem.keyEquivalentModifierMask = NSEventModifierFlagCommand |
                                            NSEventModifierFlagShift;
  [fileMenu addItem:reopenTabItem];
  [fileMenuItem setSubmenu:fileMenu];
  return fileMenuItem;
}

+ (NSMenuItem*)editMenuItem {
  NSMenuItem* editMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                        action:nil
                                                 keyEquivalent:@""];
  NSMenu* editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
  [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Cut"
                                               action:@selector(cut:)
                                        keyEquivalent:@"x"]];
  [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy"
                                               action:@selector(copy:)
                                        keyEquivalent:@"c"]];
  [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Paste"
                                               action:@selector(paste:)
                                        keyEquivalent:@"v"]];
  [editMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Select All"
                                               action:@selector(selectAll:)
                                        keyEquivalent:@"a"]];
  [editMenuItem setSubmenu:editMenu];
  return editMenuItem;
}

+ (NSMenuItem*)windowMenuItemWithTarget:(id)target {
  NSMenuItem* windowMenuItem = [[NSMenuItem alloc] initWithTitle:@""
                                                          action:nil
                                                   keyEquivalent:@""];
  NSMenu* windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];

  [self addWindowMenuItemWithTitle:@"Select Next Tab"
                            action:@selector(selectNextTab:)
                     keyEquivalent:@"\t"
                      modifierMask:NSEventModifierFlagControl
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"Select Previous Tab"
                            action:@selector(selectPreviousTab:)
                     keyEquivalent:@"\t"
                      modifierMask:NSEventModifierFlagControl | NSEventModifierFlagShift
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"Back"
                            action:@selector(navigateBack:)
                     keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSLeftArrowFunctionKey]
                      modifierMask:NSEventModifierFlagCommand
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"Forward"
                            action:@selector(navigateForward:)
                     keyEquivalent:[NSString stringWithFormat:@"%C", (unichar)NSRightArrowFunctionKey]
                      modifierMask:NSEventModifierFlagCommand
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"Reload"
                            action:@selector(reloadTab:)
                     keyEquivalent:@"r"
                      modifierMask:NSEventModifierFlagCommand
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"Reload Ignoring Cache"
                            action:@selector(reloadTabIgnoringCache:)
                     keyEquivalent:@"r"
                      modifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"History"
                            action:@selector(openHistory:)
                     keyEquivalent:@"y"
                      modifierMask:NSEventModifierFlagCommand
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"Extensions"
                            action:@selector(openExtensions:)
                     keyEquivalent:@"e"
                      modifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"Extensions"
                            action:@selector(openExtensions:)
                     keyEquivalent:@";"
                      modifierMask:NSEventModifierFlagCommand
                            target:target
                              menu:windowMenu];
  [self addWindowMenuItemWithTitle:@"Developer Tools"
                            action:@selector(openDeveloperTools:)
                     keyEquivalent:@"j"
                      modifierMask:NSEventModifierFlagCommand | NSEventModifierFlagOption
                            target:target
                              menu:windowMenu];

  [windowMenuItem setSubmenu:windowMenu];
  return windowMenuItem;
}

+ (void)addWindowMenuItemWithTitle:(NSString*)title
                            action:(SEL)action
                     keyEquivalent:(NSString*)keyEquivalent
                      modifierMask:(NSEventModifierFlags)modifierMask
                            target:(id)target
                              menu:(NSMenu*)menu {
  NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:title
                                                action:action
                                         keyEquivalent:keyEquivalent];
  item.target = target;
  item.keyEquivalentModifierMask = modifierMask;
  [menu addItem:item];
}

@end
