/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

// NSDistributedNotificationCenter, implemented rather than stubbed.
//
// WHY THIS FILE NO LONGER RETURNS nil. Every method here used to be an NSLog stub and
// +defaultCenter a hardcoded `return nil`. That is not a harmless placeholder: a caller that
// takes the center and calls an API on it gets a nil receiver, and when the caller is Swift the
// failure is a SIGSEGV rather than a no-op, because the Swift bridge of a non-optional
// Objective-C return does not test for nil.
//
// MEASURED (2026-10-15, Xcode 26.3's IDEXCBuildSupportCore, x86_64 guest): the plug-in's
// XCBSystemServiceProvider.init() does
//     NSDistributedNotificationCenter.defaultCenter
//     .notifications(named: "buildOperationClass", object: nil)      // Foundation's async sequence
// and the nil center made Foundation's Swift `Notifications.init(center:name:object:)` call
// `-[NSNotificationCenter addObserverForName:object:queue:usingBlock:]` on nil, returning nil;
// Swift then bridged that non-optional result to `Any` and called `swift_getObjectType(NULL)`,
// faulting at address 0 inside libswiftCore. The record is evidence/xcb-sigsegv-rung.
//
// WHAT IS REAL HERE, AND WHAT IS NOT. Darling has no cross-process notification transport:
// CoreFoundation's own CFNotificationCenterGetDistributedCenter() returns a center whose observer
// list is process-local (src/external/corefoundation/CFNotificationCenter.c), and no darwin
// notification daemon exists in this tree. So this class is implemented as a REAL, process-local
// center built on the registry the superclass already owns: registration, removal, posting,
// userInfo and the `suspended` mark all do what their names say, and observers registered here
// are called for posts made here. What is NOT provided is delivery BETWEEN processes or sessions,
// and that limit is stated here rather than hidden behind an NSLog: a caller that waits for a
// notification another process posts will keep waiting. The `suspensionBehavior:` argument is a
// delivery hint for a suspended center; the mark this class implements is `suspended` itself
// (posts are held while it is set and delivered when it is cleared).

#import <NSDistributedNotificationCenter.h>
#import "NSNotificationInternal.h"
#import <Foundation/NSMutableArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <dispatch/dispatch.h>
#import <pthread.h>

// The header exports this constant and nothing ever defined it, so a caller that names it fails to
// load. Apple's NSDistributedNotificationCenterType has exactly this one value.
NSDistributedNotificationCenterType const NSLocalNotificationCenterType = @"NSLocalNotificationCenterType";

@implementation NSDistributedNotificationCenter

+ (NSDistributedNotificationCenter *)defaultCenter
{
	static NSDistributedNotificationCenter *center = nil;
	static dispatch_once_t once = 0L;

	// One center per machine, built once. The instance is deliberately a DIFFERENT object from
	// +[NSNotificationCenter defaultCenter]: the two centers keep separate observer lists on
	// macOS, so a distributed observer must not be woken by a local post and vice versa.
	dispatch_once(&once, ^{
		center = [[NSDistributedNotificationCenter alloc] init];
	});

	return center;
}

+ (NSDistributedNotificationCenter *)notificationCenterForType:(NSDistributedNotificationCenterType)notificationCenterType
{
	// Apple defines one type (NSLocalNotificationCenterType) and no per-session centre in a
	// single-session process; every type therefore resolves to this machine's centre.
	return [self defaultCenter];
}

- (BOOL)suspended
{
	return _suspended;
}

- (void)setSuspended:(BOOL)suspended
{
	NSArray *held = nil;

	pthread_mutex_lock(&_observersLock);
	if (_suspended != suspended) {
		_suspended = suspended;
		if (!suspended) {
			// Take ownership of the held notifications and release the list in one step, so a
			// concurrent post cannot append to a list that is being delivered.
			held = _heldNotifications;
			_heldNotifications = nil;
		}
	}
	pthread_mutex_unlock(&_observersLock);

	// Delivered OUTSIDE the lock: an observer callback may post again, and the registry it
	// walks must not be held while it runs.
	for (NSNotification *notification in held) {
		[super postNotification:notification];
	}
	[held release];
}

- (BOOL)holdWhileSuspendedWithName:(NSNotificationName)name object:(id)object userInfo:(NSDictionary *)userInfo
{
	// Returns YES when the post was held instead of delivered.
	BOOL hold;

	pthread_mutex_lock(&_observersLock);
	hold = _suspended;
	if (hold) {
		if (_heldNotifications == nil) {
			_heldNotifications = [[NSMutableArray alloc] init];
		}
		// A plain notification (not the superclass's pooled temporary): it outlives this call.
		[_heldNotifications addObject:[NSNotification notificationWithName:name object:object userInfo:userInfo]];
	}
	pthread_mutex_unlock(&_observersLock);

	return hold;
}

- (void)addObserver:(id)observer
	selector:(SEL)selector
	name:(NSNotificationName)name
	object:(NSString *)object
	suspensionBehavior:(NSNotificationSuspensionBehavior)suspensionBehavior
{
	// What the behavior names is how a HOLDING centre treats a notification for this observer;
	// this centre's holding state is `suspended` and every held notification is delivered on
	// resume, which is NSNotificationSuspensionBehaviorHold. The registration itself is the one
	// the superclass owns, so an observer is a real record and removal works on it.
	(void)suspensionBehavior;
	[super addObserver:observer selector:selector name:name object:object];
}

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName object:(NSString *)anObject
{
	[super addObserver:observer selector:aSelector name:aName object:anObject];
}

- (void)postNotificationName:(NSNotificationName)aName
	object:(NSString *)anObject
	userInfo:(NSDictionary *)aUserInfo
	deliverImmediately:(BOOL)deliverImmediately
{
	// `deliverImmediately` asks a suspended centre to skip its hold; Apple's own header documents
	// it as such ("the notification is delivered before the method returns, even if the centre is
	// suspended").
	if (deliverImmediately) {
		[super postNotificationName:aName object:anObject userInfo:aUserInfo];
		return;
	}
	[self postNotificationName:aName object:anObject userInfo:aUserInfo];
}

- (void)postNotificationName:(NSNotificationName)aName
	object:(NSString *)anObject
	userInfo:(NSDictionary *)aUserInfo
	options:(NSDistributedNotificationOptions)options
{
	if (options & NSDistributedNotificationDeliverImmediately) {
		[super postNotificationName:aName object:anObject userInfo:aUserInfo];
		return;
	}
	// NSDistributedNotificationPostToAllSessions has no meaning while there is one session and no
	// transport; it is accepted and the notification is posted to this process's observers.
	[self postNotificationName:aName object:anObject userInfo:aUserInfo];
}

- (void)postNotificationName:(NSNotificationName)aName object:(NSString *)anObject userInfo:(NSDictionary *)aUserInfo
{
	if ([self holdWhileSuspendedWithName:aName object:anObject userInfo:aUserInfo]) {
		return;
	}
	[super postNotificationName:aName object:anObject userInfo:aUserInfo];
}

- (void)removeObserver:(id)observer name:(NSNotificationName)aName object:(NSString *)anObject
{
	[super removeObserver:observer name:aName object:anObject];
}

@end
