#import <Foundation/NSObject.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSHTTPCookieStorage.h>

#include <Security/SecureTransport.h>

typedef NS_ENUM(NSInteger, NSURLSessionTaskState) {
    NSURLSessionTaskStateRunning = 0,
    NSURLSessionTaskStateSuspended = 1,
    NSURLSessionTaskStateCanceling = 2,
    NSURLSessionTaskStateCompleted = 3,
};

typedef NS_ENUM(NSInteger, NSURLSessionAuthChallengeDisposition) {
    NSURLSessionAuthChallengeUseCredential = 0,
    NSURLSessionAuthChallengePerformDefaultHandling = 1,
    NSURLSessionAuthChallengeCancelAuthenticationChallenge = 2,
    NSURLSessionAuthChallengeRejectProtectionSpace = 3,
};

typedef NS_ENUM(NSInteger, NSURLSessionResponseDisposition) {
    NSURLSessionResponseCancel = 0,
    NSURLSessionResponseAllow = 1,
    NSURLSessionResponseBecomeDownload = 2,
};

NS_ASSUME_NONNULL_BEGIN

@class NSArray, NSCachedURLResponse, NSData, NSDictionary, NSError;
@class NSHTTPCookie, NSHTTPURLResponse, NSInputStream, NSOperationQueue;
@class NSString, NSURL, NSURLAuthenticationChallenge, NSURLCache;
@class NSURLCredential, NSURLCredentialStorage, NSURLProtectionSpace;
@class NSURLResponse, NSURLSession, NSURLSessionConfiguration;
@class NSURLSessionTask, NSURLSessionDataTask, NSURLSessionDownloadTask;
@class NSURLSessionUploadTask, NSSet;
@class NSURLSessionWebSocketTask, NSURLSessionWebSocketMessage;

@protocol NSURLSessionDelegate <NSObject>
@optional

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error;
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session;

@end

@protocol NSURLSessionTaskDelegate <NSURLSessionDelegate>
@optional

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge  completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error;

@end

@protocol NSURLSessionDataDelegate <NSURLSessionTaskDelegate>
@optional

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse  completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler;

@end

@protocol NSURLSessionDownloadDelegate <NSURLSessionTaskDelegate>

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location;
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes;

@end

FOUNDATION_EXPORT const int64_t NSURLSessionTransferSizeUnknown;
FOUNDATION_EXPORT NSString * const NSURLSessionDownloadTaskResumeData;

@interface NSURLSession : NSObject

@property (readonly, retain) NSOperationQueue *delegateQueue;
@property (nullable, readonly, retain) id <NSURLSessionDelegate> delegate;
@property (readonly, copy) NSURLSessionConfiguration *configuration;
@property (nullable, copy) NSString *sessionDescription;

@property (class, readonly, strong) NSURLSession *sharedSession;
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(nullable id <NSURLSessionDelegate>)delegate delegateQueue:(nullable NSOperationQueue *)queue;
- (void)finishTasksAndInvalidate;
- (void)invalidateAndCancel;
- (void)resetWithCompletionHandler:(void (^)(void))completionHandler;
- (void)flushWithCompletionHandler:(void (^)(void))completionHandler;
- (void)getTasksWithCompletionHandler:(void (^)(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks))completionHandler;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;
- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSURLRequest *)request;
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url;
- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData;
- (NSURLSessionWebSocketTask *)webSocketTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url;
- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url protocols:(NSArray *)protocols;

@end

