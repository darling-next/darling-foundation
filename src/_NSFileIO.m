//
//  _NSFileIO.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "_NSFileIO.h"

#import <Foundation/FoundationErrors.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSError.h>
#import <Foundation/NSDictionary.h>
#import <fcntl.h>
#import <errno.h>
#import <unistd.h>
#import <libkern/OSAtomic.h>
#import <stdio.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import "NSErrorInternal.h"

void *_NSReadBytesFromFile(NSString *path, NSDataReadingOptions readOptionsMask, NSUInteger *length, BOOL *vm, NSError **err)
{
    *length = 0;

    int fd = open([path UTF8String], O_RDONLY);
    if (fd < 0)
    {
        if (err != NULL)
        {
            *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]}];
        }
        return NULL;
    }
    struct stat statInfo;
    int result = fstat(fd, &statInfo);
    if (UNLIKELY(result != 0))
    {
        close(fd);
        if (err != NULL)
        {
            *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]}];
        }
        return NULL;
    }
    if (S_ISDIR(statInfo.st_mode))
    {
        close(fd);
        if (err != NULL)
        {
            *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoPermissionError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"the path %@ is a directory", path]}];
        }
        return NULL;
    }
    off_t len = statInfo.st_size;
    *length = len;

    if (readOptionsMask & NSDataReadingMappedIfSafe)
    {
        *vm = NO;
        void *bytes = mmap(0, len, PROT_READ, MAP_SHARED, fd, 0);
        if (bytes != MAP_FAILED)
        {
            *vm = YES;

            close(fd);
            return bytes;
        }
    }

    blksize_t preferred_block_size = statInfo.st_blksize;

    // Maybe a special file such as a file in the /proc or /sys virtual filesystems.
    // See http://unix.stackexchange.com/questions/80324/determining-if-a-file-system-object-is-a-procfs-sysfs-etc-virtual-file-which
    BOOL file_size_unknown = statInfo.st_size == 0;
    if (file_size_unknown)
    {
        // Keep reading file until EOF.
        len = preferred_block_size;
    }

    void *bytes = malloc(len);
    if (UNLIKELY(bytes == NULL))
    {
        if (err != NULL)
        {
            *err = [NSError _outOfMemoryError];
        }
        close(fd);
        return nil;
    }
    size_t offset = 0;

    while (offset < len)
    {
        size_t buffer_size = MIN(len - offset, preferred_block_size);
        ssize_t amt = read(fd, (char *)bytes + offset, buffer_size);
        if (amt < 0)
        {
            free(bytes);
            bytes = NULL;
            if (err != NULL)
            {
                *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]}];
            }
            break;
        }

        offset += amt;

        // if hit EOF, break regardless, otherwise we loop forever
        if (amt == 0)
        {
            len = offset;
            *length = len;
            bytes = reallocf(bytes, len);

            if (UNLIKELY(bytes == NULL))
            {
                if (err != NULL)
                {
                    *err = [NSError _outOfMemoryError];
                }
            }

            break;
        }

        if (file_size_unknown)
        {
            // Allocate more memory and continue reading
            len = offset + preferred_block_size;
            bytes = reallocf(bytes, len);

            if (UNLIKELY(bytes == NULL))
            {
                if (err != NULL)
                {
                    *err = [NSError _outOfMemoryError];
                }
                break;
            }
        }
    }

    close(fd);

    return bytes;
}

BOOL _NSWriteBytesToFile(NSData *data, id pathOrURL, NSDataWritingOptions options, NSError **errorPtr)
{
    if (![pathOrURL isNSString__])
    {
        pathOrURL = [pathOrURL path];
    }
    NSString *dest = pathOrURL;
    if ((options & NSDataWritingAtomic) != 0)
    {
        static int atomicId = 0;
        atomicId = OSAtomicIncrement32(&atomicId);
        pathOrURL = [pathOrURL stringByAppendingFormat:@".tmp%d", atomicId];
    }
    int fd = -1;
    const char *path = [pathOrURL UTF8String];
    if ((options & NSDataWritingWithoutOverwriting) != 0)
    {
        struct stat info;
        int err = lstat(path, &info);
        if (err != 0)
        {
            fd = open(path, O_WRONLY|O_TRUNC|O_CREAT, 0644);
        }
        else if (errorPtr != NULL)
        {
            *errorPtr = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:@{
                NSLocalizedDescriptionKey: @"file already exists"
            }];
        }
    }
    else
    {
        fd = open(path, O_WRONLY|O_TRUNC|O_CREAT, 0644);
        if (fd == -1 && errorPtr != NULL)
        {
            *errorPtr = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s", strerror(errno)]
            }];
        }
    }
    if (fd == -1)
    {
        return NO;
    }
    uint8_t *buffer = (uint8_t *)[data bytes];
    NSUInteger remaining = [data length];
    while (remaining > 0)
    {
        ssize_t amt = write(fd, buffer, remaining);
        if (amt < 0)
        {
            if (errno == EINTR)
            {
                continue;
            }
            else
            {
                if (errorPtr != NULL)
                {
                    *errorPtr = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                        NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s", strerror(errno)]
                    }];
                }
            }
            return NO;
        }
        else if (amt == 0)
        {
            break;
        }
        else
        {
            remaining -= amt;
            buffer += amt;
        }
    }
    close(fd);
    if (remaining == 0 && dest != pathOrURL)
    {
        if (rename([pathOrURL UTF8String], [dest UTF8String]) != -1)
        {
            return YES;
        }
        else
        {
            if (errorPtr != NULL)
            {
                *errorPtr = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%s", strerror(errno)]
                }];
            }
            return NO;
        }
    }
    else
    {
        // the error was already set hopefully by the amout being negative.
        return remaining == 0;
    }
}

