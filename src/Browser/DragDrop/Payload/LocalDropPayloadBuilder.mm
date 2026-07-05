#import "Browser/DragDrop/Payload/LocalDropPayloadBuilder.h"

@implementation BabelLocalDropPayloadBuilder

- (NSString*)payloadJSONForLocalPaths:(NSArray<NSString*>*)paths {
  NSMutableArray<NSString*>* cleanPaths = [NSMutableArray array];
  NSMutableArray<NSString*>* files = [NSMutableArray array];
  NSMutableArray<NSString*>* folders = [NSMutableArray array];
  NSFileManager* fileManager = NSFileManager.defaultManager;
  for (NSString* path in paths) {
    if (![path isKindOfClass:NSString.class] || 0 == path.length) {
      continue;
    }

    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]) {
      continue;
    }

    [cleanPaths addObject:path];
    if (isDirectory) {
      [folders addObject:path];
    } else {
      [files addObject:path];
    }
  }

  if (0 == cleanPaths.count) {
    return nil;
  }

  NSDictionary* payload = @{
    @"paths" : cleanPaths,
    @"files" : files,
    @"folders" : folders,
    @"source" : @"native"
  };
  NSData* payloadData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
  if (!payloadData) {
    return nil;
  }

  return [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding];
}

@end

