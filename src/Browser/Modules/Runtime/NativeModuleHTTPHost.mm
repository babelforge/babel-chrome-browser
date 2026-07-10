#import "Browser/Modules/Runtime/NativeModuleHTTPHost.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Registry/NativeModuleRegistry.h"
#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeManager.h"
#import "Browser/Navigation/Viewer/ViewerSourceRegistry.h"

#import <AppKit/AppKit.h>

#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

static NSString* const kBabelNativeModuleHTTPHostErrorDomain =
    @"fr.babelforge.babel-chrome.native-module-http-host";
static NSUInteger const kBabelNativeModuleHTTPHostMaximumHeaderBytes = 65536;

@implementation BabelNativeModuleHTTPHost {
  BabelNativeModuleRegistry* moduleRegistry_;
  BabelNativeModuleProcessRuntimeManager* runtimeManager_;
  BabelViewerSourceRegistry* sourceRegistry_;
  dispatch_queue_t serverQueue_;
  dispatch_source_t acceptSource_;
  int serverSocket_;
  NSUInteger port_;
  NSString* token_;
}

- (instancetype)initWithModuleRegistry:(BabelNativeModuleRegistry*)moduleRegistry
                        runtimeManager:(BabelNativeModuleProcessRuntimeManager*)runtimeManager
                         sourceRegistry:(BabelViewerSourceRegistry*)sourceRegistry {
  self = [super init];
  if (self) {
    moduleRegistry_ = moduleRegistry;
    runtimeManager_ = runtimeManager;
    sourceRegistry_ = sourceRegistry;
    serverQueue_ = dispatch_queue_create("fr.babelforge.babel-chrome.native-module-http-host",
                                         DISPATCH_QUEUE_SERIAL);
    serverSocket_ = -1;
  }

  return self;
}

- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                 sourceURLString:(NSString*)sourceURLString
                           error:(NSError**)error {
  return [self moduleURLForIdentifier:moduleIdentifier
                                route:route
                      sourceURLString:sourceURLString
                           queryItems:@[]
                                error:error];
}

- (NSURL*)moduleURLForIdentifier:(NSString*)moduleIdentifier
                           route:(NSString*)route
                 sourceURLString:(NSString*)sourceURLString
                      queryItems:(NSArray<NSURLQueryItem*>*)queryItems
                           error:(NSError**)error {
  if (moduleIdentifier.length == 0) {
    [self assignError:error description:@"Missing module identifier."];
    return nil;
  }

  if (![self startIfNeededWithError:error]) {
    return nil;
  }

  NSString* routeName = route.length > 0 ? route : @"index";
  NSURLComponents* components = [[NSURLComponents alloc] init];
  components.scheme = @"http";
  components.host = @"127.0.0.1";
  components.port = @(port_);
  components.path = [NSString stringWithFormat:@"/module/%@/%@",
                                               moduleIdentifier,
                                               [routeName stringByTrimmingCharactersInSet:
                                                   [NSCharacterSet characterSetWithCharactersInString:@"/"]]];
  NSMutableArray<NSURLQueryItem*>* resolvedQueryItems = [NSMutableArray array];
  [resolvedQueryItems addObject:[NSURLQueryItem queryItemWithName:@"token" value:token_ ?: @""]];
  if (sourceURLString.length > 0) {
    [resolvedQueryItems addObject:[NSURLQueryItem queryItemWithName:@"sourceUrl" value:sourceURLString]];
  }
  for (NSURLQueryItem* item in queryItems ?: @[]) {
    if (![item.name isEqualToString:@"token"]) {
      [resolvedQueryItems addObject:item];
    }
  }
  components.queryItems = resolvedQueryItems;

  return components.URL;
}

- (void)stop {
  if (acceptSource_) {
    dispatch_source_cancel(acceptSource_);
    acceptSource_ = nil;
  }

  serverSocket_ = -1;
  port_ = 0;
  token_ = nil;
}

- (BOOL)startIfNeededWithError:(NSError**)error {
  if (serverSocket_ >= 0 && port_ > 0 && token_.length > 0) {
    return YES;
  }

  int socketDescriptor = socket(AF_INET, SOCK_STREAM, 0);
  if (socketDescriptor < 0) {
    [self assignError:error description:@"Unable to create native module HTTP socket."];
    return NO;
  }

  int reuse = 1;
  setsockopt(socketDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

  sockaddr_in address;
  memset(&address, 0, sizeof(address));
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = 0;

  if (bind(socketDescriptor, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
    close(socketDescriptor);
    [self assignError:error description:@"Unable to bind native module HTTP socket."];
    return NO;
  }

  socklen_t addressLength = sizeof(address);
  if (getsockname(socketDescriptor, reinterpret_cast<sockaddr*>(&address), &addressLength) != 0) {
    close(socketDescriptor);
    [self assignError:error description:@"Unable to read native module HTTP port."];
    return NO;
  }

  if (listen(socketDescriptor, SOMAXCONN) != 0) {
    close(socketDescriptor);
    [self assignError:error description:@"Unable to listen on native module HTTP socket."];
    return NO;
  }

  fcntl(socketDescriptor, F_SETFL, fcntl(socketDescriptor, F_GETFL, 0) | O_NONBLOCK);

  serverSocket_ = socketDescriptor;
  port_ = ntohs(address.sin_port);
  token_ = NSUUID.UUID.UUIDString;
  acceptSource_ = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ,
                                         static_cast<uintptr_t>(serverSocket_),
                                         0,
                                         serverQueue_);
  __weak BabelNativeModuleHTTPHost* weakSelf = self;
  dispatch_source_set_event_handler(acceptSource_, ^{
    [weakSelf acceptPendingConnections];
  });
  dispatch_source_set_cancel_handler(acceptSource_, ^{
    close(socketDescriptor);
  });
  dispatch_resume(acceptSource_);

  return YES;
}

- (void)acceptPendingConnections {
  while (serverSocket_ >= 0) {
    int clientSocket = accept(serverSocket_, nullptr, nullptr);
    if (clientSocket < 0) {
      return;
    }

    int clientFlags = fcntl(clientSocket, F_GETFL, 0);
    if (clientFlags >= 0) {
      fcntl(clientSocket, F_SETFL, clientFlags & ~O_NONBLOCK);
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      [self handleClientSocket:clientSocket];
    });
  }
}