// Apple's Foundation exports this private file-error constructor, and a Mach-O client binds it by
// that exact name: Xcode 26.3's DTXConnectionServices.framework (built for Mac OS X 14.0) imports
// __NSErrorWithFilePathErrnoAndVariant from ordinal 3, Foundation, and dyld stops on it.
//
// THE CALL SITE, measured from the client's own code (its image uses chained fixups, so the ABI is
// read from the stub's caller, not from a bind opcode). One call site exists in the whole image, at
// 0x1d924 in the file-opening helper of -[DTXFileDescriptorTransport initWithIncomingFilePath:
// outgoingFilePath:error:]; the registers at that call are:
//
//   rdi = *__error()  the errno of the open(2) that just failed
//   rsi = the NSString path handed to that open(2) (converted with UTF8String in the same helper)
//   rdx = (~openFlags) & 1 -- 1 for the incoming open (O_RDONLY|O_CLOEXEC, flags 0x1000000) and 0
//         for the outgoing one (O_WRONLY|O_CREAT|O_TRUNC|O_CLOEXEC, flags 0x1000601)
//   rcx = 0
//
// So the third argument is the read/write direction of the failed operation, and the fourth is a
// value the only measured caller always passes as zero.  The result is retained/autoreleased, stored
// into the caller's NSError ** and the initializer then returns nil; DTXConnectionServices reads no
// key of it by name -- it does not import NSFilePathErrorKey -- and imports NSCocoaErrorDomain,
// NSLocalizedDescriptionKey, NSDebugDescriptionErrorKey, NSUnderlyingErrorKey and _OBJC_CLASS_
// $_NSError, which is what it builds its own errors with.
//
// The error built here is Apple's: an NSCocoaErrorDomain error whose code is the NSFileRead*/NSFile
// Write* code for the errno (the mapping Apple publishes in swift-corelibs-foundation's Darwin
// overlay, Darwin/Foundation-swiftoverlay/DataThunks.m _NSErrorWithFilePathAndErrno, which this
// tree already carries), the path under NSFilePathErrorKey (NSURLErrorKey for an NSURL, the key
// choice NSFileManager.m and NSFileHandle.m already make here) and the POSIX error itself under
// NSUnderlyingErrorKey.  Foundation generates the localized description from the code, so this
// constructor -- like Apple's -- does not store one.
NSError *_NSErrorWithFilePathErrnoAndVariant(int posixErrno, id path, int variant, intptr_t unmeasured)
{
    // The measured variants are 0 (the O_WRONLY|O_CREAT|O_TRUNC open) and 1 (the O_RDONLY open):
    // non-zero is a read.  Other values are not measured, because the only consumer this tree can
    // see passes nothing else.
    BOOL reading = (variant != 0);
    NSInteger code;

    if (reading)
    {
        switch (posixErrno)
        {
            case EFBIG:        code = NSFileReadTooLargeError; break;
            case ENOENT:       code = NSFileReadNoSuchFileError; break;
            case EPERM:        // fall through: a permission failure is the same error either way
            case EACCES:       code = NSFileReadNoPermissionError; break;
            case ENAMETOOLONG: code = NSFileReadInvalidFileNameError; break;
            default:           code = NSFileReadUnknownError; break;
        }
    }
    else
    {
        switch (posixErrno)
        {
            case ENOENT:       code = NSFileNoSuchFileError; break;
            case EPERM:
            case EACCES:       code = NSFileWriteNoPermissionError; break;
            case ENAMETOOLONG: code = NSFileWriteInvalidFileNameError; break;
#ifdef EDQUOT
            case EDQUOT:
#endif
            case ENOSPC:       code = NSFileWriteOutOfSpaceError; break;
            case EROFS:        code = NSFileWriteVolumeReadOnlyError; break;
            case EEXIST:       code = NSFileWriteFileExistsError; break;
            default:           code = NSFileWriteUnknownError; break;
        }
    }

    // Both the call site and the name say the first argument is a path; NSFileManager.m's own helper
    // picks the key the same way, because an NSURL may be handed to either.  The fourth argument is
    // accepted and not read: it is 0 at the only call site, and Foundation is closed source.
    (void)unmeasured;
    NSString *pathKey = [path isKindOfClass:[NSURL class]] ? NSURLErrorKey : NSFilePathErrorKey;
    NSError *underlying = [NSError errorWithDomain:NSPOSIXErrorDomain code:posixErrno userInfo:nil];
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code
                            userInfo:@{ pathKey: path, NSUnderlyingErrorKey: underlying }];
}
