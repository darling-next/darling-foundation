#import <Foundation/NSObject.h>
#import <CoreFoundation/CoreFoundation.h>

@class NSError, NSHost, NSData;

@interface NSSocket : NSObject

- initWithFileDescriptor:(int)descriptor;
- initConnectedToSocket:(NSSocket **)other;
- initTCPStream;

- (int)fileDescriptor;
- (NSError *)close;
- (NSError *)connectToHost:(NSHost *)host port:(NSInteger)port immediate:(BOOL *)immediate;
- (BOOL)hasBytesAvailable;

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)length;
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)length;
- (NSSocket *)acceptWithError:(NSError **)errorp;

@end
