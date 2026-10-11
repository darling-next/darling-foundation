#import <Foundation/NSObject.h>

@interface NSAutoreleasePool : NSObject
{
    void *context;
}

+ (void)addObject:(id)anObject;
- (void)addObject:(id)anObject;
- (void)drain;

@end
