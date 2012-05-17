Purpose
--------------

RequestQueue is a simple class for managing multiple concurrent asynchronous URL requests in your applications.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 5.1 / Mac OS 10.7 (Xcode 4.3.2, Apple LLVM compiler 3.1)
* Earliest supported deployment target - iOS 4.3 / Mac OS 10.6
* Earliest compatible deployment target - iOS 4.0 / Mac OS 10.6

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this OS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

RequestQueue makes use of the ARC Helper library to automatically work with both ARC and non-ARC projects through conditional compilation. There is no need to exclude RequestQueue files from the ARC validation process, or to convert RequestQueue using the ARC conversion tool.


Thread Safety
--------------

You can create RQOperation and RequestQueue instances on any thread, but the methods of each instance should only be called from a single thread. Additionally, the mainQueue shared instance should only be used on the main thread.


Installation
--------------

To use RequestQueue in an app, just drag the RequestQueue class files into your project. RequestQueue has no dependencies.


Classes
-----------

The RequestQueue library consists of two main classes, the RQOperation and the RequestQueue itself.

The RQOperation is an NSOperation subclass that wraps a single, asynchronous NSURLConnection. You can use the RQOperation on its own to make a standalone asynchronous request, or you can add it to any ordinary NSOperationQueue.

The RequestQueue simplifies managing a queue of RQOperations and allows for features that are not possible with an ordinary NSOperationQueue, such as LIFO (Last-In, First-Out) queueing (see below for details).


RQOperation Properties
----------------------------

    @property (nonatomic, strong, readonly) NSURLRequest *request;

The original NSURLRequest used to initialise the operation. This is deep-copied by the NSURLConnection, so making changes to this request after creating the RQOperation will have no effect on the RQOperation, however it can be useful to retain a reference to it for the purposes of identifying the RQOperation later on.

    @property (nonatomic, copy) RQCompletionHandler completionHandler;
    
This is a block that will be called when the request either completes, fails or is cancelled. For details of the callback parameters, check the Callbacks section below.
    
    @property (nonatomic, copy) RQProgressHandler uploadProgressHandler;
    
This is a block that will be called periodically as upload data is sent by the NSURLConnection. This is mainly useful when transmitting large files to a server where you would wish to display a progress bar, and is generally not applicable for most requests. For details of the callback parameters, check the Callbacks section below.
    
    @property (nonatomic, copy) RQProgressHandler downloadProgressHandler;
    
This is a block that will be called periodically as data is downloaded by the NSURLConnection. This is mainly useful when downloading large files from a server where you would wish to display a progress bar. For details of the callback parameters, check the Callbacks section below.

    @property (nonatomic, copy) RQAuthenticationChallengeHandler authenticationChallengeHandler;
    
This is a block that will be called in the event of the server returning an authentication challenge.

    @property (nonatomic, copy) NSSet *autoRetryErrorCodes;
    
A set of error codes to compare against when deciding if the request should automatically retry or not. By default this set includes any NSURLError types that relate to poor or unavailable connections. This means that the operation will retry if the Internet is down or the connection times out, but won't retry if the UL is malformed or the resource doesn't exist (which would be pointless). You can customise this set to meet the specific needs of your application if required.

    @property (nonatomic, assign) BOOL autoRetry;
    
If set to `YES`, the operation will automatically retry if there is a connection failure instead of terminating and calling the completionHandler. The operation will compare the error code against the autoRetryErrorCodes set, and will only retry if the code is in that set. Defaults to `NO`.
    

RQOperation Methods
----------------------------

    + (RQOperation *)operationWithRequest:(NSURLRequest *)request;
    - (RQOperation *)initWithRequest:(NSURLRequest *)request;

These methods are used to create a new request operation. RQOperations are single-use, meaning that the request cannot be changed after the operation is created, and the operation can only be used to send a single instance of the request, after which is should be discarded.


RequestQueue Properties
-------------------------

	@property (nonatomic, assign) NSUInteger maxConcurrentRequestCount;
	
This is the maximum number of concurrent requests. If more requests than this are added to the queue, they will be queued until the previous requests have completed. A value of 0 means that there is no limit to the number of concurrent requests. A value of 1 means that only one request will be active at a time, and will ensure that requests are completed in the same order that they are added (assuming `queueMode` is `RequestQueueModeFirstInFirstOut`). The default value is 2.
	
	@property (nonatomic, assign, getter = isSuspended) BOOL suspended;
	
