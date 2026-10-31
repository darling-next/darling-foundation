//
//  NSFileManager.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <dispatch/dispatch.h>
#import <dirent.h>
#import <errno.h>
#import <math.h>
#import <unistd.h>
#import <stdio.h>
#import <stdlib.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <copyfile.h>
#import <CoreFoundation/CFURL.h>
#import <MacTypes.h> // for kUnknownType

#import <Foundation/NSURL.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSError.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/FoundationErrors.h>

#import "NSDirectoryEnumerator.h"
#import "NSFileAttributes.h"
#import "NSFileManagerInternal.h"
#import "NSPathStore.h"
#import "NSFilesystemItemRemoveOperation.h"
#import "_NSFileIO.h"

CF_EXPORT CFStringEncoding CFStringFileSystemEncoding(void);

NSString *const NSUbiquityIdentityDidChangeNotification = @"NSUbiquityIdentityDidChangeNotification";
NSString *const NSFileType = @"NSFileType";
NSString *const NSFileTypeDirectory = @"NSFileTypeDirectory";
NSString *const NSFileTypeRegular = @"NSFileTypeRegular";
NSString *const NSFileTypeSymbolicLink = @"NSFileTypeSymbolicLink";
NSString *const NSFileTypeSocket = @"NSFileTypeSocket";
NSString *const NSFileTypeCharacterSpecial = @"NSFileTypeCharacterSpecial";
NSString *const NSFileTypeBlockSpecial = @"NSFileTypeBlockSpecial";
NSString *const NSFileTypeUnknown = @"NSFileTypeUnknown";
NSString *const NSFileSize = @"NSFileSize";
NSString *const NSFileModificationDate = @"NSFileModificationDate";
NSString *const NSFileReferenceCount = @"NSFileReferenceCount";
NSString *const NSFileDeviceIdentifier = @"NSFileDeviceIdentifier";
NSString *const NSFileOwnerAccountName = @"NSFileOwnerAccountName";
NSString *const NSFileGroupOwnerAccountName = @"NSFileGroupOwnerAccountName";
NSString *const NSFilePosixPermissions = @"NSFilePosixPermissions";
NSString *const NSFileSystemNumber = @"NSFileSystemNumber";
NSString *const NSFileSystemFileNumber = @"NSFileSystemFileNumber";
NSString *const NSFileExtensionHidden = @"NSFileExtensionHidden";
NSString *const NSFileHFSCreatorCode = @"NSFileHFSCreatorCode";
NSString *const NSFileHFSTypeCode = @"NSFileHFSTypeCode";
NSString *const NSFileImmutable = @"NSFileImmutable";
NSString *const NSFileAppendOnly = @"NSFileAppendOnly";
NSString *const NSFileCreationDate = @"NSFileCreationDate";
NSString *const NSFileOwnerAccountID = @"NSFileOwnerAccountID";
NSString *const NSFileGroupOwnerAccountID = @"NSFileGroupOwnerAccountID";
NSString *const NSFileBusy = @"NSFileBusy";
NSString *const NSFileProtectionKey = @"NSFileProtectionKey";
NSString *const NSFileProtectionNone = @"NSFileProtectionNone";
NSString *const NSFileProtectionComplete = @"NSFileProtectionComplete";
NSString *const NSFileProtectionCompleteUnlessOpen = @"NSFileProtectionCompleteUnlessOpen";
NSString *const NSFileProtectionCompleteUntilFirstUserAuthentication = @"NSFileProtectionCompleteUntilFirstUserAuthentication";
NSString *const NSFileSystemSize = @"NSFileSystemSize";
NSString *const NSFileSystemFreeSize = @"NSFileSystemFreeSize";
NSString *const NSFileSystemNodes = @"NSFileSystemNodes";
NSString *const NSFileSystemFreeNodes = @"NSFileSystemFreeNodes";

// Internal enum values
enum {
    NSDirectoryEnumerationRecursive    = 1UL << 7,
    NSDirectoryEnumerationGenerateURLs = 1UL << 8
};

@interface NSFileManager ()
- (NSArray *)directoryContentsAtPath:(NSString *)path matchingExtension:(NSString *)extension options:(NSDirectoryEnumerationOptions)options keepExtension:(BOOL)keepExtension error:(NSError **)error;
@end

@implementation NSFileManager

static void initializeDirectories(NSMutableSet *paths, NSSearchPathDirectory directory)
{
    [paths addObjectsFromArray:NSSearchPathForDirectoriesInDomains(directory, NSAllDomainsMask, YES)];
}