- (void)handleClientSocket:(int)clientSocket {
  @autoreleasepool {
    NSDictionary* request = [self requestDictionaryFromSocket:clientSocket];
    if (!request) {
      [self sendStatus:400
                reason:@"Bad Request"
           contentType:@"text/plain; charset=utf-8"
                  body:[@"Bad Request" dataUsingEncoding:NSUTF8StringEncoding]
              toSocket:clientSocket];
      close(clientSocket);
      return;
    }

    NSString* method = [request[@"method"] isKindOfClass:NSString.class] ? request[@"method"] : @"";
    NSURLComponents* components = [request[@"components"] isKindOfClass:NSURLComponents.class] ? request[@"components"] : nil;
    if ((![method isEqualToString:@"GET"] && ![method isEqualToString:@"POST"]) || !components) {
      [self sendStatus:405
                reason:@"Method Not Allowed"
           contentType:@"text/plain; charset=utf-8"
                  body:[@"Method Not Allowed" dataUsingEncoding:NSUTF8StringEncoding]
              toSocket:clientSocket];
      close(clientSocket);
      return;
    }

    if (![self requestHasValidToken:components]) {
      [self sendStatus:403
                reason:@"Forbidden"
           contentType:@"text/plain; charset=utf-8"
                  body:[@"Forbidden" dataUsingEncoding:NSUTF8StringEncoding]
              toSocket:clientSocket];
      close(clientSocket);
      return;
    }

    NSArray<NSString*>* pathComponents = [components.path pathComponents];
    if ([self handleInternalRouteWithMethod:method
                                 components:components
                             pathComponents:pathComponents
                                    request:request
                                   toSocket:clientSocket]) {
      close(clientSocket);
      return;
    }

    if (pathComponents.count >= 5 && [pathComponents[1] isEqualToString:@"module"] &&
        [pathComponents[3] isEqualToString:@"assets"]) {
      [self serveModuleAssetWithComponents:components
                            pathComponents:pathComponents
                                  toSocket:clientSocket];
      close(clientSocket);
      return;
    }

    if (pathComponents.count >= 4 && [pathComponents[1] isEqualToString:@"module"]) {
      if (![method isEqualToString:@"GET"]) {
        [self sendStatus:405
                  reason:@"Method Not Allowed"
             contentType:@"text/plain; charset=utf-8"
                    body:[@"Method Not Allowed" dataUsingEncoding:NSUTF8StringEncoding]
                toSocket:clientSocket];
        close(clientSocket);
        return;
      }
      NSDictionary* headers = [request[@"headers"] isKindOfClass:NSDictionary.class] ? request[@"headers"] : @{};
      [self proxyModuleRouteWithComponents:components
                            pathComponents:pathComponents
                                    headers:headers
                                  toSocket:clientSocket];
      close(clientSocket);
      return;
    }

    [self sendStatus:404
              reason:@"Not Found"
         contentType:@"text/plain; charset=utf-8"
                body:[@"Not Found" dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    close(clientSocket);
  }
}

- (NSDictionary*)requestDictionaryFromSocket:(int)clientSocket {
  NSMutableData* data = [NSMutableData data];
  char buffer[2048];
  NSData* marker = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
  NSRange markerRange = NSMakeRange(NSNotFound, 0);
  while (data.length < kBabelNativeModuleHTTPHostMaximumHeaderBytes) {
    ssize_t readCount = recv(clientSocket, buffer, sizeof(buffer), 0);
    if (readCount <= 0) {
      break;
    }

    [data appendBytes:buffer length:static_cast<NSUInteger>(readCount)];
    markerRange = [data rangeOfData:marker options:0 range:NSMakeRange(0, data.length)];
    if (markerRange.location != NSNotFound) {
      break;
    }
  }

  if (markerRange.location == NSNotFound) {
    return nil;
  }

  NSUInteger headerEnd = markerRange.location + markerRange.length;
  NSData* headerData = [data subdataWithRange:NSMakeRange(0, headerEnd)];
  NSString* text = [[NSString alloc] initWithData:headerData encoding:NSUTF8StringEncoding];
  if (text.length == 0) {
    return nil;
  }

  NSArray<NSString*>* lines = [text componentsSeparatedByString:@"\r\n"];
  NSString* requestLine = lines.firstObject ?: @"";
  NSArray<NSString*>* requestParts = [requestLine componentsSeparatedByString:@" "];
  if (requestParts.count < 2) {
    return nil;
  }

  NSString* target = requestParts[1];
  NSURLComponents* components = [NSURLComponents componentsWithString:
      [@"http://127.0.0.1" stringByAppendingString:(target ?: @"")]];
  if (!components) {
    return nil;
  }

  NSMutableDictionary<NSString*, NSString*>* headers = [NSMutableDictionary dictionary];
  for (NSUInteger index = 1; index < lines.count; ++index) {
    NSString* line = lines[index];
    if (line.length == 0) {
      break;
    }

    NSRange separator = [line rangeOfString:@":"];
    if (separator.location == NSNotFound) {
      continue;
    }

    NSString* name = [[line substringToIndex:separator.location] lowercaseString];
    NSString* value = [[line substringFromIndex:separator.location + 1]
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (name.length > 0) {
      headers[name] = value ?: @"";
    }
  }

  NSUInteger contentLength = static_cast<NSUInteger>(MAX(0, [headers[@"content-length"] integerValue]));
  NSMutableData* body = [NSMutableData data];
  if (data.length > headerEnd) {
    [body appendData:[data subdataWithRange:NSMakeRange(headerEnd, data.length - headerEnd)]];
  }
  while (body.length < contentLength) {
    ssize_t readCount = recv(clientSocket, buffer, sizeof(buffer), 0);
    if (readCount <= 0) {
      break;
    }
    [body appendBytes:buffer length:static_cast<NSUInteger>(readCount)];
  }

  return @{
    @"method" : requestParts[0],
    @"components" : components,
    @"headers" : headers,
    @"body" : body
  };
}

- (BOOL)requestHasValidToken:(NSURLComponents*)components {
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:@"token"]) {
      return token_.length > 0 && [item.value isEqualToString:token_];
    }
  }

  return NO;
}

