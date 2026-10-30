#import <Foundation/Foundation.h>
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures;
static void check(BOOL condition, const char *operation) {
    if (!condition) {
        fprintf(stderr, "FAIL Foundation I/O: %s\n", operation);
        failures++;
    }
}

static void directory_errors(void) {
    char root[] = "/private/var/tmp/foundation-file-io-XXXXXX";
    if (!mkdtemp(root)) { check(NO, "create fixture directory"); return; }
    NSString *base = [NSString stringWithUTF8String:root];
    NSString *path = [base stringByAppendingPathComponent:@"attachments"];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    check([manager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error], "create attachment directory");
    error = nil;
    check(![manager createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error], "existing directory reports failure without intermediates");
    check([[error domain] isEqual:NSCocoaErrorDomain] && [error code] == NSFileWriteFileExistsError, "existing directory has Cocoa file-exists error");
    NSError *underlying = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
    check([[underlying domain] isEqual:NSPOSIXErrorDomain] && [underlying code] == EEXIST, "retain underlying EEXIST");
    check([[[error userInfo] objectForKey:NSFilePathErrorKey] isEqual:path], "retain failed directory path");
    error = nil;
    check([manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error], "existing directory succeeds with intermediates");
    NSString *missing = [base stringByAppendingPathComponent:@"missing/child"];
    error = nil;
    check(![manager createDirectoryAtPath:missing withIntermediateDirectories:NO attributes:nil error:&error], "missing parent fails without intermediates");
    check([[error domain] isEqual:NSCocoaErrorDomain] && [error code] == NSFileNoSuchFileError, "missing parent has Cocoa no-such-file error");
    error = nil;
    check([manager createDirectoryAtPath:missing withIntermediateDirectories:YES attributes:nil error:&error], "create missing parents recursively");
    NSData *contents = [@"attachment contents" dataUsingEncoding:NSUTF8StringEncoding];
    NSString *attachment = [path stringByAppendingPathComponent:@"first"];
    error = nil;
    check([contents writeToFile:attachment options:0 error:&error], "write attachment after repeated directory creation");
    check([[NSData dataWithContentsOfFile:attachment] isEqualToData:contents], "attachment contents preserved");
    error = nil;
    check([manager removeItemAtPath:base error:&error], "remove fixture directory");
    error = nil;
    check(![manager removeItemAtPath:base error:&error], "repeated removal reports missing item");
    check([[error domain] isEqual:NSCocoaErrorDomain] && [error code] == NSFileNoSuchFileError, "missing removal has recoverable Cocoa error");
    underlying = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
    check([[underlying domain] isEqual:NSPOSIXErrorDomain] && [underlying code] == ENOENT, "missing removal retains underlying ENOENT");
    check([[[error userInfo] objectForKey:NSFilePathErrorKey] isEqual:base], "missing removal retains failed path");
}

struct writer {
    int fd;
    const unsigned char *bytes;
    size_t length;
    int error;
};

static void *write_pipe(void *context) {
    struct writer *writer = context;
    size_t offset = 0;
    while (offset < writer->length) {
        size_t count = writer->length - offset;
        if (count > 419) count = 419;
        ssize_t written = write(writer->fd, writer->bytes + offset, count);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) { writer->error = 1; break; }
        offset += (size_t)written;
    }
    if (close(writer->fd) != 0) writer->error = 1;
    return NULL;
}

static void pipe_contents(size_t size, NSUInteger first_read) {
    unsigned char bytes[12289];
    for (size_t i = 0; i < sizeof(bytes); i++) bytes[i] = (unsigned char)(i * 37 + 11);
    int descriptors[2];
    if (pipe(descriptors) != 0) { check(NO, "create pipe"); return; }
    struct writer writer = { descriptors[1], bytes, size, 0 };
    pthread_t thread;
    if (pthread_create(&thread, NULL, write_pipe, &writer) != 0) {
        close(descriptors[0]); close(descriptors[1]);
        check(NO, "start pipe producer"); return;
    }
    NSFileHandle *handle = [[[NSFileHandle alloc] initWithFileDescriptor:descriptors[0] closeOnDealloc:YES] autorelease];
    NSData *first = [handle readDataOfLength:first_read];
    size_t expected = first_read < size ? first_read : size;
    check([first length] == expected && (expected == 0 || memcmp([first bytes], bytes, expected) == 0), "bounded pipe read returns exact bytes");
    NSData *remaining = [handle readDataToEndOfFile];
    check([remaining length] == size - expected && (size == expected || memcmp([remaining bytes], bytes + expected, size - expected) == 0), "read-to-EOF preserves all remaining bytes");
    check([[handle readDataToEndOfFile] length] == 0, "repeated EOF read is empty");
    check(pthread_join(thread, NULL) == 0 && writer.error == 0, "pipe producer completes");
    [handle closeFile];
}

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        @try {
            directory_errors();
            pipe_contents(0, 0);
            pipe_contents(17, 0);
            pipe_contents(4096, NSUIntegerMax);
            pipe_contents(4113, NSUIntegerMax);
            pipe_contents(12289, NSUIntegerMax);
            pipe_contents(12289, 5000);
        } @catch (NSException *exception) {
            fprintf(stderr, "FAIL Foundation I/O exception: %s: %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
            failures++;
        }
        printf("FOUNDATION_FILE_IO failures=%d\n", failures);
        if (failures) return 1;
        puts("FOUNDATION_FILE_IO_OK");
        return 0;
    }
}
