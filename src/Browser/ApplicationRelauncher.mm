#import "Browser/ApplicationRelauncher.h"

@implementation BabelApplicationRelauncher

- (BOOL)scheduleRelaunchForBundlePath:(NSString*)bundlePath
                    processIdentifier:(int)processIdentifier {
  if (bundlePath.length == 0) {
    return NO;
  }

  NSString* script = [NSString stringWithFormat:
      @"while /bin/kill -0 %d 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open %@",
      processIdentifier,
      [self shellQuotedString:bundlePath]];

  NSTask* task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/nohup"];
  task.arguments = @[@"/bin/sh", @"-c", script];
  NSFileHandle* nullHandle = [NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
  if (nullHandle) {
    task.standardOutput = nullHandle;
    task.standardError = nullHandle;
  }

  return [task launchAndReturnError:nil];
}

- (NSString*)shellQuotedString:(NSString*)value {
  NSString* escaped = [value stringByReplacingOccurrencesOfString:@"'" withString:@"'\\''"];
  return [NSString stringWithFormat:@"'%@'", escaped ?: @""];
}

@end