This property toggles whether the queued requests should be started or not. Requests that are already in progress will not be affected by toggling this property, but if suspended = YES, no new requests will be started until it is set to NO again. Setting this property to NO will immediately start the next queued requests downloading.
	
	@property (nonatomic, assign, readonly) NSUInteger requestCount;
	
The number of requests in the queue. This includes both active requests and pending requests.
	
	@property (nonatomic, strong, readonly) NSArray *requests;

The requests in the queue. This includes both active requests and pending requests.

    @property (nonatomic, assign) RequestQueueMode queueMode;
    
The queueMode property controls whether new request are added at the front or the back of the queue. The default value of `RequestQueueModeFirstInFirstOut` puts new requests at the back of the queue and the `RequestQueueModeLastInFirstOut` value puts them at the front. Last-in-first-out means that the more recent request is given priority. Requests that are already active will still finish first, but if a large backlog of requests builds up in the queue, newer requests will not be forced to wait until the backlog is cleared before they are dealt with.

    @property (nonatomic, assign) BOOL allowDuplicateRequests;

This property controls whether the request queue allows multiple identical requests to be queued. If set to `NO` (the default), adding a duplicate request (i.e. a request with identical parameters to another request already in the queue) will result in the previously added request being cancelled. The completion handler for the cancelled request will be called with the NSURLErrorCancelled error as normal.


RequestQueue Methods
----------------------

The RequestQueue class has the following methods:

	+ (RequestQueue *)mainQueue;
	
This returns a singleton shared instance of the request queue that can be used anywhere in your app (not thread safe, should only be called from the main thread). It is also perfectly acceptable to create your own queue instance for more finely-grained control over concurrency (for example, you could create a low-priority queue instance and a high priority queue so that your app can perform high-priority requests without them getting stuck behind a low priority request, waiting for it to finish).

	- (void)addOperation:(RQOperation *)operation;
	
This adds a new RQOperation to the queue. If there are fewer than `maxConcurrentRequestCount` operations already in the queue, this will start immediately. It is not valid to add the same RQOperation to the queue more than once (this will throw an exception), however you can add the same request to a given queue multiple times using different RQOperation instances. Note that although RQOperations are initiated in the order in which they were added (first in, first out), there is no guarantee that they will complete in the same order, unless the `maxConcurrentRequestCount` is set to 1.
	
	- (void)addRequest:(NSURLRequest *)request completionHandler:(RQCompletionHandler)completionHandler;
	
This creates a new RQOperation with the specified completion handler and adds it to the queue. Note that the same request can be added to the queue multiple times and will be downloaded multiple times. If you want to avoid adding identical requests to the queue more than once, check if the `requests` property of the queue already contains an identical request before adding it by using the `contains:` method of NSArray.
	
	- (void)cancelRequest:(NSURLRequest *)request;
	
This method will cancel the request if it is in progress and remove it from the queue. Regardless of whether the request has started or not, the completion handler block will receive the error `NSURLErrorCancelled`. *Note:* To cancel an RQOperation, you can just call the cancel method of the operation directly and it will automatically be removed from any queue to which it has been added.
	
	- (void)cancelAllRequests;
	
This method will cancel all active and queued requests and remove them from the queue.
	

Callbacks
------------

RequestQueue defines the following callback block functions that you can use to be notified about the request status and progress.

	typedef void (^RQCompletionHandler)(NSURLResponse *response, NSData *data, NSError *error);

Upon completion of a request download, your callback will be called with these arguments. If the request was successful, the error parameter will be nil. In the event of an error, response and data may be nil or may not, depending on the nature of the error. If the request was cancelled, the error code will be `NSURLErrorCancelled`.

    typedef void (^RQProgressHandler)(float progress, NSInteger bytesTransferred, NSInteger totalBytes);
    
This callback is used to track the progress of a request upload or download. The progress parameter is a floating point value between 0.0 and 1.0, useful for updating a progress bar or other visual progress indicator. The bytesTransferred and totalBytes parameters indicate the number of bytes that have been transferred and the expected total number of bytes to be transferred, respectively. Note: totalBytes is often an estimate and may sometimes be incorrect, or unavailable (in which case the value may be zero or -1). In these cases, the progress value is meaningless, and you should display an indeterminate progress indicator such as a spinner (UIActivityIndicatorView) or barber pole.