- (id)init
{
    self = [super init];
    if (self)
    {
        static pthread_mutex_t lock = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;
        static BOOL initialized = NO;
        pthread_mutex_lock(&lock);
        if (!initialized)
        {
            initialized = YES;
            NSMutableSet *paths = [[NSMutableSet alloc] init];
            initializeDirectories(paths, NSApplicationDirectory);
            initializeDirectories(paths, NSDemoApplicationDirectory);
            initializeDirectories(paths, NSDeveloperApplicationDirectory);
            initializeDirectories(paths, NSAdminApplicationDirectory);
            initializeDirectories(paths, NSLibraryDirectory);
            initializeDirectories(paths, NSDeveloperDirectory);
            initializeDirectories(paths, NSUserDirectory);
            initializeDirectories(paths, NSDocumentationDirectory);
            initializeDirectories(paths, NSDocumentDirectory);
            initializeDirectories(paths, NSCoreServiceDirectory);
            initializeDirectories(paths, NSAutosavedInformationDirectory);
            initializeDirectories(paths, NSDesktopDirectory);
            initializeDirectories(paths, NSCachesDirectory);
            initializeDirectories(paths, NSApplicationSupportDirectory);
            initializeDirectories(paths, NSDownloadsDirectory);
            initializeDirectories(paths, NSInputMethodsDirectory);
            initializeDirectories(paths, NSMoviesDirectory);
            initializeDirectories(paths, NSMusicDirectory);
            initializeDirectories(paths, NSPicturesDirectory);
            initializeDirectories(paths, NSPrinterDescriptionDirectory);
            initializeDirectories(paths, NSSharedPublicDirectory);
            initializeDirectories(paths, NSPreferencePanesDirectory);
            initializeDirectories(paths, NSApplicationScriptsDirectory);
            initializeDirectories(paths, NSItemReplacementDirectory);
            for (NSString *path in paths)
            {
                BOOL isDir = NO;
                BOOL exists = [self fileExistsAtPath:path isDirectory:&isDir];
                if (!exists)
                {
                    [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
                }
            }
            [paths release];
        }
        pthread_mutex_unlock(&lock);
    }
    return self;
}

+ (NSFileManager *)defaultManager
{
    static NSFileManager *defaultManager = nil;
    static pthread_mutex_t lock = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;
    pthread_mutex_lock(&lock);
    if (defaultManager == nil)
    {
        defaultManager = [[NSFileManager alloc] init];
        
    }
    pthread_mutex_unlock(&lock);
    return (NSFileManager *)defaultManager;
}

- (void)setDelegate:(id)delegate
{
    if (_delegate != delegate)
    {
        _delegate = delegate;
        _flags.shouldCopyItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldCopyItemAtPath:toPath:)];
        _flags.shouldCopyItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldCopyItemAtURL:toURL:)];
        _flags.shouldProceedAfterErrorCopyingItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:copyingItemAtPath:toPath:)];
        _flags.shouldProceedAfterErrorCopyingItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:copyingItemAtURL:toURL:)];
        _flags.shouldMoveItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldMoveItemAtPath:toPath:)];
        _flags.shouldMoveItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldMoveItemAtURL:toURL:)];
        _flags.shouldProceedAfterErrorMovingItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:movingItemAtPath:toPath:)];
        _flags.shouldProceedAfterErrorMovingItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:movingItemAtURL:toURL:)];
        _flags.shouldLinkItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldLinkItemAtPath:toPath:)];
        _flags.shouldLinkItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldLinkItemAtURL:toURL:)];
        _flags.shouldProceedAfterErrorLinkingItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:linkingItemAtPath:toPath:)];
        _flags.shouldProceedAfterErrorLinkingItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:linkingItemAtURL:toURL:)];
        _flags.shouldRemoveItemAtPath = [delegate respondsToSelector:@selector(fileManager:shouldRemoveItemAtPath:)];
        _flags.shouldRemoveItemAtURL = [delegate respondsToSelector:@selector(fileManager:shouldRemoveItemAtURL:)];
        _flags.shouldProceedAfterErrorRemovingItemAtPath = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:removingItemAtPath:)];
        _flags.shouldProceedAfterErrorRemovingItemAtURL = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:removingItemAtURL:)];
    }
}

- (id)delegate
{
    return _delegate;
}

