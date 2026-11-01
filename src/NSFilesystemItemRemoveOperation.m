//
//  NSFilesystemItemRemoveOperation.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSFilesystemItemRemoveOperation.h"
#import <ftw.h>
#import <errno.h>
#import <unistd.h>
#import <stdlib.h>
#import <stdio.h>
#import <Foundation/NSError.h>
#import "_NSFileIO.h"

@implementation NSFilesystemItemRemoveOperation

+ (id)filesystemItemRemoveOperationWithPath:(NSString *)path
{
    return [[[NSFilesystemItemRemoveOperation alloc] initWithPath:path] autorelease];
}

+ (NSError *)_errorWithErrno:(int)err atPath:(NSString *)path
{
    // Removal is a write operation. Preserve errno as the underlying error,
    // while exposing the Cocoa file error callers use for recovery.
    return _NSErrorWithFilePathErrnoAndVariant(err, path, 0, 0);
}

- (id)initWithPath:(NSString *)path
{
    self = [super init];

    if (self)
    {
        _removePath = [path retain];
    }

    return self;
    
}

- (void)dealloc
{
    [_error release];
    [_removePath release];

    [super dealloc];
}

static _Thread_local void* ctx = NULL;

static int NSFilesystemItemRemoveOperationFunction(const char *path, const struct stat *stat_info, int flags, struct FTW *info)
{
    NSFilesystemItemRemoveOperation *op = (NSFilesystemItemRemoveOperation *)ctx;
    NSFileManager *fm = [op delegate];
    id fmDelegate = [fm delegate];
    BOOL shouldRemove = YES;
    NSString *pathStr = [NSString stringWithUTF8String:path];
    if ([fmDelegate respondsToSelector:@selector(fileManager:shouldRemoveItemAtPath:)])
    {
        shouldRemove = [fmDelegate fileManager:fm shouldRemoveItemAtPath:pathStr];
    }

    if (!shouldRemove)
    {
        return 0;
    }

    int err = remove(path);

    if (err != 0)
    {
        BOOL shouldProceed = YES;
        NSError *error = [NSFilesystemItemRemoveOperation _errorWithErrno:errno atPath:pathStr];
        [op _setError:error];
        if ([fmDelegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:removingItemAtPath:)])
        {
            shouldProceed = [fmDelegate fileManager:fm shouldProceedAfterError:error removingItemAtPath:pathStr];
        }
        if (!shouldProceed)
        {
            return -1; // FTW_STOP missing from both bionic and iOS?
        }
    }

    return 0;
}

- (void)main
{
    @autoreleasepool
    {
        ctx = self;

        // Reuse the sibling fork's no-follow removal policy. Darwin nftw
        // follows its root even with FTW_PHYS and requires a directory root.
        // Non-directories, including dangling links, use the same callback.
        const char *path = [_removePath cString];
        struct stat st;
        int err;
        if (lstat(path, &st) == 0 && !S_ISDIR(st.st_mode))
        {
            err = NSFilesystemItemRemoveOperationFunction(path, &st, FTW_F, NULL);
        }
        else
        {
            err = nftw(
                path,
                NSFilesystemItemRemoveOperationFunction,
                1, // ignored by the implementation, but values less than 1 and
                   // more than OPEN_MAX result in EINVAL
                FTW_DEPTH | FTW_PHYS
            );
        }

        ctx = NULL;
        if (_error == nil && err != 0)
        {
            NSError *error = [NSFilesystemItemRemoveOperation _errorWithErrno:errno atPath:_removePath];
            [self _setError:error];
        }
    }
}

- (BOOL)_filtersUnderbars
{
    return _filterUnderbars;
}

- (void)_setFilterUnderbars:(BOOL)filterUnderbars
{
    _filterUnderbars = filterUnderbars;
}

- (void)_setError:(NSError *)error
{
    if (error != _error)
    {
        [_error release];
        _error = [error retain];
    }
}

- (id)error
{
    return _error;
}

- (void)setDelegate:(NSFileManager *)delegate
{
    _delegate = delegate;
}

- (NSFileManager *)delegate
{
    return _delegate;
}

@end
