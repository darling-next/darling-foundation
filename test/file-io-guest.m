#import <Foundation/Foundation.h>
#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
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
    NSString *dangling = [base stringByAppendingPathComponent:@"dangling"];
    const char target[] = "missing-target";
    check(symlink(target, [dangling fileSystemRepresentation]) == 0, "create dangling directory-collision control");
    error = nil;
    check(![manager createDirectoryAtPath:dangling withIntermediateDirectories:YES attributes:nil error:&error],
          "dangling symlink cannot satisfy intermediate-directory creation");
    check([[error domain] isEqual:NSCocoaErrorDomain] && [error code] == NSFileWriteFileExistsError,
          "non-directory EEXIST retains Cocoa file-exists error");
    underlying = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
    check([[underlying domain] isEqual:NSPOSIXErrorDomain] && [underlying code] == EEXIST,
          "non-directory collision retains underlying EEXIST");
    check([[[error userInfo] objectForKey:NSFilePathErrorKey] isEqual:dangling], "non-directory collision retains failed path");
    char destination[sizeof(target)];
    ssize_t length = readlink([dangling fileSystemRepresentation], destination, sizeof(destination));
    check(length >= 0 && (size_t)length == sizeof(target) - 1 && memcmp(destination, target, sizeof(target) - 1) == 0,
          "failed directory creation preserves dangling symlink");
    error = nil;
    check([manager removeItemAtPath:base error:&error], "remove fixture directory");
    error = nil;
    check(![manager removeItemAtPath:base error:&error], "repeated removal reports missing item");
    check([[error domain] isEqual:NSCocoaErrorDomain] && [error code] == NSFileNoSuchFileError, "missing removal has recoverable Cocoa error");
    underlying = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
    check([[underlying domain] isEqual:NSPOSIXErrorDomain] && [underlying code] == ENOENT, "missing removal retains underlying ENOENT");
    check([[[error userInfo] objectForKey:NSFilePathErrorKey] isEqual:base], "missing removal retains failed path");
}

