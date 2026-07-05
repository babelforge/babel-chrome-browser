#import "Browser/DragDrop/Logging/LocalDropLogWriter.h"

@implementation BabelLocalDropLogWriter {
  NSURL* logURL_;
}

- (instancetype)initWithLogURL:(NSURL*)logURL {
  self = [super init];
  if (self) {
    logURL_ = logURL;
  }
  return self;
}

- (void)appendLine:(NSString*)line {
  [NSFileManager.defaultManager createDirectoryAtURL:logURL_.URLByDeletingLastPathComponent
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  if (![NSFileManager.defaultManager fileExistsAtPath:logURL_.path]) {
    [NSFileManager.defaultManager createFileAtPath:logURL_.path contents:nil attributes:nil];
  }

  NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:logURL_.path];
  if (!fileHandle) {
    NSLog(@"BabelChrome local drop: %@", line ?: @"");
    return;
  }

  NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
  NSString* timestamp = [formatter stringFromDate:NSDate.date];
  NSString* entry = [NSString stringWithFormat:@"%@ %@\n", timestamp, line ?: @""];
  [fileHandle seekToEndOfFile];
  [fileHandle writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
  [fileHandle closeFile];
}

@end