- (BOOL)handleInternalRouteWithMethod:(NSString*)method
                           components:(NSURLComponents*)components
                       pathComponents:(NSArray<NSString*>*)pathComponents
                              request:(NSDictionary*)request
                             toSocket:(int)clientSocket {
  if (pathComponents.count == 3 && [pathComponents[1] isEqualToString:@"source-status"] &&
      [method isEqualToString:@"GET"]) {
    [self serveSourceStatusWithIdentifier:pathComponents[2] toSocket:clientSocket];
    return YES;
  }

  if (pathComponents.count == 3 && [pathComponents[1] isEqualToString:@"asset"] &&
      [method isEqualToString:@"GET"]) {
    [self serveRegisteredSourceAssetWithIdentifier:pathComponents[2] toSocket:clientSocket];
    return YES;
  }

  if (pathComponents.count == 5 && [pathComponents[1] isEqualToString:@"internal"] &&
      [pathComponents[2] isEqualToString:@"open-with"] &&
      [pathComponents[3] isEqualToString:@"list"] &&
      [method isEqualToString:@"GET"]) {
    [self serveOpenWithListForExtension:pathComponents[4] toSocket:clientSocket];
    return YES;
  }

  if (pathComponents.count == 5 && [pathComponents[1] isEqualToString:@"internal"] &&
      [pathComponents[2] isEqualToString:@"open-with"] &&
      [pathComponents[3] isEqualToString:@"set"] &&
      [method isEqualToString:@"POST"]) {
    NSData* body = [request[@"body"] isKindOfClass:NSData.class] ? request[@"body"] : [NSData data];
    [self setOpenWithDefaultForExtension:pathComponents[4] body:body toSocket:clientSocket];
    return YES;
  }

  if (pathComponents.count == 4 && [pathComponents[1] isEqualToString:@"internal"] &&
      [pathComponents[2] isEqualToString:@"open-with"] &&
      [pathComponents[3] isEqualToString:@"open"] &&
      [method isEqualToString:@"POST"]) {
    NSData* body = [request[@"body"] isKindOfClass:NSData.class] ? request[@"body"] : [NSData data];
    [self openSourceWithBody:body toSocket:clientSocket];
    return YES;
  }

  if (pathComponents.count == 3 && [pathComponents[1] isEqualToString:@"internal"] &&
      [pathComponents[2] isEqualToString:@"message-relay"] &&
      [method isEqualToString:@"POST"]) {
    [self sendJSON:@{@"ok" : @YES} status:200 toSocket:clientSocket];
    return YES;
  }

  return NO;
}

- (void)serveSourceStatusWithIdentifier:(NSString*)sourceIdentifier toSocket:(int)clientSocket {
  NSDictionary* source = [sourceRegistry_ sourceWithIdentifier:sourceIdentifier];
  if (!source) {
    [self sendJSON:@{@"error" : @"Source not found"} status:404 toSocket:clientSocket];
    return;
  }

  NSString* type = [source[@"type"] isKindOfClass:NSString.class] ? source[@"type"] : @"";
  NSString* value = [source[@"value"] isKindOfClass:NSString.class] ? source[@"value"] : @"";
  if ([type isEqualToString:@"file"]) {
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:value isDirectory:&isDirectory] || isDirectory) {
      [self sendJSON:@{@"error" : @"Source not found"} status:404 toSocket:clientSocket];
      return;
    }

    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfItemAtPath:value error:nil];
    NSDate* modificationDate = [attributes[NSFileModificationDate] isKindOfClass:NSDate.class]
        ? attributes[NSFileModificationDate]
        : nil;
    id lastModified = modificationDate ? @((NSInteger)modificationDate.timeIntervalSince1970) : [NSNull null];
    [self sendJSON:@{@"local" : @YES, @"lastModified" : lastModified} status:200 toSocket:clientSocket];
    return;
  }

  [self sendJSON:@{@"local" : @NO, @"lastModified" : [NSNull null]} status:200 toSocket:clientSocket];
}

- (void)serveRegisteredSourceAssetWithIdentifier:(NSString*)sourceIdentifier toSocket:(int)clientSocket {
  NSDictionary* source = [sourceRegistry_ sourceWithIdentifier:sourceIdentifier];
  if (!source) {
    [self sendMissingImageWithIdentifier:sourceIdentifier toSocket:clientSocket];
    return;
  }

  NSString* type = [source[@"type"] isKindOfClass:NSString.class] ? source[@"type"] : @"";
  NSString* value = [source[@"value"] isKindOfClass:NSString.class] ? source[@"value"] : @"";
  if ([type isEqualToString:@"file"]) {
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:value isDirectory:&isDirectory] || isDirectory) {
      [self sendMissingImageWithIdentifier:sourceIdentifier toSocket:clientSocket];
      return;
    }

    NSData* data = [NSData dataWithContentsOfFile:value];
    if (!data) {
      [self sendMissingImageWithIdentifier:sourceIdentifier toSocket:clientSocket];
      return;
    }

    [self sendStatus:200
              reason:@"OK"
         contentType:[self mimeTypeForPath:value]
                body:data
            toSocket:clientSocket];
    return;
  }

  if ([type isEqualToString:@"url"]) {
    [self serveRemoteAssetWithURLString:value sourceIdentifier:sourceIdentifier toSocket:clientSocket];
    return;
  }

  [self sendMissingImageWithIdentifier:sourceIdentifier toSocket:clientSocket];
}