static void symlink_operations(void) {
    char root[] = "/private/var/tmp/foundation-symlink-XXXXXX";
    if (!mkdtemp(root)) { check(NO, "create symlink fixture directory"); return; }
    NSString *base = [NSString stringWithUTF8String:root];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *target = [base stringByAppendingPathComponent:@"target.txt"];
    NSString *link = [base stringByAppendingPathComponent:@"link.txt"];
    NSData *contents = [@"link target contents" dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    check([contents writeToFile:target options:0 error:&error], "write symlink target file");
    check([manager createSymbolicLinkAtPath:link withDestinationPath:target error:&error],
          "create symbolic link at the requested path");
    struct stat info;
    check(lstat([link fileSystemRepresentation], &info) == 0 && S_ISLNK(info.st_mode),
          "the requested path is itself a symbolic link");
    char stored[PATH_MAX];
    ssize_t storedLength = readlink([link fileSystemRepresentation], stored, sizeof(stored));
    const char *destination = [target fileSystemRepresentation];
    check(storedLength == (ssize_t)strlen(destination) && memcmp(stored, destination, (size_t)storedLength) == 0,
          "link stores the requested destination");
    check([[manager destinationOfSymbolicLinkAtPath:link error:NULL] isEqualToString:target],
          "destination lookup returns the stored absolute destination");
    check([[NSData dataWithContentsOfFile:link] isEqualToData:contents],
          "reading through the link returns target contents");
    NSString *subdirectory = [base stringByAppendingPathComponent:@"sub"];
    check([manager createDirectoryAtPath:subdirectory withIntermediateDirectories:NO attributes:nil error:NULL],
          "create link destination subdirectory");
    NSString *unnormalized = [base stringByAppendingPathComponent:@"sub/../target.txt"];
    NSString *storedLink = [base stringByAppendingPathComponent:@"stored.txt"];
    check([manager createSymbolicLinkAtPath:storedLink withDestinationPath:unnormalized error:NULL],
          "create symbolic link with an unnormalized destination");
    check([[manager destinationOfSymbolicLinkAtPath:storedLink error:NULL] isEqualToString:unnormalized],
          "destination lookup returns the destination as stored, not resolved");
    check([[NSData dataWithContentsOfFile:storedLink] isEqualToData:contents],
          "unnormalized destination resolves to the target file");
    NSString *dangling = [base stringByAppendingPathComponent:@"dangling.txt"];
    NSString *missing = [base stringByAppendingPathComponent:@"missing-target.txt"];
    check([manager createSymbolicLinkAtPath:dangling withDestinationPath:missing error:NULL],
          "create dangling symbolic link");
    check([[manager destinationOfSymbolicLinkAtPath:dangling error:NULL] isEqualToString:missing],
          "dangling destination lookup succeeds");
    check(![manager fileExistsAtPath:dangling], "dangling link does not claim a target file");
    // The runtime stores destinations longer than the path buffer; the getter must return the
    // stored bytes whole instead of stopping at its buffer size.
    size_t longLength = (size_t)PATH_MAX + 512;
    char *longTarget = malloc(longLength + 1);
    char *longStored = malloc(longLength + 1);
    check(longTarget != NULL && longStored != NULL, "allocate long destination fixture");
    if (longTarget != NULL && longStored != NULL) {
        longTarget[0] = '/';
        memset(longTarget + 1, 'x', longLength - 1);
        longTarget[longLength] = '\0';
        NSString *longLink = [base stringByAppendingPathComponent:@"long.txt"];
        int linked = symlink(longTarget, [longLink fileSystemRepresentation]);
        check(linked == 0, "create destination longer than the runtime path buffer");
        if (linked == 0) {
            ssize_t storedLong = readlink([longLink fileSystemRepresentation], longStored, longLength + 1);
            check(storedLong == (ssize_t)longLength && memcmp(longStored, longTarget, longLength) == 0,
                  "filesystem preserves the complete long destination");
            if (storedLong > 0 && (size_t)storedLong <= longLength) {
                longStored[storedLong] = '\0';
                NSString *longDestination = [manager destinationOfSymbolicLinkAtPath:longLink error:NULL];
                const char *longDestinationBytes = [longDestination UTF8String];
                check(longDestinationBytes != NULL &&
                      [longDestination length] == (NSUInteger)storedLong &&
                      strcmp(longDestinationBytes, longStored) == 0,
                      "destination lookup returns a stored target longer than the path buffer");
            }
        }
    }
    free(longTarget);
    free(longStored);
    error = nil;
    check(![manager createSymbolicLinkAtPath:link withDestinationPath:target error:&error],
          "existing link path rejects a second link");
    check([[error domain] isEqual:NSCocoaErrorDomain] && [error code] == NSFileWriteFileExistsError,
          "existing link path has Cocoa file-exists error");
    check([[[error userInfo] objectForKey:NSFilePathErrorKey] isEqual:link],
          "existing link path retains the failed path");
    NSError *underlying = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
    check([[underlying domain] isEqual:NSPOSIXErrorDomain] && [underlying code] == EEXIST,
          "existing link path retains underlying EEXIST");
    error = nil;
    check([manager removeItemAtPath:base error:&error], "remove symlink fixture directory");
}

static void check_paths(NSArray *actual, NSArray *expected, const char *operation) {
    check(actual != nil && [actual count] == [expected count] &&
          [[NSSet setWithArray:actual] isEqualToSet:[NSSet setWithArray:expected]], operation);
}

static void directory_subpaths(void) {
    char root[] = "/private/var/tmp/foundation-subpaths-XXXXXX";
    if (!mkdtemp(root)) { check(NO, "create recursive fixture directory"); return; }
    NSString *base = [NSString stringWithUTF8String:root];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *directories = @[@"empty", @"left", @"left/deep", @"right"];
    NSDictionary *contents = @{
        @"same.swift": @"root contents",
        @"left/same.swift": @"left contents",
        @"left/deep/unique.swift": @"deep contents",
        @"right/same.swift": @"right contents",
        @"leaf-link.swift": @"left contents"
    };
    for (NSString *directory in directories) {
        check([manager createDirectoryAtPath:[base stringByAppendingPathComponent:directory]
                withIntermediateDirectories:NO attributes:nil error:NULL], "create nested fixture directory");
    }
    for (NSString *path in contents) {
        if ([path isEqualToString:@"leaf-link.swift"]) continue;
        check([[contents objectForKey:path] writeToFile:[base stringByAppendingPathComponent:path]
                atomically:NO encoding:NSUTF8StringEncoding error:NULL], "write distinct nested fixture contents");
    }
    check(symlink("left/same.swift", [[base stringByAppendingPathComponent:@"leaf-link.swift"] fileSystemRepresentation]) == 0,
          "create file symlink");
    check(symlink("left", [[base stringByAppendingPathComponent:@"directory-link"] fileSystemRepresentation]) == 0,
          "create directory symlink");
    NSArray *expected = [directories arrayByAddingObjectsFromArray:[contents allKeys]];
    expected = [expected arrayByAddingObject:@"directory-link"];
    NSArray *subpaths = [manager subpathsOfDirectoryAtPath:base error:NULL];
    check_paths(subpaths, expected, "recursive paths are root-relative, distinct and do not descend symlinks");
    for (NSString *path in subpaths) {
        if (![[path pathExtension] isEqualToString:@"swift"]) continue;
        NSString *text = [NSString stringWithContentsOfFile:[base stringByAppendingPathComponent:path]
                encoding:NSUTF8StringEncoding error:NULL];
        check([text isEqualToString:[contents objectForKey:path]], "enumerated nested file resolves to its own contents");
    }
    NSArray *shallow = @[@"empty", @"left", @"right", @"same.swift", @"leaf-link.swift", @"directory-link"];
    check_paths([manager contentsOfDirectoryAtPath:base error:NULL], shallow, "shallow string listing stays shallow");
    NSMutableArray *urlPaths = [NSMutableArray array];
    for (NSURL *url in [manager contentsOfDirectoryAtURL:[NSURL fileURLWithPath:base]
                includingPropertiesForKeys:@[] options:0 error:NULL]) {
        [urlPaths addObject:[url path]];
    }
    NSMutableArray *expectedURLs = [NSMutableArray array];
    for (NSString *path in shallow) [expectedURLs addObject:[base stringByAppendingPathComponent:path]];
    check_paths(urlPaths, expectedURLs, "URL listing retains complete child paths");
    check([manager removeItemAtPath:base error:NULL], "remove recursive fixture directory");
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
            symlink_operations();
            directory_subpaths();
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
