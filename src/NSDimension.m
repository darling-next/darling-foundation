#import <Foundation/NSDimension.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

// NSUnitFrequency lives here rather than in its own translation unit: the Foundation target's source
// list is explicit (CMakeLists.txt) and this change is not allowed to extend a target's source list.
// NSDimension is the superclass, so the concrete dimension subclass is compiled next to it.

#import <Foundation/NSUnitFrequency.h>
#import <Foundation/NSUnitConverterLinear.h>
#import <dispatch/dispatch.h>

@implementation NSDimension

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end

@implementation NSUnitFrequency

+ (NSUnitFrequency *)hertz
{
    static NSUnitFrequency *hertz;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        hertz = [[NSUnitFrequency alloc] initWithSymbol:@"Hz"
                                              converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0]];
    });
    return hertz;
}

+ (NSUnitFrequency *)kilohertz
{
    static NSUnitFrequency *kilohertz;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        kilohertz = [[NSUnitFrequency alloc] initWithSymbol:@"kHz"
                                                  converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e3]];
    });
    return kilohertz;
}

+ (NSUnitFrequency *)megahertz
{
    static NSUnitFrequency *megahertz;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        megahertz = [[NSUnitFrequency alloc] initWithSymbol:@"MHz"
                                                  converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e6]];
    });
    return megahertz;
}

+ (NSUnitFrequency *)gigahertz
{
    static NSUnitFrequency *gigahertz;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gigahertz = [[NSUnitFrequency alloc] initWithSymbol:@"GHz"
                                                  converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e9]];
    });
    return gigahertz;
}

+ (NSUnitFrequency *)baseUnit
{
    return [self hertz];
}

- (instancetype)initWithSymbol:(NSString *)symbol converter:(NSUnitConverter *)converter
{
    self = [super init];
    if (self) {
        _symbol = [symbol copy];
        _converter = converter;
    }
    return self;
}

@end