- (void)proxyModuleRouteWithComponents:(NSURLComponents*)components
                        pathComponents:(NSArray<NSString*>*)pathComponents
                                headers:(NSDictionary*)headers
                              toSocket:(int)clientSocket {
  NSString* moduleIdentifier = pathComponents[2];
  NSString* route = [[pathComponents subarrayWithRange:NSMakeRange(3, pathComponents.count - 3)]
      componentsJoinedByString:@"/"];

  NSError* error = nil;
  BabelNativeModuleManifest* module = [moduleRegistry_ moduleWithIdentifier:moduleIdentifier error:&error];
  if (!module || !module.enabled) {
    [self sendStatus:404
              reason:@"Not Found"
         contentType:@"text/plain; charset=utf-8"
                body:[@"Module route not found" dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  if ([module.runtimeType isEqualToString:@"process-runtime"]) {
    [self executeProcessRuntimeRouteWithModule:module
                                         route:route
                                    components:components
                                      toSocket:clientSocket];
    return;
  }

  if (![module.runtimeType isEqualToString:@"process-web"]) {
    [self sendStatus:404
              reason:@"Not Found"
         contentType:@"text/plain; charset=utf-8"
                body:[@"Module route not found" dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  NSDictionary* status = [runtimeManager_ startProcessWebRuntimeIfNeededForModule:module
                                                            additionalEnvironment:[self processEnvironmentForModule:module]
                                                                            error:&error];
  NSString* baseURL = [status[@"baseUrl"] isKindOfClass:NSString.class] ? status[@"baseUrl"] : @"";
  if (baseURL.length == 0) {
    NSString* message = error.localizedDescription ?: @"Unable to start module runtime.";
    [self sendStatus:502
              reason:@"Bad Gateway"
         contentType:@"text/plain; charset=utf-8"
                body:[message dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  NSURL* targetURL = [self targetURLWithBaseURL:baseURL
                                          route:[self processWebTargetRouteForModule:module publicRoute:route]
                               sourceComponents:components];
  if (!targetURL) {
    [self sendStatus:502
              reason:@"Bad Gateway"
         contentType:@"text/plain; charset=utf-8"
                body:[@"Unable to build module target URL" dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  [self proxyGETToURL:targetURL
               module:module
                route:route
           sourceURL:[self queryValueForName:@"sourceUrl" components:components]
       requestHeaders:headers
            toSocket:clientSocket];
}

- (NSString*)processWebTargetRouteForModule:(BabelNativeModuleManifest*)module publicRoute:(NSString*)route {
  if ([module.moduleType isEqualToString:@"viewer"]) {
    return @"render";
  }

  return route ?: @"";
}

- (void)executeProcessRuntimeRouteWithModule:(BabelNativeModuleManifest*)module
                                       route:(NSString*)route
                                  components:(NSURLComponents*)components
                                    toSocket:(int)clientSocket {
  NSError* error = nil;
  NSString* fileTypes = [moduleRegistry_ fileTypeHeaderValueWithError:nil] ?: @"";
  NSDictionary* response = [runtimeManager_ executeProcessRuntimeForModule:module
                                                                     route:route
                                                                 sourceURL:[self queryValueForName:@"sourceUrl" components:components]
                                                       localServiceBaseURL:[self baseURLString]
                                                         localServiceToken:token_ ?: @""
                                                                queryItems:components.queryItems ?: @[]
                                                                 fileTypes:fileTypes
                                                                      hook:[self queryValueForName:@"hook" components:components]
                                                                     error:&error];
  if (!response) {
    NSString* message = error.localizedDescription ?: @"Module process-runtime route could not be executed.";
    [self sendStatus:502
              reason:@"Bad Gateway"
         contentType:@"text/plain; charset=utf-8"
                body:[message dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  NSInteger status = [response[@"statusCode"] isKindOfClass:NSNumber.class] ? [response[@"statusCode"] integerValue] : 200;
  NSString* contentType = [response[@"contentType"] isKindOfClass:NSString.class]
      ? response[@"contentType"]
      : @"application/octet-stream";
  NSDictionary* headers = [response[@"headers"] isKindOfClass:NSDictionary.class] ? response[@"headers"] : @{};
  NSData* body = [response[@"body"] isKindOfClass:NSData.class] ? response[@"body"] : [NSData data];
  NSMutableDictionary<NSString*, NSString*>* responseHeaders = [NSMutableDictionary dictionary];
  for (id key in headers) {
    id value = headers[key];
    if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class]) {
      responseHeaders[key] = value;
    }
  }
  responseHeaders[@"Content-Type"] = contentType;

  [self sendStatus:status
            reason:[self reasonForStatus:status]
           headers:responseHeaders
              body:body
          toSocket:clientSocket];
}

- (void)serveModuleAssetWithComponents:(NSURLComponents*)components
                        pathComponents:(NSArray<NSString*>*)pathComponents
                              toSocket:(int)clientSocket {
  NSString* moduleIdentifier = pathComponents[2];
  NSString* assetPath = [[pathComponents subarrayWithRange:NSMakeRange(4, pathComponents.count - 4)]
      componentsJoinedByString:@"/"];

  NSError* error = nil;
  BabelNativeModuleManifest* module = [moduleRegistry_ moduleWithIdentifier:moduleIdentifier error:&error];
  if (!module || !module.enabled || assetPath.length == 0) {
    [self sendStatus:404
              reason:@"Not Found"
         contentType:@"text/plain; charset=utf-8"
                body:[@"Module asset not found" dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  NSString* publicDirectory = [[module.path stringByAppendingPathComponent:@"public"] stringByStandardizingPath];
  NSString* candidate = [[publicDirectory stringByAppendingPathComponent:assetPath] stringByStandardizingPath];
  if (![candidate hasPrefix:[publicDirectory stringByAppendingString:@"/"]]) {
    [self sendStatus:403
              reason:@"Forbidden"
         contentType:@"text/plain; charset=utf-8"
                body:[@"Forbidden" dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  NSData* data = [NSData dataWithContentsOfFile:candidate];
  BOOL isDirectory = NO;
  if (data.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:candidate isDirectory:&isDirectory] ||
      isDirectory) {
    [self sendStatus:404
              reason:@"Not Found"
         contentType:@"text/plain; charset=utf-8"
                body:[@"Module asset not found" dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  [self sendStatus:200
            reason:@"OK"
       contentType:[self mimeTypeForPath:candidate]
              body:data
          toSocket:clientSocket];
}

- (NSURL*)targetURLWithBaseURL:(NSString*)baseURL
                         route:(NSString*)route
              sourceComponents:(NSURLComponents*)sourceComponents {
  NSURLComponents* components = [NSURLComponents componentsWithString:baseURL ?: @""];
  if (!components) {
    return nil;
  }

  components.path = [@"/" stringByAppendingString:[route stringByTrimmingCharactersInSet:
      [NSCharacterSet characterSetWithCharactersInString:@"/"]]];
  NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
  for (NSURLQueryItem* item in sourceComponents.queryItems ?: @[]) {
    if (![item.name isEqualToString:@"token"]) {
      [queryItems addObject:item];
    }
  }
  components.queryItems = queryItems.count > 0 ? queryItems : nil;

  return components.URL;
}

- (void)proxyGETToURL:(NSURL*)targetURL
               module:(BabelNativeModuleManifest*)module
                route:(NSString*)route
             sourceURL:(NSString*)sourceURL
        requestHeaders:(NSDictionary*)requestHeaders
              toSocket:(int)clientSocket {
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:targetURL];
  request.HTTPMethod = @"GET";
  request.timeoutInterval = 30;
  NSString* userAgent = [requestHeaders[@"user-agent"] isKindOfClass:NSString.class]
      ? requestHeaders[@"user-agent"]
      : @"BabelChrome NativeModuleHTTPHost";
  [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
  [request setValue:module.moduleIdentifier ?: @"" forHTTPHeaderField:@"X-BabelChrome-Module-Id"];
  [request setValue:route ?: @"" forHTTPHeaderField:@"X-BabelChrome-Module-Route"];
  [request setValue:sourceURL ?: @"" forHTTPHeaderField:@"X-BabelChrome-Source-Url"];
  [request setValue:[self queryValueForName:@"sourceId" components:targetURL ? [NSURLComponents componentsWithURL:targetURL resolvingAgainstBaseURL:NO] : nil]
      forHTTPHeaderField:@"X-BabelChrome-Source-Id"];
  [request setValue:[self baseURLString] forHTTPHeaderField:@"X-BabelChrome-Local-Service-Base-Url"];
  [request setValue:token_ ?: @"" forHTTPHeaderField:@"X-BabelChrome-Local-Service-Token"];
  [request setValue:[self assetBaseURLStringForModule:module]
      forHTTPHeaderField:@"X-BabelChrome-Module-Asset-Base-Url"];
  [request setValue:[self assetTokenQueryString]
      forHTTPHeaderField:@"X-BabelChrome-Module-Asset-Token-Query"];
  NSString* fileTypes = [moduleRegistry_ fileTypeHeaderValueWithError:nil];
  if (fileTypes.length > 0) {
    [request setValue:fileTypes forHTTPHeaderField:@"X-BabelChrome-File-Types"];
  }

  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block NSData* responseData = nil;
  __block NSHTTPURLResponse* httpResponse = nil;
  __block NSError* responseError = nil;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
  NSURLSessionDataTask* task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                                            responseData = data;
                                            responseError = error;
                                            if ([response isKindOfClass:NSHTTPURLResponse.class]) {
                                              httpResponse = (NSHTTPURLResponse*)response;
                                            }
                                            dispatch_semaphore_signal(semaphore);
                                          }];
  [task resume];
  dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 31 * NSEC_PER_SEC));
  [session finishTasksAndInvalidate];

  if (responseError || !httpResponse) {
    NSString* message = responseError.localizedDescription ?: @"Module route could not be proxied.";
    [self sendStatus:502
              reason:@"Bad Gateway"
         contentType:@"text/plain; charset=utf-8"
                body:[message dataUsingEncoding:NSUTF8StringEncoding]
            toSocket:clientSocket];
    return;
  }

  NSString* contentType = httpResponse.allHeaderFields[@"Content-Type"];
  if (![contentType isKindOfClass:NSString.class] || contentType.length == 0) {
    contentType = @"text/html; charset=utf-8";
  }

  [self sendStatus:httpResponse.statusCode
            reason:[self reasonForStatus:httpResponse.statusCode]
       contentType:contentType
              body:responseData ?: [NSData data]
          toSocket:clientSocket];
}

- (NSString*)baseURLString {
  return [NSString stringWithFormat:@"http://127.0.0.1:%lu", static_cast<unsigned long>(port_)];
}

- (NSString*)assetBaseURLStringForModule:(BabelNativeModuleManifest*)module {
  NSString* moduleIdentifier = module.moduleIdentifier ?: @"";

  return [NSString stringWithFormat:@"%@/module/%@/assets",
                                    [self baseURLString],
                                    moduleIdentifier];
}

- (NSString*)assetTokenQueryString {
  NSString* encodedToken = [token_ stringByAddingPercentEncodingWithAllowedCharacters:
      NSCharacterSet.URLQueryAllowedCharacterSet] ?: @"";

  return [@"?token=" stringByAppendingString:encodedToken];
}

- (void)serveRemoteAssetWithURLString:(NSString*)urlString
                     sourceIdentifier:(NSString*)sourceIdentifier
                              toSocket:(int)clientSocket {
  NSURL* url = [NSURL URLWithString:urlString ?: @""];
  if (!url || (![[url.scheme lowercaseString] isEqualToString:@"http"] &&
               ![[url.scheme lowercaseString] isEqualToString:@"https"])) {
    [self sendMissingImageWithIdentifier:sourceIdentifier toSocket:clientSocket];
    return;
  }

  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
  request.timeoutInterval = 8;
  [request setValue:@"BabelChrome Local Viewer" forHTTPHeaderField:@"User-Agent"];

  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block NSData* responseData = nil;
  __block NSHTTPURLResponse* httpResponse = nil;
  NSURLSession* session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.ephemeralSessionConfiguration];
  NSURLSessionDataTask* task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
                                            (void)error;
                                            responseData = data;
                                            if ([response isKindOfClass:NSHTTPURLResponse.class]) {
                                              httpResponse = (NSHTTPURLResponse*)response;
                                            }
                                            dispatch_semaphore_signal(semaphore);
                                          }];
  [task resume];
  dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 9 * NSEC_PER_SEC));
  [session finishTasksAndInvalidate];

  if (!httpResponse || httpResponse.statusCode >= 400 || responseData.length == 0) {
    [self sendMissingImageWithIdentifier:sourceIdentifier toSocket:clientSocket];
    return;
  }

  NSString* contentType = [httpResponse.allHeaderFields[@"Content-Type"] isKindOfClass:NSString.class]
      ? httpResponse.allHeaderFields[@"Content-Type"]
      : @"application/octet-stream";
  [self sendStatus:200 reason:@"OK" contentType:contentType body:responseData toSocket:clientSocket];
}

- (void)sendMissingImageWithIdentifier:(NSString*)sourceIdentifier toSocket:(int)clientSocket {
  NSString* escapedIdentifier = [self htmlEscapedString:sourceIdentifier ?: @""];
  NSString* svg = [NSString stringWithFormat:
      @"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"720\" height=\"160\" viewBox=\"0 0 720 160\" role=\"img\" aria-label=\"Missing image\">"
       "<rect width=\"720\" height=\"160\" rx=\"10\" fill=\"#fff5f5\" stroke=\"#e7b5b5\"/>"
       "<text x=\"24\" y=\"58\" fill=\"#8a1f1f\" font-family=\"-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif\" font-size=\"20\" font-weight=\"700\">Missing image</text>"
       "<text x=\"24\" y=\"94\" fill=\"#8a1f1f\" font-family=\"-apple-system, BlinkMacSystemFont, Helvetica, Arial, sans-serif\" font-size=\"14\">The linked image could not be loaded.</text>"
       "<text x=\"24\" y=\"124\" fill=\"#8a1f1f\" font-family=\"ui-monospace, SFMono-Regular, Menlo, Consolas, monospace\" font-size=\"12\">%@</text>"
       "</svg>",
      escapedIdentifier];
  [self sendStatus:404
            reason:@"Not Found"
       contentType:@"image/svg+xml; charset=utf-8"
              body:[svg dataUsingEncoding:NSUTF8StringEncoding]
          toSocket:clientSocket];
}

- (void)serveOpenWithListForExtension:(NSString*)extension toSocket:(int)clientSocket {
  NSString* normalizedExtension = [self normalizedExtension:extension];
  NSArray<NSDictionary*>* apps = [self matchingApplicationsForExtension:normalizedExtension];
  NSString* storedDefault = [self storedOpenWithDefaultForExtension:normalizedExtension];
  NSString* defaultApplication = [self applicationList:apps containsIdentifier:storedDefault]
      ? storedDefault
      : [self defaultApplicationIdentifierForExtension:normalizedExtension apps:apps];

  [self sendJSON:@{
    @"default" : defaultApplication.length > 0 ? defaultApplication : [NSNull null],
    @"apps" : apps
  } status:200 toSocket:clientSocket];
}

- (void)setOpenWithDefaultForExtension:(NSString*)extension body:(NSData*)body toSocket:(int)clientSocket {
  NSString* normalizedExtension = [self normalizedExtension:extension];
  NSDictionary* payload = [self JSONPayloadFromBody:body];
  NSString* applicationIdentifier = [payload[@"applicationId"] isKindOfClass:NSString.class]
      ? payload[@"applicationId"]
      : @"";
  NSArray<NSDictionary*>* apps = [self matchingApplicationsForExtension:normalizedExtension];
  if (![self applicationList:apps containsIdentifier:applicationIdentifier]) {
    [self sendJSON:@{@"ok" : @NO, @"error" : @"Application is not available for this extension."}
            status:400
          toSocket:clientSocket];
    return;
  }

  NSMutableDictionary* preferences = [[self readOpenWithPreferences] mutableCopy];
  preferences[normalizedExtension] = applicationIdentifier;
  if (![self writeOpenWithPreferences:preferences]) {
    [self sendJSON:@{@"ok" : @NO, @"error" : @"Unable to write Open With preferences."}
            status:500
          toSocket:clientSocket];
    return;
  }

  [self sendJSON:@{@"ok" : @YES} status:200 toSocket:clientSocket];
}

- (void)openSourceWithBody:(NSData*)body toSocket:(int)clientSocket {
  NSDictionary* payload = [self JSONPayloadFromBody:body];
  NSString* filePath = [self openWithFilePathFromPayload:payload];
  if (filePath.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:filePath]) {
    [self sendJSON:@{@"ok" : @NO, @"error" : @"File does not exist."} status:404 toSocket:clientSocket];
    return;
  }

  NSString* applicationIdentifier = [payload[@"applicationId"] isKindOfClass:NSString.class]
      ? payload[@"applicationId"]
      : @"";
  NSURL* fileURL = [NSURL fileURLWithPath:filePath];
  NSURL* applicationURL = applicationIdentifier.length > 0
      ? [self applicationURLForIdentifier:applicationIdentifier]
      : nil;

  dispatch_async(dispatch_get_main_queue(), ^{
    if (applicationURL) {
      NSWorkspaceOpenConfiguration* configuration = [NSWorkspaceOpenConfiguration configuration];
      [NSWorkspace.sharedWorkspace openURLs:@[ fileURL ]
                       withApplicationAtURL:applicationURL
                              configuration:configuration
                          completionHandler:nil];
      return;
    }

    [NSWorkspace.sharedWorkspace openURL:fileURL];
  });

  [self sendJSON:@{@"ok" : @YES} status:200 toSocket:clientSocket];
}

- (NSArray<NSDictionary*>*)matchingApplicationsForExtension:(NSString*)extension {
  NSMutableDictionary<NSString*, NSDictionary*>* appsByIdentifier = [NSMutableDictionary dictionary];
  for (NSString* path in [self applicationBundlePaths]) {
    NSDictionary* metadata = [self applicationMetadataForPath:path];
    NSString* applicationIdentifier = [metadata[@"applicationId"] isKindOfClass:NSString.class]
        ? metadata[@"applicationId"]
        : @"";
    if (applicationIdentifier.length == 0 ||
        ![self applicationMetadata:metadata supportsExtension:extension]) {
      continue;
    }

    appsByIdentifier[applicationIdentifier] = @{
      @"applicationId" : applicationIdentifier,
      @"name" : [metadata[@"name"] isKindOfClass:NSString.class] ? metadata[@"name"] : path.lastPathComponent,
      @"path" : path
    };
  }

  NSArray* apps = appsByIdentifier.allValues;
  return [apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* left, NSDictionary* right) {
    NSString* leftName = [left[@"name"] isKindOfClass:NSString.class] ? left[@"name"] : @"";
    NSString* rightName = [right[@"name"] isKindOfClass:NSString.class] ? right[@"name"] : @"";
    return [leftName localizedCaseInsensitiveCompare:rightName];
  }];
}

- (NSArray<NSString*>*)applicationBundlePaths {
  NSArray<NSString*>* directories = @[
    @"/Applications",
    @"/Applications/Utilities",
    @"/System/Applications",
    @"/System/Applications/Utilities",
    [NSHomeDirectory() stringByAppendingPathComponent:@"Applications"]
  ];

  NSMutableArray<NSString*>* paths = [NSMutableArray array];
  for (NSString* directory in directories) {
    NSArray<NSString*>* children = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil];
    for (NSString* child in children ?: @[]) {
      if ([child.pathExtension isEqualToString:@"app"]) {
        [paths addObject:[directory stringByAppendingPathComponent:child]];
      }
    }
  }

  return paths;
}

- (NSDictionary*)applicationMetadataForPath:(NSString*)applicationPath {
  NSString* infoPath = [[applicationPath stringByAppendingPathComponent:@"Contents"]
      stringByAppendingPathComponent:@"Info.plist"];
  NSDictionary* info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
  if (![info isKindOfClass:NSDictionary.class]) {
    return @{};
  }

  NSString* applicationIdentifier = [info[@"CFBundleIdentifier"] isKindOfClass:NSString.class]
      ? info[@"CFBundleIdentifier"]
      : @"";
  NSString* name = [info[@"CFBundleDisplayName"] isKindOfClass:NSString.class]
      ? info[@"CFBundleDisplayName"]
      : ([info[@"CFBundleName"] isKindOfClass:NSString.class] ? info[@"CFBundleName"] : applicationPath.lastPathComponent);
  NSArray* documentTypes = [info[@"CFBundleDocumentTypes"] isKindOfClass:NSArray.class]
      ? info[@"CFBundleDocumentTypes"]
      : @[];

  return @{
    @"applicationId" : applicationIdentifier,
    @"name" : name,
    @"documentTypes" : documentTypes
  };
}

- (BOOL)applicationMetadata:(NSDictionary*)metadata supportsExtension:(NSString*)extension {
  NSArray* documentTypes = [metadata[@"documentTypes"] isKindOfClass:NSArray.class]
      ? metadata[@"documentTypes"]
      : @[];
  for (NSDictionary* documentType in documentTypes) {
    if (![documentType isKindOfClass:NSDictionary.class]) {
      continue;
    }

    NSArray* extensions = [documentType[@"CFBundleTypeExtensions"] isKindOfClass:NSArray.class]
        ? documentType[@"CFBundleTypeExtensions"]
        : @[];
    for (id candidate in extensions) {
      if (![candidate isKindOfClass:NSString.class]) {
        continue;
      }
      NSString* normalizedCandidate = [self normalizedExtension:candidate];
      if ([normalizedCandidate isEqualToString:@"*"] || [normalizedCandidate isEqualToString:extension]) {
        return YES;
      }
    }

    NSArray* contentTypes = [documentType[@"LSItemContentTypes"] isKindOfClass:NSArray.class]
        ? documentType[@"LSItemContentTypes"]
        : @[];
    if ([self contentTypes:contentTypes supportExtension:extension]) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)contentTypes:(NSArray*)contentTypes supportExtension:(NSString*)extension {
  NSSet<NSString*>* textExtensions = [NSSet setWithArray:@[
    @"css", @"csv", @"htm", @"html", @"js", @"json", @"markdown", @"md", @"mdown",
    @"mermaid", @"mkd", @"mmd", @"php", @"txt", @"xml", @"yaml", @"yml"
  ]];
  NSSet<NSString*>* genericTypes = [NSSet setWithArray:@[@"public.data", @"public.item", @"public.content"]];
  NSSet<NSString*>* textTypes = [NSSet setWithArray:@[@"public.text", @"public.plain-text", @"public.source-code"]];
  for (id contentType in contentTypes) {
    if (![contentType isKindOfClass:NSString.class]) {
      continue;
    }
    if ([genericTypes containsObject:contentType]) {
      return YES;
    }
    if ([textExtensions containsObject:extension] && [textTypes containsObject:contentType]) {
      return YES;
    }
  }

  return NO;
}

- (NSString*)defaultApplicationIdentifierForExtension:(NSString*)extension apps:(NSArray<NSDictionary*>*)apps {
  if (extension.length == 0) {
    return @"";
  }

  NSString* temporaryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
      [@"babelchrome-open-with." stringByAppendingString:extension]];
  NSURL* applicationURL = [NSWorkspace.sharedWorkspace URLForApplicationToOpenURL:
      [NSURL fileURLWithPath:temporaryPath]];
  NSString* applicationIdentifier = [self applicationIdentifierForApplicationURL:applicationURL];
  return [self applicationList:apps containsIdentifier:applicationIdentifier] ? applicationIdentifier : @"";
}

- (NSString*)storedOpenWithDefaultForExtension:(NSString*)extension {
  NSDictionary* preferences = [self readOpenWithPreferences];
  return [preferences[extension] isKindOfClass:NSString.class] ? preferences[extension] : @"";
}

- (NSDictionary*)readOpenWithPreferences {
  NSData* data = [NSData dataWithContentsOfFile:[self openWithPreferencesPath]];
  if (data.length == 0) {
    return @{};
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  return [decoded isKindOfClass:NSDictionary.class] ? decoded : @{};
}

- (BOOL)writeOpenWithPreferences:(NSDictionary*)preferences {
  NSData* data = [NSJSONSerialization dataWithJSONObject:preferences ?: @{}
                                                 options:NSJSONWritingPrettyPrinted
                                                   error:nil];
  return data && [data writeToFile:[self openWithPreferencesPath] atomically:YES];
}

- (NSString*)openWithPreferencesPath {
  return [[sourceRegistry_ stateDirectoryPath] stringByAppendingPathComponent:@"open-with-preferences.json"];
}

- (BOOL)applicationList:(NSArray<NSDictionary*>*)apps containsIdentifier:(NSString*)applicationIdentifier {
  if (applicationIdentifier.length == 0) {
    return NO;
  }

  for (NSDictionary* app in apps) {
    NSString* candidate = [app[@"applicationId"] isKindOfClass:NSString.class] ? app[@"applicationId"] : @"";
    if ([candidate isEqualToString:applicationIdentifier]) {
      return YES;
    }
  }

  return NO;
}

- (NSURL*)applicationURLForIdentifier:(NSString*)applicationIdentifier {
  if (applicationIdentifier.length == 0) {
    return nil;
  }

  for (NSString* path in [self applicationBundlePaths]) {
    NSURL* applicationURL = [NSURL fileURLWithPath:path isDirectory:YES];
    if ([[self applicationIdentifierForApplicationURL:applicationURL] isEqualToString:applicationIdentifier]) {
      return applicationURL;
    }
  }

  return nil;
}

- (NSString*)applicationIdentifierForApplicationURL:(NSURL*)applicationURL {
  if (!applicationURL) {
    return @"";
  }

  NSBundle* bundle = [NSBundle bundleWithURL:applicationURL];
  return bundle.bundleIdentifier ?: @"";
}

- (NSString*)openWithFilePathFromPayload:(NSDictionary*)payload {
  NSString* sourceIdentifier = [payload[@"sourceId"] isKindOfClass:NSString.class] ? payload[@"sourceId"] : @"";
  if (sourceIdentifier.length > 0) {
    NSDictionary* source = [sourceRegistry_ sourceWithIdentifier:sourceIdentifier];
    NSString* type = [source[@"type"] isKindOfClass:NSString.class] ? source[@"type"] : @"";
    NSString* value = [source[@"value"] isKindOfClass:NSString.class] ? source[@"value"] : @"";
    if ([type isEqualToString:@"file"] && value.length > 0) {
      return value;
    }
  }

  return [payload[@"file"] isKindOfClass:NSString.class] ? payload[@"file"] : @"";
}

- (NSDictionary*)JSONPayloadFromBody:(NSData*)body {
  if (body.length == 0) {
    return @{};
  }

  id decoded = [NSJSONSerialization JSONObjectWithData:body options:0 error:nil];
  return [decoded isKindOfClass:NSDictionary.class] ? decoded : @{};
}

- (void)sendJSON:(NSDictionary*)payload status:(NSInteger)status toSocket:(int)clientSocket {
  NSData* data = [NSJSONSerialization dataWithJSONObject:payload ?: @{}
                                                 options:0
                                                   error:nil] ?: [NSData data];
  [self sendStatus:status
            reason:[self reasonForStatus:status]
       contentType:@"application/json; charset=utf-8"
              body:data
          toSocket:clientSocket];
}

- (NSString*)normalizedExtension:(NSString*)extension {
  NSString* decoded = [extension ?: @"" stringByRemovingPercentEncoding] ?: extension ?: @"";
  NSString* trimmed = [decoded stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if ([trimmed hasPrefix:@"."]) {
    trimmed = [trimmed substringFromIndex:1];
  }
  return trimmed.lowercaseString;
}

- (NSString*)htmlEscapedString:(NSString*)string {
  NSMutableString* escaped = [string mutableCopy] ?: [NSMutableString string];
  [escaped replaceOccurrencesOfString:@"&"
                            withString:@"&amp;"
                               options:0
                                 range:NSMakeRange(0, escaped.length)];
  [escaped replaceOccurrencesOfString:@"<"
                            withString:@"&lt;"
                               options:0
                                 range:NSMakeRange(0, escaped.length)];
  [escaped replaceOccurrencesOfString:@">"
                            withString:@"&gt;"
                               options:0
                                 range:NSMakeRange(0, escaped.length)];
  [escaped replaceOccurrencesOfString:@"\""
                            withString:@"&quot;"
                               options:0
                                 range:NSMakeRange(0, escaped.length)];
  return escaped;
}

- (NSDictionary<NSString*, NSString*>*)processEnvironmentForModule:(BabelNativeModuleManifest*)module {
  NSMutableDictionary<NSString*, NSString*>* environment = [NSMutableDictionary dictionary];
  environment[@"BABELCHROME_LOCAL_SERVICE_BASE_URL"] = [self baseURLString];
  environment[@"BABELCHROME_LOCAL_SERVICE_TOKEN"] = token_ ?: @"";
  environment[@"BABELCHROME_VIEWER_STATE_DIR"] = [sourceRegistry_ stateDirectoryPath] ?: @"";
  environment[@"BABELCHROME_VIEWER_TOKEN"] = token_ ?: @"";
  environment[@"BABELCHROME_MODULE_ASSET_BASE_URL"] = [self assetBaseURLStringForModule:module];
  environment[@"BABELCHROME_MODULE_ASSET_TOKEN_QUERY"] = [self assetTokenQueryString];
  NSString* fileTypes = [moduleRegistry_ fileTypeHeaderValueWithError:nil];
  if (fileTypes.length > 0) {
    environment[@"BABELCHROME_FILE_TYPES"] = fileTypes;
  }

  return environment;
}

- (NSString*)queryValueForName:(NSString*)name components:(NSURLComponents*)components {
  for (NSURLQueryItem* item in components.queryItems ?: @[]) {
    if ([item.name isEqualToString:name]) {
      return item.value ?: @"";
    }
  }

  return @"";
}

- (NSString*)mimeTypeForPath:(NSString*)path {
  NSString* extension = path.pathExtension.lowercaseString ?: @"";
  NSDictionary<NSString*, NSString*>* types = @{
    @"css" : @"text/css; charset=utf-8",
    @"html" : @"text/html; charset=utf-8",
    @"htm" : @"text/html; charset=utf-8",
    @"js" : @"text/javascript; charset=utf-8",
    @"mjs" : @"text/javascript; charset=utf-8",
    @"json" : @"application/json; charset=utf-8",
    @"svg" : @"image/svg+xml",
    @"png" : @"image/png",
    @"jpg" : @"image/jpeg",
    @"jpeg" : @"image/jpeg",
    @"gif" : @"image/gif",
    @"webp" : @"image/webp",
    @"woff" : @"font/woff",
    @"woff2" : @"font/woff2"
  };

  return types[extension] ?: @"application/octet-stream";
}

- (void)sendStatus:(NSInteger)status
            reason:(NSString*)reason
       contentType:(NSString*)contentType
              body:(NSData*)body
          toSocket:(int)clientSocket {
  [self sendStatus:status
            reason:reason
           headers:@{@"Content-Type" : contentType ?: @"application/octet-stream"}
              body:body
          toSocket:clientSocket];
}

- (void)sendStatus:(NSInteger)status
            reason:(NSString*)reason
           headers:(NSDictionary<NSString*, NSString*>*)headers
              body:(NSData*)body
          toSocket:(int)clientSocket {
  NSData* responseBody = body ?: [NSData data];
  NSMutableString* header = [NSMutableString stringWithFormat:@"HTTP/1.1 %ld %@\r\n",
                                                               static_cast<long>(status),
                                                               reason ?: @"OK"];
  for (NSString* key in headers ?: @{}) {
    NSString* value = headers[key];
    if ([key rangeOfString:@"\r"].location == NSNotFound &&
        [key rangeOfString:@"\n"].location == NSNotFound &&
        [value rangeOfString:@"\r"].location == NSNotFound &&
        [value rangeOfString:@"\n"].location == NSNotFound) {
      [header appendFormat:@"%@: %@\r\n", key, value];
    }
  }
  [header appendFormat:@"Content-Length: %lu\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n",
                       static_cast<unsigned long>(responseBody.length)];
  NSMutableData* response = [NSMutableData dataWithData:[header dataUsingEncoding:NSUTF8StringEncoding]];
  [response appendData:responseBody];

  const uint8_t* bytes = static_cast<const uint8_t*>(response.bytes);
  NSUInteger remaining = response.length;
  while (remaining > 0) {
    ssize_t written = send(clientSocket, bytes, remaining, 0);
    if (written <= 0) {
      return;
    }
    bytes += written;
    remaining -= static_cast<NSUInteger>(written);
  }
}

- (NSString*)reasonForStatus:(NSInteger)status {
  switch (status) {
    case 200:
      return @"OK";
    case 204:
      return @"No Content";
    case 400:
      return @"Bad Request";
    case 403:
      return @"Forbidden";
    case 404:
      return @"Not Found";
    case 405:
      return @"Method Not Allowed";
    case 500:
      return @"Internal Server Error";
    case 502:
      return @"Bad Gateway";
    default:
      return @"OK";
  }
}

- (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelNativeModuleHTTPHostErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Native module host failed."}];
}

@end
