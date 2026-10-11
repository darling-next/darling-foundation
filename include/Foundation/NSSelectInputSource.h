#import <Foundation/NSObject.h>
#import <Foundation/NSSocket.h>

enum {
    NSSelectReadEvent = 0x01,
    NSSelectWriteEvent = 0x02,
    NSSelectExceptEvent = 0x04
};

@interface NSSelectInputSource : NSObject {
    NSSocket *_socket;
    id _delegate;
    NSUInteger _eventMask;
    BOOL _isValid;
}

- initWithSocket:(NSSocket *)socket;
+ (id)socketInputSourceWithSocket:(NSSocket *)socket;

- (NSSocket *)socket;
- (id)delegate;
- (void)setDelegate:(id)object;

- (NSUInteger)selectEventMask;
- (void)setSelectEventMask:(NSUInteger)mask;

- (NSUInteger)processImmediateEvents:(NSUInteger)selectEvent;
- (BOOL)isValid;
- (void)invalidate;

@end

@interface NSObject (NSSelectInputSourceDelegate)
- (void)selectInputSource:(NSSelectInputSource *)inputSource selectEvent:(NSUInteger)selectEvent;
@end

#import <Foundation/NSRunLoop.h>

@interface NSRunLoop (NSSelectInputSource)
- (void)addInputSource:(id)source forMode:(NSString *)mode;
- (void)removeInputSource:(id)source forMode:(NSString *)mode;
@end
