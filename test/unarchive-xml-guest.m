#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
static void check(BOOL condition, const char *name)
{
    if (!condition) {
        fprintf(stderr, "FAIL XML unarchive: %s\n", name);
        failures++;
    }
}

static NSData *archive(BOOL top, BOOL objects)
{
    NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        @100000, @"$version", @"NSKeyedArchiver", @"$archiver", nil];
    if (top) [plist setObject:[NSDictionary dictionary] forKey:@"$top"];
    if (objects) [plist setObject:[NSArray arrayWithObject:@"$null"] forKey:@"$objects"];
    return [NSPropertyListSerialization dataWithPropertyList:plist
        format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
}

static void missing_entry(BOOL top, BOOL objects)
{
    NSData *data = archive(top, objects);
    check(data != nil, "serialize malformed archive");
    NSError *error = nil;
    id result = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:data error:&error];
    check(result == nil, "malformed archive has no result");
    check([[error domain] isEqual:NSCocoaErrorDomain] && [error code] == 4864,
        "malformed archive reports Cocoa corrupt-archive error");
    check([NSKeyedUnarchiver unarchiveTopLevelObjectWithData:data error:NULL] == nil,
        "null error output still rejects malformed archive");
    BOOL caught = NO;
    @try {
        NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        [decoder release];
    } @catch (NSException *exception) {
        caught = [[exception name] isEqual:NSInvalidUnarchiveOperationException];
    }
    check(caught, "legacy initializer raises invalid-unarchive exception");
}

int main(void)
{
    @autoreleasepool {
        for (int i = 0; i < 32; i++) {
            @autoreleasepool {
                missing_entry(YES, NO);
                missing_entry(NO, YES);
                missing_entry(NO, NO);
            }
        }
        NSData *valid = [NSKeyedArchiver archivedDataWithRootObject:@73];
        NSError *error = nil;
        id result = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:valid error:&error];
        // The NSError out-parameter is only meaningful on failure; success asserts the
        // consumer-visible decoded value, not whether the coder happened to touch it.
        check([result isEqual:@73], "valid decode after rejected archives");
    }
    printf("XML-UNARCHIVE failures=%d\n", failures);
    return failures != 0;
}
