//
//  NSDictionary.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSDictionary.h>

#import <Foundation/NSArray.h>
#import "NSCoderInternal.h"
#import <Foundation/NSData.h>
#import "NSObjectInternal.h"
#import <Foundation/NSString.h>
#import "NSStringInternal.h"
#import "NSSharedKeySet.h"
#import "NSSharedKeyDictionary.h"
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSPortCoder.h>

#import <CoreFoundation/CFData.h>
#import <CoreFoundation/CFBase.h>
#import <CoreFoundation/CFPropertyList.h>

#import <Foundation/NSError.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSURLError.h>
#import <Foundation/FoundationErrors.h>
#import "_NSFileIO.h"

#import <stdio.h>
#import <stdlib.h>
#import "NSExternals.h"

@implementation NSDictionary (NSDictionary)

+ (id)newWithContentsOf:(id)source immutable:(BOOL)immutable
{
    return [self newWithContentsOf:source immutable:immutable error:NULL];
}

// The error-returning variant exists so the error-returning public APIs
// (+[NSDictionary dictionaryWithContentsOfURL:error:], -[NSDictionary initWithContentsOfURL:error:])
// can report WHY the contents could not be read. The reader used to discard both reasons: the failed
// file read and the property list's own CFError, so its callers invented one
// (NSDictionaryErrorDomain, code -1), which matches nothing a caller can act on.
+ (id)newWithContentsOf:(id)source immutable:(BOOL)immutable error:(NSError **)error
{
    NSError *readError = nil;
    NSData *data = nil;

    if ([source isNSString__])
    {
        data = [[NSData alloc] initWithContentsOfFile:source options:0 error:&readError];
    }
    else
    {
        data = [[NSData alloc] initWithContentsOfURL:source options:0 error:&readError];
    }

    if (data == nil)
    {
        if (error != NULL)
        {
            // -[NSData initWithContentsOf{File,URL}:options:error:] reports the errno of the failed
            // open(2)/read(2) in NSPOSIXErrorDomain; Foundation reports the same failure in
            // NSCocoaErrorDomain with the NSFileRead* code for that errno and the POSIX error as
            // NSUnderlyingError, which is what _NSErrorWithFilePathErrnoAndVariant constructs.
            if ([[readError domain] isEqualToString:NSPOSIXErrorDomain])
            {
                *error = _NSErrorWithFilePathErrnoAndVariant((int)[readError code], source, 1, 0);
            }
            else
            {
                *error = readError;
            }
        }
        return nil;
    }

    CFErrorRef plistError = NULL;
    CFDictionaryRef plist = (CFDictionaryRef)CFPropertyListCreateWithData(kCFAllocatorDefault, (CFDataRef)data, immutable ? kCFPropertyListImmutable : kCFPropertyListMutableContainers, NULL, &plistError);
    [data release];

    if (plistError != NULL)
    {
        if (error != NULL)
        {
            // The property list's own error, in the Cocoa domain with the
            // NSPropertyList*/kCFPropertyList* code it was created with. Handing it to the
            // autorelease pool transfers the +1 the parser's CFErrorRef carries.
            *error = [(NSError *)plistError autorelease];
        }
        else
        {
            CFRelease(plistError);
        }
    }

    id dict = nil;
    if (immutable)
    {
        dict = [[NSDictionary alloc] initWithDictionary:(NSDictionary *)plist];
    }
    else
    {
        dict = [[NSMutableDictionary alloc] initWithDictionary:(NSMutableDictionary *)plist];
    }
    if (plist != nil)
    {
        CFRelease(plist);
    }
    return dict;
}

// Apple's current Foundation exposes -[NSDictionary writeToURL:error:] (public write(to:));
// the vendored CoreFoundation bridge only carries the legacy Boolean-only atomically
// overloads, and neither darling-foundation upstream a8b5ab1 nor the VibeDarling sibling
// implements this selector. Do not route through the legacy writer: that drops NSError and
// would fabricate success for invalid property lists. Serialize with the same CF property
// list writer the readers use, then hand the bytes to the shared error-preserving NSData
// writer so serialization and I/O failures remain distinguishable. Declared here on the
// public base class; __NSCFDictionary and other subclasses inherit it by ordinary dispatch.
- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error
{
    CFErrorRef plistError = NULL;
    CFDataRef data = CFPropertyListCreateData(kCFAllocatorDefault,
        (CFPropertyListRef)self, kCFPropertyListXMLFormat_v1_0, 0, &plistError);
    if (data == NULL)
    {
        if (error != NULL)
        {
            if (plistError != NULL)
            {
                *error = [(NSError *)plistError autorelease];
            }
            else
            {
                // CFPropertyListCreateData reports an invalid plist value on its own stream
                // but can return NULL without a CFError. The public Foundation write
                // contract reports this serialization failure as
                // NSPropertyListWriteStreamError (3851), and the destination stays untouched.
                *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                             code:NSPropertyListWriteStreamError
                                         userInfo:nil];
            }
        }
        else if (plistError != NULL)
        {
            CFRelease(plistError);
        }
        return NO;
    }
    if (plistError != NULL)
    {
        CFRelease(plistError);
    }

    if (url != nil && ![url isFileURL])
    {
        if (error != NULL)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSFileWriteUnsupportedSchemeError
                                     userInfo:@{NSURLErrorKey: url}];
        }
        CFRelease(data);
        return NO;
    }

    NSError *writeError = nil;
    BOOL success = [(NSData *)data writeToURL:url options:0 error:&writeError];
    CFRelease(data);
    if (!success && error != NULL)
    {
        if ([[writeError domain] isEqualToString:NSPOSIXErrorDomain])
        {
            *error = _NSErrorWithFilePathErrnoAndVariant((int)[writeError code], url, 0, 0);
        }
        else
        {
            *error = writeError;
        }
    }
    return success;
}

