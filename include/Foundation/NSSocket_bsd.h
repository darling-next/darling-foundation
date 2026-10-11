#import <Foundation/NSSocket.h>

@interface NSSocket_bsd : NSSocket {
    int _descriptor;
}

- initWithDescriptor:(int)descriptor;
+ socketWithDescriptor:(int)descriptor;

- (int)descriptor;
- (void)setDescriptor:(int)descriptor;

@end