- (BOOL)fileExistsAtPath:(NSString *)path
{
    return [self fileExistsAtPath:path isDirectory:NULL];
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory
{
    if (path == nil)
    {
        return NO;
    }
    BOOL exists = NO;
    BOOL isDir = NO;
    struct stat s;
    int err = stat([path UTF8String], &s); // this should use the fileSystemRep
    if (err == 0)
    {
        exists = YES;
        if (S_ISDIR(s.st_mode))
        {
            isDir = YES;
        }
    }
    if (isDirectory)
    {
        *isDirectory = isDir;
    }
    return exists;
}

static inline BOOL _NSFileAccessibleForMode(NSString *path, int mode)
{
    char buffer[BUG_COMPLIANT_PATH_MAX];
    if ([path getFileSystemRepresentation:buffer maxLength:BUG_COMPLIANT_PATH_MAX])
    {
        return access(buffer, mode) == 0;
    }
    else
    {
        return NO;
    }
}

- (BOOL)isReadableFileAtPath:(NSString *)path
{
    return _NSFileAccessibleForMode(path, R_OK);
}

- (BOOL)isWritableFileAtPath:(NSString *)path
{
    return _NSFileAccessibleForMode(path, W_OK);
}

- (BOOL)isExecutableFileAtPath:(NSString *)path
{
    return _NSFileAccessibleForMode(path, X_OK);
}

- (BOOL)isDeletableFileAtPath:(NSString *)path
{
    NSString *parent = [path stringByDeletingLastPathComponent];
    if (parent == nil)
    {
        parent = [self currentDirectoryPath];
    }

    return [self isWritableFileAtPath:parent];
}

- (NSString *)displayNameAtPath:(NSString *)path
{
    return [[[path lastPathComponent] componentsSeparatedByString:@":"] componentsJoinedByString:NSPathSep];
}

- (NSArray *)componentsToDisplayForPath:(NSString *)path
{
    return [path pathComponents];
}

- (NSArray *)directoryContentsAtPath:(NSString *)path matchingExtension:(NSString *)extension options:(NSDirectoryEnumerationOptions)options keepExtension:(BOOL)keepExtension error:(NSError **)error
{
    NSMutableArray *files = [NSMutableArray array];
    NSError* localError = nil;
    [self _directoryContentsAtPath:path 
                relativePath:nil
                matchingExtension:extension
                options:options
                keepExtension:keepExtension
                error:&localError
                toResult:files];
    if (localError != nil)
    {
        if (error)
        {
            *error = localError;
        }
        return nil;
    }
    if (options & NSDirectoryEnumerationGenerateURLs)
    {
        return [files sortedArrayUsingComparator:^(NSURL *url1, NSURL *url2){
            return [url1.path caseInsensitiveCompare:url2.path];
        }];
    }
    else
    {
        return [files sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    }
}

- (void)_directoryContentsAtPath:(NSString *)path relativePath:(NSString *)relativePath matchingExtension:(NSString *)extension options:(NSDirectoryEnumerationOptions)options keepExtension:(BOOL)keepExtension error:(NSError **)error toResult:(NSMutableArray *)files
{
    DIR *dirp = opendir([path fileSystemRepresentation]);
    if (!dirp) {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return;
    }

    struct dirent buffer;
    struct dirent *dp;
    const BOOL generateURLs = (options & NSDirectoryEnumerationGenerateURLs) != 0;

    while ((0 == readdir_r(dirp, &buffer, &dp)) && dp) {
        unsigned namelen = strlen(dp->d_name);
        if ((namelen == 1 && dp->d_name[0] == PATH_DOT) || (namelen == 2 && dp->d_name[0] == PATH_DOT && dp->d_name[1] == PATH_DOT))
        {
            continue;
        }

        if (dp->d_name[0] == PATH_DOT && ((options & NSDirectoryEnumerationSkipsHiddenFiles) != 0))
        {
            continue;
        }

        NSString *item = [NSString stringWithUTF8String:dp->d_name];
        const BOOL matchesExtension = extension == nil || [[item pathExtension] isEqualToString:extension];
        const BOOL recurse = dp->d_type == DT_DIR && (options & NSDirectoryEnumerationRecursive) != 0;
        NSString *relativeItem = item;
        if (!generateURLs && relativePath != nil && (matchesExtension || recurse))
        {
            relativeItem = [relativePath stringByAppendingPathComponent:item];
        }
        if (matchesExtension)
        {
            if (generateURLs)
            {
                [files addObject:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:item]]];
            }
            else
            {
                if (!keepExtension)
                {
                    [files addObject:[relativeItem stringByDeletingPathExtension]];
                }
                else
                {
                    [files addObject:relativeItem];
                }
            }
        }

        // should NSDirectoryEnumerationSkipsPackageDescendants be checked somehow here?
        if (recurse)
        {
            [self _directoryContentsAtPath:[path stringByAppendingPathComponent:item] 
                                                relativePath:generateURLs ? nil : relativeItem
                                            matchingExtension:extension
                                                      options:options
                                                keepExtension:keepExtension
                                                        error:error
                                                        toResult:files];
        }
    }
    closedir(dirp);
}


- (NSArray *)mountedVolumeURLsIncludingResourceValuesForKeys:(NSArray *)propertyKeys options:(NSVolumeEnumerationOptions)options
{
    return nil;
}

