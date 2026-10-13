//
//  NSDate.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSDate.h>

#import "NSExternals.h"
#import "NSObjectInternal.h"

#import <Foundation/NSCoder.h>
#import <Foundation/NSPortCoder.h>

@implementation NSDate (NSDate)

/* +[NSDate now] is the class property Apple's NSDate.h declares in the
 * NSDateCreation category (macOS 10.15/iOS 13) and the accessor Xcode3Core's
 * -[Xcode3CommandLineBuildTool resolveErrorTriageResultBundleDestination]
 * sends on its error-printing path.  It was absent from this tree entirely --
 * no `now` selector string in the deployed Foundation -- so the error the tool
 * was trying to report was masked by the unrecognized-selector exception.
 *
 * Darwin documents `now` as an NSDate for the current date and time:
 * `+[NSDate now]` is equivalent to `+[NSDate date]`, which is the same
 * +alloc/-initWithTimeIntervalSinceReferenceDate: protocol the receiver class
 * (and any subclass that overrides alloc/init) supplies.  Implemented through
 * `self`, exactly as the neighbouring distantFuture/distantPast and date
 * constructors are, so a subclass gets its own class back. */
+ (id)now
{
    return [self date];
}

- (Class)classForCoder
{
    return [NSDate self];
}

OBJC_PROTOCOL_IMPL_PUSH
- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSTimeInterval timeInterval = 0.0;
    if ([aDecoder allowsKeyedCoding])
    {
        timeInterval = [aDecoder decodeDoubleForKey:NS_time];
    }
    else
    {
        [aDecoder decodeValueOfObjCType:@encode(NSTimeInterval) at:&timeInterval];
    }
    return [self initWithTimeIntervalSinceReferenceDate:timeInterval];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSTimeInterval timeInterval = [self timeIntervalSinceReferenceDate];
    if ([aCoder allowsKeyedCoding])
    {
        [aCoder encodeDouble:timeInterval forKey:NS_time];
    }
    else
    {
        [aCoder encodeValueOfObjCType:@encode(NSTimeInterval) at:&timeInterval];
    }
}
OBJC_PROTOCOL_IMPL_POP

@end


@implementation NSDate (NSDatePortCoding)

- (id) replacementObjectForPortCoder: (NSPortCoder *) portCoder {
    return self;
}

@end

@implementation NSCalendarDate

- (id)allocWithZone:(NSZone *)zone
{
#warning TODO implement NSCalendarDate
    DEBUG_BREAK();
    return nil;
}

@end