OBJC_PROTOCOL_IMPL_PUSH
- (id)initWithCoder:(NSCoder *)coder
{
#warning TODO: Fix fault cases to replicate behavior
    NSUInteger count = 0;
    id *objects = NULL;
    id *keys = NULL;
    if ([coder allowsKeyedCoding])
    {
        if ([coder isKindOfClass: [NSKeyedUnarchiver class]] || [coder isKindOfClass: [NSXPCCoder class]])
        {
            NSArray *objectArray = [coder _decodeArrayOfObjectsForKey:NS_objects];
            NSArray *keyArray = [coder _decodeArrayOfObjectsForKey:NS_keys];
            count = [objectArray count];
            if (count != [keyArray count])
            {
                // Let this fault in initWithObjects:forKeys:?
            }
            if (objectArray == NULL || keyArray == NULL)
            {
                [self release];
                return nil;
            }
            else
            {
                return [self initWithObjects:objectArray forKeys:keyArray];
            }
        }
        else
        {
            NSUInteger capacity = 31;
            NSUInteger index = 0;
            objects = malloc(capacity * sizeof(id));
            keys = malloc(capacity * sizeof(id));
            if (objects == NULL || keys == NULL)
            {
                free(objects);
                free(keys);
                [self release];
                [NSException raise:NSMallocException format:@"Could not allocate buffer"];
                return nil;
            }
            id key = nil;
            id object = nil;
            do {

                if (index + 1 > capacity)
                {
                    capacity *= 2;
                    id *newObjects = realloc(objects, capacity * sizeof(id));
                    id *newKeys = realloc(keys, capacity * sizeof(id));
                    if (objects == NULL || keys == NULL)
                    {
                        free(objects);
                        free(keys);
                        free(newObjects);
                        free(newKeys);
                        [self release];
                        [NSException raise:NSMallocException format:@"Could not allocate buffer"];
                        return nil;
                    }
                }

                key = [coder decodeObjectForKey:[NSString stringWithFormat:@"NS.key.%d", index]];
                object = [coder decodeObjectForKey:[NSString stringWithFormat:@"NS.object.%d", index]];
                // NS.key.# and NS.object.# being nil signify the end of the list
                if (key != nil && object == nil)
                {
                    // fault?
                }
                else if (object != nil)
                {
                    objects[index] = object;
                    keys[index] = key;
                    index++;
                }
                count = index;
            } while (key != nil && object != nil);
        }
    }
    else
    {
        [coder decodeValueOfObjCType:@encode(int) at:&count];

        objects = malloc(count * sizeof(id));
        keys = malloc(count *sizeof(id));
        if (objects == NULL || keys == NULL)
        {
            free(objects);
            free(keys);
            [self release];
            [NSException raise:NSMallocException format:@"Could not allocate buffer"];
            return nil;
        }
        for (NSUInteger idx = 0; idx < count; idx++)
        {
            id key = nil;
            id object = nil;
            [coder decodeValueOfObjCType:@encode(id) at:&key];
            [coder decodeValueOfObjCType:@encode(id) at:&object];
            if (key == nil || object == nil)
            {
                // fault?
            }
            keys[idx] = [key autorelease];
            objects[idx] = [object autorelease];
        }
    }
    NSDictionary *dict = nil;
    if (objects != NULL && keys != NULL)
    {
        dict = [self initWithObjects:objects forKeys:keys count:count];
    }

    if (objects != NULL)
    {
        free(objects);
    }

    if (keys != NULL)
    {
        free(keys);
    }
    return dict;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
#warning TODO: Fix fault cases to replicate behavior
    NSUInteger count = [self count];
    if ([aCoder allowsKeyedCoding])
    {
        if ([aCoder isKindOfClass: [NSKeyedArchiver class]] || [aCoder isKindOfClass: [NSXPCCoder class]])
        {
            id *objects = malloc(count * sizeof(id));
            id *keys = malloc(count * sizeof(id));
            if (objects == NULL || keys == NULL)
            {
                free(objects);
                free(keys);
                [NSException raise:NSMallocException format:@"Could not allocate buffer"];
                return;
            }
            [self getObjects:objects andKeys:keys];

            NSArray *keyArray = [[NSArray alloc] initWithObjects:keys count:count];
            [aCoder _encodeArrayOfObjects:keyArray forKey:NS_keys];
            [keyArray release];
            free(keys);

            NSArray *objectArray = [[NSArray alloc] initWithObjects:objects count:count];
            [aCoder _encodeArrayOfObjects:objectArray forKey:NS_objects];
            [objectArray release];
            free(objects);
        }
        else
        {
            NSUInteger idx = 0;
            for (id key in self)
            {
                [aCoder encodeObject:key forKey:[NSString stringWithFormat:@"NS.key.%d", idx]];
                [aCoder encodeObject:[self objectForKey:key] forKey:[NSString stringWithFormat:@"NS.object.%d", idx]];
            }
        }
    }
    else
    {
        [aCoder encodeValueOfObjCType:@encode(int) at:&count];
        NSEnumerator *enumerator = [self keyEnumerator];
        id key = [enumerator nextObject];
        while (key != nil)
        {
            [aCoder encodeBycopyObject:key];
            [aCoder encodeBycopyObject:[self objectForKey:key]];
            key = [enumerator nextObject];
        }
    }
}
OBJC_PROTOCOL_IMPL_POP