- (NSArray *)contentsOfDirectoryAtURL:(NSURL *)directoryUrl includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask error:(NSError **)error
{
    NSArray *urls = [self directoryContentsAtPath:[directoryUrl path]
                                matchingExtension:nil 
                                          options:mask | NSDirectoryEnumerationGenerateURLs 
                                    keepExtension:YES 
                                            error:error];
    // TODO: refactor this... it is rather ineffecient
    for (NSURL *url in urls)
    {
        struct stat s;
        int err = stat([[url path] UTF8String], &s);
        if (err != 0)
        {
            if (error)
            {
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
                }];
            }
            return urls;
        }
        for (NSString *key in keys)
        {
            CFTypeRef value = NULL;
            if ([key isEqualToString:NSURLNameKey])
            {
                value = [[url lastPathComponent] retain];
            }
            else if ([key isEqualToString:NSURLLocalizedNameKey])
            {
                value = [[[url lastPathComponent] stringByDeletingPathExtension] retain];
            }
            else if ([key isEqualToString:NSURLIsRegularFileKey])
            {
                value = [(S_ISREG(s.st_mode) ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLIsDirectoryKey])
            {
                value = [(S_ISDIR(s.st_mode) ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLIsSymbolicLinkKey])
            {
                value = [(S_ISLNK(s.st_mode) ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLIsVolumeKey])
            {
                value = [@NO retain]; // is this even possible?
            }
            else if ([key isEqualToString:NSURLIsPackageKey])
            {
                value = [((S_ISDIR(s.st_mode) && [[[url lastPathComponent] pathExtension] length] > 0) ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLIsUserImmutableKey])
            {

            }
            else if ([key isEqualToString:NSURLIsHiddenKey])
            {
                value = [([[url lastPathComponent] hasPrefix:NSPathDot] ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLHasHiddenExtensionKey])
            {
                value = [@NO retain];
            }
            else if ([key isEqualToString:NSURLCreationDateKey])
            {
#ifdef ANDROID
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_ctime * NSEC_PER_SEC + s.st_ctime_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#elif defined(__APPLE__)
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_ctime * NSEC_PER_SEC + s.st_ctimespec.tv_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#else
#error Implementation needed for file time specs
#endif
            }
            else if ([key isEqualToString:NSURLContentAccessDateKey])
            {
#ifdef ANDROID
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_atime * NSEC_PER_SEC + s.st_atime_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#elif defined(__APPLE__)
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_atime * NSEC_PER_SEC + s.st_atimespec.tv_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#else
#error Implementation needed for file time specs
#endif
            }
            else if ([key isEqualToString:NSURLContentModificationDateKey])
            {
#ifdef ANDROID
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_mtime * NSEC_PER_SEC + s.st_mtime_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#elif defined(__APPLE__)
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_mtime * NSEC_PER_SEC + s.st_mtimespec.tv_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#else
#error Implementation needed for file time specs
#endif
            }
            else if ([key isEqualToString:NSURLAttributeModificationDateKey])
            {
#ifdef ANDROID
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_mtime * NSEC_PER_SEC + s.st_mtime_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#elif defined(__APPLE__)
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_mtime * NSEC_PER_SEC + s.st_mtimespec.tv_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#else
#error Implementation needed for file time specs
#endif
            }
            else if ([key isEqualToString:NSURLParentDirectoryURLKey])
            {
                value = [[url URLByDeletingLastPathComponent] retain];
            }
            else if ([key isEqualToString:NSURLFileSizeKey])
            {
                value = [[NSNumber numberWithLongLong:s.st_size] retain];
            }
            else if ([key isEqualToString:NSURLFileAllocatedSizeKey])
            {
                value = [[NSNumber numberWithUnsignedLongLong:s.st_blksize * s.st_blocks] retain];
            }

            if (value)
            {
                CFErrorRef cfError = NULL;
                BOOL set = CFURLSetResourcePropertyForKey((CFURLRef)url, (CFStringRef)key, value, &cfError);

                CFRelease(value);

                if (!set)
                {
                    if (error)
                    {
                        *error = [(NSError*)cfError autorelease];
                    }
                    else if (cfError)
                    {
                        CFRelease(cfError);
                    }
                    return urls; // early escape out of both iterators
                }
            }
        }
    }
    return urls;
}

// Use the runtime's current-user home resolution, not the named-user lookup.
- (NSURL *)homeDirectoryForCurrentUser
{
    return [NSURL fileURLWithPath:NSHomeDirectory() isDirectory:YES];
}

// Darwin's relationship between the two APIs of the same name: NSFileManager's temporaryDirectory
// IS the URL of NSTemporaryDirectory(), directory-flagged so that the trailing slash Darwin's URL
// carries is preserved. Deriving it here, rather than naming a directory in this file, is what
// keeps this accessor and the rest of the runtime's temporary-directory notion from disagreeing --
// a hardcoded /tmp would silently return a different directory the moment NSTemporaryDirectory()
// and it stopped agreeing (which they already can: NSTemporaryDirectory() honours TEMPDIR/TMPDIR/
// TEMP/TMP before its /tmp default, NSPathUtilities.m).
//
// What the guest actually gets is therefore whatever its own TMPDIR resolution says, which on this
// runtime is /tmp/: launchd exports TMPDIR=confstr(_CS_DARWIN_USER_TEMP_DIR) (launchd/src/core.c),
// confstr falls back through __dirhelper() to TMPDIR and then P_tmpdir (libc/gen/confstr.c), and
// the guest's /tmp is a real directory in the prefix. The oracle next to this fix measures the
// path, the trailing slash, the directory-ness and the existence of the result rather than
// asserting any of them from here.
- (NSURL *)temporaryDirectory
{
    return [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
}

- (NSArray *)URLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domainMask {
    // Only NSUserDomain is supported on iOS
    if (domainMask != NSUserDomainMask)
    {
        return @[];
    }
    NSArray *pathsForDirectory = NSSearchPathForDirectoriesInDomains(directory, domainMask, YES);
    NSMutableArray *urls = [NSMutableArray arrayWithCapacity:[pathsForDirectory count]];

    for (NSString *s in pathsForDirectory) {
        [urls addObject:[NSURL fileURLWithPath:s]];
    }

    return [[urls copy] autorelease];
}

- (NSURL *)URLForDirectory:(NSSearchPathDirectory)directory inDomain:(NSSearchPathDomainMask)domain appropriateForURL:(NSURL *)url create:(BOOL)shouldCreate error:(NSError **)error
{
    // how is appropriateForURL come into play? it does not seem to be used...
    NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, domain, YES);
    if ([paths count] == 0)
    {
        return nil;
    }

    NSString *path = [paths objectAtIndex:0];
    NSURL *dirUrl = [NSURL fileURLWithPath:path];
    if (shouldCreate && ![self fileExistsAtPath:path] &&
        ![self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error])
    {
        return nil;
    }

    return dirUrl;
}

- (BOOL)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
    if (createIntermediates)
    {
        NSArray *comps = [url pathComponents];
        NSURL *recomposed = nil;
        for (NSString *comp in comps)
        {
            if (recomposed == nil)
            {
                recomposed = [NSURL fileURLWithPath:comp];
            }
            else
            {
                recomposed = [recomposed URLByAppendingPathComponent:comp];
            }
            BOOL isDir = NO;
            BOOL exists = [self fileExistsAtPath:[recomposed path] isDirectory:&isDir];
            if (!exists)
            {
                NSError *creationError = nil;
                if (![self createDirectoryAtURL:recomposed withIntermediateDirectories:NO attributes:attributes error:&creationError])
                {
                    // Another creator may have installed this component after the existence check.
                    if ([[creationError domain] isEqualToString:NSCocoaErrorDomain] &&
                        [creationError code] == NSFileWriteFileExistsError &&
                        [self fileExistsAtPath:[recomposed path] isDirectory:&isDir] && isDir)
                    {
                        continue;
                    }
                    if (error)
                    {
                        *error = creationError;
                    }
                    return NO;
                }
            }
            else if (!isDir)
            {
                if (error)
                {
                    *error = [NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:@{
                        NSLocalizedDescriptionKey: @"Found a file where a directory was expected"
                    }];
                }
                return NO;
            }
        }
        return YES;
    }
    else
    {
        mode_t mode = 0777;
        if (attributes[NSFilePosixPermissions])
        {
            mode = [attributes[NSFilePosixPermissions] intValue];
        }

        // NSFileOwnerAccountName
        // NSFileGroupOwnerAccountName
        // are possible, but not reasonable atm

        int err = mkdir([[url path] UTF8String], mode);
        if (err == -1)
        {
            if (error)
            {
                *error = _NSErrorWithFilePathErrnoAndVariant(errno, [url path], 0, 0);
            }
            return NO;
        }

        return YES;
    }
}

- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
    return [self createDirectoryAtURL:[NSURL fileURLWithPath:path] withIntermediateDirectories:createIntermediates attributes:attributes error:error];
}

- (BOOL)createDirectoryAtPath:(NSString *)path attributes:(NSDictionary *)attributes
{
    return [self createDirectoryAtPath:path withIntermediateDirectories:NO attributes:attributes error:nil];
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error
{
    if (path == nil) {
        if (error) {
            *error = [NSError errorWithDomain: NSCocoaErrorDomain
                                         code: NSFileReadUnknownError
                                     userInfo: @{ NSFilePathErrorKey: path }];
        }
        return nil;
    }
    struct stat s;
    int err = lstat([path UTF8String], &s);
    if (err == -1)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return nil;
    }
    return [NSFileAttributes attributesWithStat:&s];
}

- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data attributes:(NSDictionary *)attr
{
    if (data == nil) {
        data = [NSData data];
    }
    
    if (![data writeToFile:path atomically:YES])
    {
        return NO;
    }
    
    if (attr)
    {
        [self setAttributes:attr ofItemAtPath:path error:nil];
    }

    return YES;
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error
{
    if (path == NULL) {
        return NO;
    }

    NSFilesystemItemRemoveOperation *op = [NSFilesystemItemRemoveOperation filesystemItemRemoveOperationWithPath:path];
    [op setDelegate:self];
    [op start];
    if (error != NULL)
    {
        *error = [op error];
    }
    return [op error] == nil;
}

- (BOOL)removeItemAtURL:(NSURL *)URL error:(NSError **)error
{
    return [self removeItemAtPath:URL.path error:error];
}


#warning TODO implement remove with NSFilesystemItemRemoveOperation
    // NSFilesystemItemRemoveOperation *op = [NSFilesystemItemRemoveOperation filesystemItemRemoveOperationWithPath:path];
    // [op setDelegate:self];
    // [op start];
    // *error = [op error];

static NSError *_NSErrorWithFilePathAndErrno(id path, int code)
{
    NSString *pathKey = [path isKindOfClass:[NSURL class]] ? NSURLErrorKey : NSFilePathErrorKey;
    NSString *underlyingError = [NSString stringWithFormat:@"Error Domain=NSPOSIXErrorDomain Code=%d \"%s\"", code, strerror(code)];
    NSDictionary *userInfo = @{ pathKey: path, NSUnderlyingErrorKey: underlyingError };
    
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:userInfo];
}

- (BOOL)setAttributes:(NSDictionary *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error
{
    char buffer[BUG_COMPLIANT_PATH_MAX];
    
    if ([self getFileSystemRepresentation:buffer maxLength:BUG_COMPLIANT_PATH_MAX withPath:path])
    {
        NSNumber *posixPermissions = [attributes objectForKey:NSFilePosixPermissions];
        if (posixPermissions)
        {
            mode_t permissions = [posixPermissions shortValue];
            if (chmod(buffer, permissions) != 0)
            {
                if (error) {
                    *error = _NSErrorWithFilePathAndErrno(path, errno);
                }
                return NO;
            }
        }
        
        NSDate *creationDate = [attributes objectForKey:NSFileCreationDate];
        if (creationDate)
        {
            // Creation time is not stored by most Linux file systems.
            DEBUG_LOG("Setting file creation date is not supported (path: %s)", buffer);
        }
        
        NSDate *modificationDate = [attributes objectForKey:NSFileModificationDate];
        if (modificationDate)
        {
            NSTimeInterval modification = [modificationDate timeIntervalSince1970];
        
            struct timeval times[2];
            double wholeSeconds, fractionalSeconds = modf(modification, &wholeSeconds);
            times[0].tv_sec = wholeSeconds;
            times[0].tv_usec = lround(1000000.0 * fractionalSeconds);
            times[1] = times[0];

            if (utimes(buffer, times) != 0)
            {
                if (error) {
                    *error = _NSErrorWithFilePathAndErrno(path, errno);
                }
                return NO;
            }
        }
        
        return YES;
    }
    else
    {
        if (error) {
            *error = _NSErrorWithFilePathAndErrno(path, ENOENT);
        }
        return NO;
    }
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)path traverseLink:(BOOL)yorn
{
    struct stat s;
    int err = 0;
    if (yorn)
    {
        err = lstat([path UTF8String], &s);
    }
    else
    {
        err = stat([path UTF8String], &s);
    }
    if (err == -1)
    {
        return nil;
    }
    else
    {
        return [NSFileAttributes attributesWithStat:&s];
    }
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error
{
    char pathbuf[BUG_COMPLIANT_PATH_MAX];
    if (![path getFileSystemRepresentation:pathbuf maxLength:BUG_COMPLIANT_PATH_MAX])
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:@{
                NSLocalizedDescriptionKey: @"file not found"
            }];
        }
        return nil;
    }
    
    struct statfs statbuf;
    if (statfs(pathbuf, &statbuf) != 0)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return nil;
    }
    
    #define FILESYSTEM_NUM_ATTRIBUTES 5
    
    NSString *keys[FILESYSTEM_NUM_ATTRIBUTES] = {
        NSFileSystemNumber,
        NSFileSystemSize,
        NSFileSystemFreeSize,
        NSFileSystemNodes,
        NSFileSystemFreeNodes
    };
    
    unsigned long long blocksize = statbuf.f_bsize;
    long fsnumber;
    memcpy(&fsnumber, &statbuf.f_fsid, sizeof(fsnumber));
    
    NSNumber *objects[FILESYSTEM_NUM_ATTRIBUTES] = {
        [NSNumber numberWithUnsignedLong:fsnumber],
        [NSNumber numberWithUnsignedLongLong:blocksize * (unsigned long long)statbuf.f_blocks],
        [NSNumber numberWithUnsignedLongLong:blocksize * (unsigned long long)statbuf.f_bavail],
        [NSNumber numberWithLong:statbuf.f_files],
        [NSNumber numberWithLong:statbuf.f_ffree],
    };
    
    if (error)
    {
        *error = nil;
    }
    
    return [NSDictionary dictionaryWithObjects:objects forKeys:keys count:FILESYSTEM_NUM_ATTRIBUTES];
    #undef FILESYSTEM_NUM_ATTRIBUTES
}

