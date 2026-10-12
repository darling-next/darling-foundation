#import <Foundation/NSUnitConverterLinear.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

@implementation NSUnitConverterLinear

- (instancetype)init
{
    return [self initWithCoefficient:1.0 constant:0.0];
}

- (instancetype)initWithCoefficient:(double)coefficient
{
    return [self initWithCoefficient:coefficient constant:0.0];
}

- (instancetype)initWithCoefficient:(double)coefficient constant:(double)constant
{
    self = [super init];
    if (self) {
        _coefficient = coefficient;
        _constant = constant;
    }
    return self;
}

- (double)baseUnitValueFromValue:(double)value
{
    return value * _coefficient + _constant;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
    return (baseUnitValue - _constant) / _coefficient;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
