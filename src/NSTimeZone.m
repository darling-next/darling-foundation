//
//  NSTimeZone.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSTimeZone.h>
#import <Foundation/NSPortCoder.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSData.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import "NSObjectInternal.h"

@implementation NSTimeZone (NSTimeZone)

// Keyed archive contract from vendored corelibs NSTimeZone.swift and its native
// sibling adaptation; retain the existing named/data-backed creation routes.
OBJC_PROTOCOL_IMPL_PUSH
- (id)initWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"NSTimeZone requires a keyed coder"];
        return nil;
    }
    NSString *name = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.name"];
    NSData *data = [coder decodeObjectOfClass:[NSData class] forKey:@"NS.data"];
    if (![name isKindOfClass:[NSString class]] || (data != nil && ![data isKindOfClass:[NSData class]]))
    {
        [self release];
        return nil;
    }
    return [data length] > 0 ? [self initWithName:name data:data] : [self initWithName:name];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
    {
        [NSException raise:NSInvalidArgumentException format:@"NSTimeZone requires a keyed coder"];
    }
    [coder encodeObject:[self name] forKey:@"NS.name"];
    [coder encodeObject:[self data] forKey:@"NS.data"];
}
OBJC_PROTOCOL_IMPL_POP

- (Class)classForCoder
{
    return [NSTimeZone self];
}

@end

@implementation NSTimeZone (NSTimeZonePortCoding)

- (id) replacementObjectForPortCoder: (NSPortCoder *) portCoder {
    if ([portCoder isByref]) {
        return [super replacementObjectForPortCoder: portCoder];
    }
    return self;
}

@end