@interface NSURLSession (NSURLSessionAsynchronousConvenience)

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData completionHandler:(void (^)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

@interface NSURLSessionTask : NSObject <NSCopying>

@property (readonly) NSUInteger taskIdentifier;
@property (nullable, readonly, copy) NSURLRequest *originalRequest;
@property (nullable, readonly, copy) NSURLRequest *currentRequest;
@property (nullable, readonly, copy) NSURLResponse *response;
@property (readonly) int64_t countOfBytesReceived;
@property (readonly) int64_t countOfBytesSent;
@property (readonly) int64_t countOfBytesExpectedToSend;
@property (readonly) int64_t countOfBytesExpectedToReceive;
@property (nullable, copy) NSString *taskDescription;
@property (readonly) NSURLSessionTaskState state;
@property (nullable, readonly, copy) NSError *error;
@property (nullable, retain) id<NSURLSessionTaskDelegate> delegate;

- (void)cancel;
- (void)suspend;
- (void)resume;

@end

@interface NSURLSessionDataTask : NSURLSessionTask
@end

@interface NSURLSessionUploadTask : NSURLSessionDataTask
@end

@interface NSURLSessionDownloadTask : NSURLSessionTask

- (void)cancelByProducingResumeData:(void (^)(NSData * _Nullable resumeData))completionHandler;

@end

/* Objective-C wire message and Swift overlay names follow Apple's public SDK
 * and swift-corelibs-foundation Darwin/Foundation-swiftoverlay/URLSession.swift.
 */
typedef NS_ENUM(NSInteger, NSURLSessionWebSocketMessageType) {
    NSURLSessionWebSocketMessageTypeData = 0,
    NSURLSessionWebSocketMessageTypeString = 1,
};

typedef NS_ENUM(NSInteger, NSURLSessionWebSocketCloseCode) {
    NSURLSessionWebSocketCloseCodeInvalid = 0,
    NSURLSessionWebSocketCloseCodeNormalClosure = 1000,
    NSURLSessionWebSocketCloseCodeGoingAway = 1001,
    NSURLSessionWebSocketCloseCodeProtocolError = 1002,
    NSURLSessionWebSocketCloseCodeUnsupportedData = 1003,
    NSURLSessionWebSocketCloseCodeNoStatusReceived = 1005,
    NSURLSessionWebSocketCloseCodeAbnormalClosure = 1006,
    NSURLSessionWebSocketCloseCodeInvalidFramePayloadData = 1007,
    NSURLSessionWebSocketCloseCodePolicyViolation = 1008,
    NSURLSessionWebSocketCloseCodeMessageTooBig = 1009,
    NSURLSessionWebSocketCloseCodeMandatoryExtensionMissing = 1010,
    NSURLSessionWebSocketCloseCodeInternalServerError = 1011,
    NSURLSessionWebSocketCloseCodeTLSHandshakeFailure = 1015,
};

NS_SWIFT_NAME(__NSURLSessionWebSocketMessage)
@interface NSURLSessionWebSocketMessage : NSObject <NSCopying> {
@private
    NSData *_data;
    NSString *_string;
}
- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithString:(NSString *)string;
@property (readonly) NSURLSessionWebSocketMessageType type;
@property (nullable, readonly, copy) NSData *data;
@property (nullable, readonly, copy) NSString *string;
@end

@interface NSURLSessionWebSocketTask : NSURLSessionTask
@property NSInteger maximumMessageSize;
@property (readonly) NSURLSessionWebSocketCloseCode closeCode;
@property (nullable, readonly, copy) NSData *closeReason;
- (void)sendMessage:(NSURLSessionWebSocketMessage *)message completionHandler:(void (^)(NSError * _Nullable error))completionHandler NS_SWIFT_NAME(__send(_:completionHandler:));
- (void)receiveMessageWithCompletionHandler:(void (^)(NSURLSessionWebSocketMessage * _Nullable message, NSError * _Nullable error))completionHandler NS_SWIFT_NAME(__receiveMessage(completionHandler:));
- (void)sendPingWithPongReceiveHandler:(void (^)(NSError * _Nullable error))pongReceiveHandler;
- (void)cancelWithCloseCode:(NSURLSessionWebSocketCloseCode)closeCode reason:(nullable NSData *)reason;
@end

@protocol NSURLSessionWebSocketDelegate <NSURLSessionTaskDelegate>
@optional
- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didOpenWithProtocol:(nullable NSString *)protocol;
- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode reason:(nullable NSData *)reason;
@end

@interface NSURLSessionConfiguration : NSObject <NSCopying>
{
@private
    // Explicit storage is required by the i386 fragile Objective-C ABI.
    NSString *_identifier;
    NSURLRequestCachePolicy _requestCachePolicy;
    NSTimeInterval _timeoutIntervalForRequest;
    NSTimeInterval _timeoutIntervalForResource;
    NSURLRequestNetworkServiceType _networkServiceType;
    BOOL _allowsCellularAccess;
    BOOL _discretionary;
    BOOL _sessionSendsLaunchEvents;
    NSDictionary *_connectionProxyDictionary;
    SSLProtocol _TLSMinimumSupportedProtocol;
    SSLProtocol _TLSMaximumSupportedProtocol;
    BOOL _HTTPShouldUsePipelining;
    BOOL _HTTPShouldSetCookies;
    NSHTTPCookieAcceptPolicy _HTTPCookieAcceptPolicy;
    NSDictionary *_HTTPAdditionalHeaders;
    NSInteger _HTTPMaximumConnectionsPerHost;
    NSHTTPCookieStorage *_HTTPCookieStorage;
    NSURLCredentialStorage *_URLCredentialStorage;
    NSURLCache *_URLCache;
    NSArray *_protocolClasses;
    BOOL __allowsReachabilityCheck;
    NSSet *__suppressedAutoAddedHTTPHeaders;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration;
+ (NSURLSessionConfiguration *)backgroundSessionConfiguration:(NSString *)identifier;

@property(class, readonly, strong) NSURLSessionConfiguration *defaultSessionConfiguration;

@property (nullable, readonly, copy) NSString *identifier;
@property NSURLRequestCachePolicy requestCachePolicy;
@property NSTimeInterval timeoutIntervalForRequest;
@property NSTimeInterval timeoutIntervalForResource;
@property NSURLRequestNetworkServiceType networkServiceType;
@property BOOL allowsCellularAccess;
@property (getter=isDiscretionary) BOOL discretionary;
@property BOOL sessionSendsLaunchEvents;
@property (nullable, copy) NSDictionary *connectionProxyDictionary;
@property SSLProtocol TLSMinimumSupportedProtocol;
@property SSLProtocol TLSMaximumSupportedProtocol;
@property BOOL HTTPShouldUsePipelining;
@property BOOL HTTPShouldSetCookies;
@property NSHTTPCookieAcceptPolicy HTTPCookieAcceptPolicy;
@property (nullable, copy) NSDictionary *HTTPAdditionalHeaders;
@property NSInteger HTTPMaximumConnectionsPerHost;
@property (nullable, retain) NSHTTPCookieStorage *HTTPCookieStorage;
@property (nullable, retain) NSURLCredentialStorage *URLCredentialStorage;
@property (nullable, retain) NSURLCache *URLCache;
@property (nullable, copy) NSArray *protocolClasses;

/* Backed by the CFNetwork HTTP header and socket reachability providers. */
@property BOOL _allowsReachabilityCheck;
@property (nullable, copy) NSSet *_suppressedAutoAddedHTTPHeaders;

@end

@interface NSURLSession (NSURLSessionDeprecated)

/* Use -dataTaskWithURL: instead */
- (NSURLSessionDataTask *)dataTaskWithHTTPGetRequest:(NSURL *)url;

/* Use -dataTaskWithURL:completionHandler: instead */
- (NSURLSessionDataTask *)dataTaskWithHTTPGetRequest:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
