#import "Browser/Modules/Runtime/NativeModuleHTTPHost.h"

#import "Browser/Modules/Registry/NativeModuleManifest.h"
#import "Browser/Modules/Registry/NativeModuleRegistry.h"
#import "Browser/Modules/Runtime/NativeModuleProcessRuntimeManager.h"

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
  dispatch_queue_t serverQueue_;
  dispatch_source_t acceptSource_;
  int serverSocket_;
  NSUInteger port_;
  NSString* token_;
}

- (instancetype)initWithModuleRegistry:(BabelNativeModuleRegistry*)moduleRegistry
                        runtimeManager:(BabelNativeModuleProcessRuntimeManager*)runtimeManager {
  self = [super init];
  if (self) {
    moduleRegistry_ = moduleRegistry;
    runtimeManager_ = runtimeManager;
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
  NSMutableArray<NSURLQueryItem*>* queryItems = [NSMutableArray array];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"token" value:token_ ?: @""]];
  if (sourceURLString.length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"sourceUrl" value:sourceURLString]];
  }
  components.queryItems = queryItems;

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
    if (![method isEqualToString:@"GET"] || !components) {
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
    if (pathComponents.count >= 5 && [pathComponents[1] isEqualToString:@"module"] &&
        [pathComponents[3] isEqualToString:@"assets"]) {
      [self serveModuleAssetWithComponents:components
                            pathComponents:pathComponents
                                  toSocket:clientSocket];
      close(clientSocket);
      return;
    }

    if (pathComponents.count >= 4 && [pathComponents[1] isEqualToString:@"module"]) {
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
  while (data.length < kBabelNativeModuleHTTPHostMaximumHeaderBytes) {
    ssize_t readCount = recv(clientSocket, buffer, sizeof(buffer), 0);
    if (readCount <= 0) {
      break;
    }

    [data appendBytes:buffer length:static_cast<NSUInteger>(readCount)];
    NSData* marker = [@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
    NSRange markerRange = [data rangeOfData:marker options:0 range:NSMakeRange(0, data.length)];
    if (markerRange.location != NSNotFound) {
      break;
    }
  }

  NSString* text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
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

  return @{
    @"method" : requestParts[0],
    @"components" : components,
    @"headers" : headers
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

- (void)proxyModuleRouteWithComponents:(NSURLComponents*)components
                        pathComponents:(NSArray<NSString*>*)pathComponents
                                headers:(NSDictionary*)headers
                              toSocket:(int)clientSocket {
  NSString* moduleIdentifier = pathComponents[2];
  NSString* route = [[pathComponents subarrayWithRange:NSMakeRange(3, pathComponents.count - 3)]
      componentsJoinedByString:@"/"];

  NSError* error = nil;
  BabelNativeModuleManifest* module = [moduleRegistry_ moduleWithIdentifier:moduleIdentifier error:&error];
  if (!module || !module.enabled || ![module.runtimeType isEqualToString:@"process-web"]) {
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

  NSURL* targetURL = [self targetURLWithBaseURL:baseURL route:route sourceComponents:components];
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

- (NSDictionary<NSString*, NSString*>*)processEnvironmentForModule:(BabelNativeModuleManifest*)module {
  NSMutableDictionary<NSString*, NSString*>* environment = [NSMutableDictionary dictionary];
  environment[@"BABELCHROME_LOCAL_SERVICE_BASE_URL"] = [self baseURLString];
  environment[@"BABELCHROME_LOCAL_SERVICE_TOKEN"] = token_ ?: @"";
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
  NSData* responseBody = body ?: [NSData data];
  NSString* header = [NSString stringWithFormat:
      @"HTTP/1.1 %ld %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n",
      static_cast<long>(status),
      reason ?: @"OK",
      contentType ?: @"application/octet-stream",
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
