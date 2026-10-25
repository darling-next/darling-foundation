# Darling Foundation

*Note: GitHub says this repository is based on gnusteps/libs-base. That was true in the past but it has since been replaced with an entirely different base project (Appportable Cocotron, and some others). We are not thousands of commits behind 😆.*

## TODO
- [ ] Remove warnings

## Conformance notes
- `-[NSDictionary writeToURL:error:]` is implemented on the public base class:
  it serializes with `CFPropertyListCreateData` (XML v1.0), writes through the
  error-preserving `NSData` writer, maps POSIX write failures to Cocoa
  `NSFileWrite*` codes and rejects non-file URL schemes. `__NSCFDictionary`
  inherits it by ordinary dispatch. Current upstream and the vendored
  swift-corelibs reference do not provide this selector.
- `NSOperationQueue.underlyingQueue` retains the supplied executor separately
  from its private serial scheduler. Non-main operations execute on that queue;
  clearing it restores global-queue execution. Scheduler bookkeeping does not
  move onto the caller's executor.
- `-[NSData _createDispatchData]` exposes the existing owned dispatch-data
  snapshot to ARC consumers. Each enumerated region pointer already addresses
  that region; its logical range location is not added a second time. The
  snapshot copies bytes, so it does not borrow the input object's lifetime.
  These primitives do not implement NSURLSession private transport policies.