// Use stable public coder classes, including for Swift-bridged subclasses.
- (Class)classForCoder
{
    if ([self isKindOfClass:[NSMutableDictionary class]])
    {
        return [NSMutableDictionary class];
    }
    return [NSDictionary class];
}

- (NSString *)descriptionInStringsFileFormat
{
    NSMutableString *description = [[NSMutableString alloc] init];
    NSEnumerator *enumerator = [self keyEnumerator];
    id key = [enumerator nextObject];
    while (key != nil)
    {
        [description appendFormat:@"%@ = %@;", [key quotedStringRepresentation], [(NSString *)[self objectForKey:key] quotedStringRepresentation]];
        key = [enumerator nextObject];
        if (key == nil)
        {
            [description appendString:@"\n"];
        }
    }
    NSString *desc = [description copy];
    [description release];
    return [desc autorelease];
}

@end

@implementation NSDictionary (NSKeyValueCoding)

- (id)valueForKeyPath:(id)idKeyPath
{
    if (!idKeyPath)
    {
        return nil;
    }

    NSString *key = [idKeyPath description];
    NSRange remainderRange = [key rangeOfString:@"."];
    NSString *remainderPath = nil;

    if (remainderRange.location != NSNotFound)
    {
        remainderPath = @"";
        NSString *subkey = [key substringWithRange:NSMakeRange(0, remainderRange.location)];
        if (remainderRange.location < [key length]-1)
        {
            remainderPath = [key substringFromIndex:remainderRange.location+1];
        }
        key = subkey;
    }

    if (![key hasPrefix:@"@"])
    {
        id aVal = [self valueForKey:key];
        if (!remainderPath)
        {
            return aVal;
        }
        return [aVal valueForKeyPath:remainderPath];
    }

    // handle @operators

    if ([key isEqualToString:@"@count"])
    {
        if (remainderPath)
        {
            @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:@"this class does not implement the count operation." userInfo:nil];
            return nil;
        }
        return [NSNumber numberWithUnsignedInteger:[self count]];
    }

    if (remainderPath)
    {
        @throw [NSException exceptionWithName:@"NSInvalidArgumentException" reason:[NSString stringWithFormat:@"this class does not implement the %@ operation.", key] userInfo:nil];
        return nil;
    }

#warning TODO : FIXME what is userInfo here?
    @throw [NSException exceptionWithName:@"NSUnknownKeyException" reason:[NSString stringWithFormat:@"this class is not key value coding-compliant for the key %@.", key] userInfo:self];
    return nil;
}

- (id)valueForKey:(id)key
{
    return [self objectForKey:key];
}

@end

@implementation NSMutableDictionary (NSKeyValueCoding)

- (void)setValue:(id)value forKey:(NSString *)key
{
    if (value) {
        [self setObject:value forKey:key];
    } else {
        [self removeObjectForKey:key];
    }
}

@end


@implementation NSDictionary (NSSharedKeySetDictionary)

+ (id)sharedKeySetForKeys:(NSArray *)keys
{
    if (keys == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"keys cannot be nil"];
        return nil;
    }
    if (![keys isNSArray__])
    {
        [NSException raise:NSInvalidArgumentException format:@"keys must be an array"];
        return nil;
    }
    return [NSSharedKeySet keySetWithKeys:keys];
}

@end

@implementation NSMutableDictionary (NSSharedKeySetDictionary)

+ (id)dictionaryWithSharedKeySet:(id)keyset
{
    return [NSSharedKeyDictionary sharedKeyDictionaryWithKeySet:keyset];
}

@end

@implementation NSDictionary (NSDictionaryPortCoding)

- (id) replacementObjectForPortCoder: (NSPortCoder *) portCoder {
    if ([portCoder isByref]) {
        return [super replacementObjectForPortCoder: portCoder];
    }
    return self;
}

@end