- (NSString *)currentDirectoryPath
{
    char buffer[BUG_COMPLIANT_PATH_MAX];
    if (getcwd(buffer, BUG_COMPLIANT_PATH_MAX) != NULL)
    {
        return [self stringWithFileSystemRepresentation:buffer length:strlen(buffer)];
    }
    else
    {
        return nil;
    }
}

- (BOOL)changeCurrentDirectoryPath:(NSString*)path
{
    char buffer[BUG_COMPLIANT_PATH_MAX];
    if ([self getFileSystemRepresentation:buffer maxLength:BUG_COMPLIANT_PATH_MAX withPath:path])
    {
        return chdir(buffer) == 0;
    }
    else
    {
        return NO;
    }
}

- (BOOL)changeFileAttributes:(NSDictionary *)attributes atPath:(NSString *)path
{
    return [self setAttributes:attributes ofItemAtPath:path error:nil];
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error
{
    return [self directoryContentsAtPath:path matchingExtension:nil options:0 keepExtension:YES error:error];
}

- (NSArray *)subpathsOfDirectoryAtPath:(NSString *)path error:(NSError **)error
{
    return [self directoryContentsAtPath:path matchingExtension:nil options:NSDirectoryEnumerationRecursive keepExtension:YES error:error];
}

- (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error
{
    if (error)
    {
        *error = nil;
    }
    BOOL shouldLink = YES;
    if (_flags.shouldLinkItemAtPathToPath)
    {
        shouldLink = [_delegate fileManager:self shouldLinkItemAtPath:path toPath:destPath];
    }
    if (!shouldLink)
    {
        return NO;
    }
    // symlink(2) takes the link target first and the new link path second, which is the reverse
    // of the atPath:/withDestinationPath: labels: the link itself must appear at `path`.
    int err = symlink([destPath fileSystemRepresentation], [path fileSystemRepresentation]);
    if (err == -1)
    {
        if (error)
        {
            *error = _NSErrorWithFilePathErrnoAndVariant(errno, path, 0, 0);
        }
        return NO;
    }
    return YES;
}

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path error:(NSError **)error
{
    if (error)
    {
        *error = nil;
    }
    // Return the link's stored contents, without resolving relative or dangling destinations.
    const char *linkPath = [path fileSystemRepresentation];
    char stackTarget[PATH_MAX + 1];
    char *target = stackTarget;
    size_t capacity = sizeof(stackTarget);
    for (;;)
    {
        ssize_t length = readlink(linkPath, target, capacity);
        if (length < 0)
        {
            int readError = errno;
            if (target != stackTarget)
            {
                free(target);
            }
            if (error)
            {
                *error = _NSErrorWithFilePathErrnoAndVariant(readError, path, 1, 0);
            }
            return nil;
        }
        if ((size_t)length < capacity)
        {
            NSString *destination = [self stringWithFileSystemRepresentation:target length:(NSUInteger)length];
            if (target != stackTarget)
            {
                free(target);
            }
            return destination;
        }
        // A full buffer does not prove the destination fit: readlink truncates instead of failing.
        // Grow and re-read so a long stored target is returned whole; the truncated bytes are
        // discarded rather than carried over.
        size_t grown = capacity * 2;
        char *buffer = grown > capacity ? malloc(grown) : NULL;
        if (buffer == NULL)
        {
            if (target != stackTarget)
            {
                free(target);
            }
            if (error)
            {
                *error = _NSErrorWithFilePathErrnoAndVariant(ENOMEM, path, 1, 0);
            }
            return nil;
        }
        if (target != stackTarget)
        {
            free(target);
        }
        target = buffer;
        capacity = grown;
    }
}


- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error
{
    NSString *dstDir = [dstPath stringByDeletingLastPathComponent];
    BOOL isDir = NO;
    BOOL exists = [self fileExistsAtPath:dstDir isDirectory:&isDir];
    if (exists && !isDir)
    {
#warning TODO: Error should be populated here
        return NO;
    }
    else if (!exists)
    {
        if (![self createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:error])
        {
            return NO;
        }
    }
    /* copyfile(3) copies NOTHING for a directory source unless COPYFILE_RECURSIVE is requested: it returns 0
     * and leaves the destination empty. MEASURED: `copyItemAtPath:` of a three-level tree reported success and
     * produced an empty directory, and SwiftPM's dependency cache materialisation ("Fetched … from cache") put
     * EMPTY repositories into .build/repositories, so every pinned version "did not match" and resolution
     * failed. Darwin's NSFileManager copies hierarchies, so this must too. */
    struct stat srcStat;
    BOOL srcIsDirectory = (stat([srcPath fileSystemRepresentation], &srcStat) == 0) && S_ISDIR(srcStat.st_mode);

    copyfile_flags_t flags = COPYFILE_DATA;
    if (srcIsDirectory)
    {
        flags |= COPYFILE_RECURSIVE;
    }
    if (error != NULL)
    {
        *error = nil;
    }
    int err = copyfile([srcPath fileSystemRepresentation], [dstPath fileSystemRepresentation], NULL, flags);

    if (err != 0)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return NO;
    }
    return YES;
}

- (BOOL)copyItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error
{
    return [self copyItemAtPath:srcURL.path toPath:dstURL.path error:error];
}

- (NSData *)contentsAtPath:(NSString *)path
{
    return [[[NSData alloc] initWithContentsOfFile:path] autorelease];
}

- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error
{
    if (error != NULL) {
        *error = nil;
    }

    BOOL exists = [self fileExistsAtPath:dstPath];
    if (exists)
    {
        if (error != NULL)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError userInfo:@{
                NSLocalizedDescriptionKey: @"Item couldn't be moved because an item with the same name already exists.",
                NSFilePathErrorKey: dstPath,
            }];
        }
        return NO;
    }

    if (rename([srcPath UTF8String], [dstPath UTF8String]) != -1) {
        return YES;
    }

    if (error != NULL) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
            NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
    }
    return NO;
}

- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error
{
    return [self moveItemAtPath:srcURL.path toPath:dstURL.path error:error];
}

- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)path
{
    return [[NSAllDescendantPathsEnumerator newWithPath:path prepend:nil attributes:nil cross:YES depth:1] autorelease];
}

- (NSDirectoryEnumerator *)enumeratorAtURL:(NSURL *)url includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask errorHandler:(BOOL (^)(NSURL *url, NSError *error))handler
{
    if (url == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"URL is nil"];
        return nil;
    }
    return [[[NSURLDirectoryEnumerator alloc] initWithURL:url includingPropertiesForKeys:keys options:mask errorHandler:handler] autorelease];
}

- (NSArray *)subpathsAtPath:(NSString *)path
{
    return [[self enumeratorAtPath:path] allObjects];
}

- (BOOL)getFileSystemRepresentation:(char *)buffer maxLength:(NSUInteger)maxLength withPath:(NSString *)path
{
    if ([path isEqual:@""])
    {
        // it is a known iOS bug (by unit test) to not zero out the buffer (or atleast zero index 0)
        return NO;
    }

    return CFStringGetFileSystemRepresentation((CFStringRef)path, buffer, maxLength);
}

static inline NSStringEncoding defaultEncoding()
{
    static NSStringEncoding encoding = 0;
    if (encoding == 0)
    {
        encoding = CFStringConvertEncodingToNSStringEncoding(CFStringFileSystemEncoding());
    }
    return encoding;
}

- (__strong const char *)fileSystemRepresentationWithPath:(NSString *)path
{
    CFIndex maxLen = CFStringGetMaximumSizeOfFileSystemRepresentation((CFStringRef)path);
    char *buffer = malloc(maxLen);
    if (buffer == NULL)
    {
        [NSException raise:NSMallocException format:@"unable to allocate to create representation"];
        return NULL;
    }

    if ([self getFileSystemRepresentation:buffer maxLength:maxLen withPath:path])
    {
        return [[NSData dataWithBytesNoCopy:buffer length:maxLen] bytes];
    }
    else
    {
        free(buffer);
        [NSException raise:NSInvalidArgumentException format:@"unable to convert path %@", path];
        return nil;
    }

}

- (NSString *)stringWithFileSystemRepresentation:(const char *)str length:(NSUInteger)len
{
    return [[[NSString alloc] initWithBytes:str length:len encoding:defaultEncoding()] autorelease];
}

@end
