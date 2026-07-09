#import "Browser/Modules/Runtime/NativeModulePortAllocator.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

static NSString* const kBabelNativeModulePortAllocatorErrorDomain =
    @"fr.babelforge.babel-chrome.native-module-port-allocator";

@implementation BabelNativeModulePortAllocator

- (NSNumber*)availableLocalPortWithError:(NSError**)error {
  int descriptor = socket(AF_INET, SOCK_STREAM, 0);
  if (descriptor < 0) {
    [self assignError:error description:@"Unable to create a local TCP socket."];
    return nil;
  }

  struct sockaddr_in address;
  memset(&address, 0, sizeof(address));
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = htons(0);

  if (bind(descriptor, reinterpret_cast<struct sockaddr*>(&address), sizeof(address)) != 0) {
    close(descriptor);
    [self assignError:error description:@"Unable to bind a local TCP socket."];
    return nil;
  }

  socklen_t addressLength = sizeof(address);
  if (getsockname(descriptor, reinterpret_cast<struct sockaddr*>(&address), &addressLength) != 0) {
    close(descriptor);
    [self assignError:error description:@"Unable to read the allocated local TCP port."];
    return nil;
  }

  int port = ntohs(address.sin_port);
  close(descriptor);

  if (port <= 0) {
    [self assignError:error description:@"Allocated local TCP port is invalid."];
    return nil;
  }

  return @(port);
}

- (void)assignError:(NSError**)error description:(NSString*)description {
  if (!error) {
    return;
  }

  *error = [NSError errorWithDomain:kBabelNativeModulePortAllocatorErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : description ?: @"Unable to allocate module port."}];
}

@end
