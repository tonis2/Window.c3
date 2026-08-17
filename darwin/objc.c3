module c3w @feat(DARWIN);
import std::os::macos::objc;
import std::os::macos::objc::ns;
import std::io;
import std::math;


alias SendBool = fn void*(void*, ObjcSelector, bool);
alias SendContentRec = fn void*(void*, ObjcSelector, NSRect, long, long, bool);
alias SendDequeueEvent = fn void*(void*, ObjcSelector, long, void*, ObjcId, bool);
alias SendDouble = fn void*(void*, ObjcSelector, double);
alias SendEvent = fn void*(void*, ObjcSelector, NSEvent);
alias SendId = fn void*(void*, ObjcSelector, ObjcId);
alias SendIdId = fn void*(void*, ObjcSelector, ObjcId, ObjcId);
alias SendInt = fn void*(void*, ObjcSelector, int);
alias SendPtr = fn void*(void*, ObjcSelector, void*);
alias SendSelector = fn void*(void*, ObjcSelector, ObjcSelector);
alias SendSize = fn void*(void*, ObjcSelector, NSSize);
// -[NSWindow setFrame:display:]. NSRect rides in the float registers as an HFA,
// the same way it does in SendContentRec.
alias SendRectBool = fn void*(void*, ObjcSelector, NSRect, bool);
alias SendString = fn void*(void*, ObjcSelector, ZString);
alias SendPostEvent = fn void*(void*, ObjcSelector, NSEvent, bool);
// +[NSEvent otherEventWithType:location:modifierFlags:timestamp:windowNumber:
//  context:subtype:data1:data2:] — the one NSEvent constructor that takes no
//  hardware state, and so the only one an application can make up out of thin
//  air. NSPoint rides in the float registers as an HFA, the same way NSRect
//  does in SendContentRec.
alias SendOtherEvent = fn void*(void*, ObjcSelector, ulong, NSPoint, ulong, double, long, void*, short, long, long);
alias GetInt = fn int(void*, ObjcSelector);
alias GetDouble = fn double(void*, ObjcSelector);
// Objective-C BOOL is a signed char, so only the low byte of the return
// register is defined — reading one back as an int picks up whatever was in the
// rest of it. Same family of arm64 return-ABI trap as get_scrolling_delta below.
alias GetBool = fn char(void*, ObjcSelector);
// alias GetView = fn NSView(void*, ObjcSelector);
alias GetRect = fn NSRect(void*, ObjcSelector);
alias GetCharacters = fn NSString(void*, ObjcSelector);
alias GetPoint = fn NSPoint(void*, ObjcSelector);
alias GetID = fn ObjcId*(void*, ObjcSelector);
alias GetPtr = fn void*(void*, ObjcSelector);

faultdef IVAR_NOT_SET, IVAR_NOT_FOUND, METHOD_NOT_SET;

struct NSObject
{
	ObjcClass cls;
	ObjcId* id;
}

alias NSApplication = NSObject;
alias NSStatusBar = NSObject;
alias NSImage = NSObject;
alias NSMenu = NSObject;
alias NSMenuItem = NSObject;
alias NSString = NSObject;
alias NSWindow = NSObject;
alias NSAutoreleasePool = NSObject;
alias NSValue = NSObject;
alias NSDate = NSObject;
alias CALayer = NSObject;
alias NSView = NSObject;

typedef NSEvent = void*;
typedef NSStatusBarItem = void*;

fn NSObject new_object(ZString cls_name = "NSObject")
{
	NSObject self;
	self.cls = objc::getClass(cls_name);
	return self;
}

macro NSObject.call(&self, $FunctionType, ZString $selector, ...)
{
	return (($FunctionType)&objc::msgSend)((ObjcId)self.id, objc::sel_getUid($selector), $vasplat);
}

macro ObjcId.call(ObjcId self, $FunctionType, ZString $selector, ...)
{
	return (($FunctionType)&objc::msgSend)(self, objc::sel_getUid($selector), $vasplat);
}

fn void NSObject.alloc_class_pair(&self, ZString name, uint extra_bytes)
{
	self.cls = objc::allocateClassPair(self.cls, name, extra_bytes);
}

fn void NSApplication.sharedApplication(&self)
{
	self.id = objc::msg_send(self.cls, SendVoid, "sharedApplication");
}

fn void NSApplication.setDelegate(&self, NSObject delegate)
{
	objc::msg_send(self.id, SendId, "setDelegate:", delegate.id);
}

fn void NSWindow.setTitle(&self, NSString title)
{
	objc::msg_send(self.id, SendId, "setTitle:", title.id);
}

fn void NSApplication.terminate(&self)
{
	objc::msg_send(self.id, SendId, "terminate:", self.id);
}

fn void NSApplication.activateIgnoringOtherApps(&self, bool flag)
{
	objc::msg_send(self.id, SendBool, "activateIgnoringOtherApps:", flag);
}

fn NSEvent NSApplication.nextEventMatchingMask(&self, long mask, NSDate until_date, NSObject in_mode, bool dequeue)
{
	return (NSEvent)objc::msg_send(
		self.id,
		SendDequeueEvent,
		"nextEventMatchingMask:untilDate:inMode:dequeue:",
		mask,
		until_date.id,
		in_mode.id,
		dequeue
	);
}

fn void NSApplication.finishLaunching(&self)
{
	objc::msg_send(self.id, SendVoid, "finishLaunching");
}

fn void NSApplication.updateWindows(&self)
{
	objc::msg_send(self.id, SendVoid, "updateWindows");
}

fn void NSApplication.sendEvent(&self, NSEvent event)
{
	objc::msg_send(self.id, SendEvent, "sendEvent:", event);
}

<*
 Put an event at the head of the queue from any thread.

 One of the few AppKit calls documented as thread-safe, and the reason
 `Window.wake` can exist at all: it is what a worker thread has to reach for
 when the main thread is parked in nextEventMatchingMask.

 @param at_start : `True to jump the queue, so a wake is not stuck behind a burst of input.`
*>
fn void NSApplication.postEvent(&self, NSEvent event, bool at_start)
{
	objc::msg_send(self.id, SendPostEvent, "postEvent:atStart:", event, at_start);
}

<*
 An application-defined event carrying nothing.

 Autoreleased, so the caller needs a pool in place — which on a worker thread
 means making one. Every field is zero: the event exists to be delivered, and
 whatever reads the queue is expected to ignore it.
*>
fn NSEvent new_wake_event()
{
	NSObject cls = new_object("NSEvent");
	return (NSEvent)objc::msg_send(
		cls.cls,
		SendOtherEvent,
		"otherEventWithType:location:modifierFlags:timestamp:windowNumber:context:subtype:data1:data2:",
		(ulong)DarwinEventType.APPLICATION_DEFINED.value,
		(NSPoint){ 0, 0 },
		(ulong)0,
		0.0,
		(long)0,
		null,
		(short)0,
		(long)0,
		(long)0
	);
}

fn void NSApplication.setActivationPolicy(&self, NSApplicationActivationPolicy policy)
{
	objc::msg_send(self.id, SendInt, "setActivationPolicy:", (int)policy);
}

fn void NSImage.initWithContentsOfFile(&self, NSString str)
{
	self.id = objc::msg_send(self.id, SendId, "initWithContentsOfFile:", str.id);
}

fn void NSImage.setSize(&self, NSSize size)
{
	objc::msg_send(self.id, SendSize, "setSize:", size);
}


fn void NSObject.init(&self)
{
	self.id = objc::msg_send(self.id, SendVoid, "init");
}

fn void NSValue.valueWithPointer(&self, void* ptr)
{
	self.id = objc::msg_send(self.cls, SendPtr, "valueWithPointer:", ptr);
}

fn void NSString.stringWithUTF8String(&self, ZString str)
{
	self.id = objc::msg_send(self.cls, SendString, "stringWithUTF8String:", str);
}

fn void NSDate.distantFuture(&self)
{
	self.id = objc::msg_send(self.cls, SendVoid, "distantFuture");
}

fn void NSDate.distantPast(&self)
{
	self.id = objc::msg_send(self.cls, SendVoid, "distantPast");
}


fn void NSWindow.initWithContentRect(&self, NSRect rect, ulong style_mask, ulong backing, bool is_defer)
{
	self.id = objc::msg_send(
		self.id,
		SendContentRec,
		"initWithContentRect:styleMask:backing:defer:",
		rect,
		(long)style_mask,
		(long)backing,
		is_defer
	);
}

fn void NSWindow.makeKeyAndOrderFront(&self, ObjcSelector sel)
{
	objc::msg_send(self.id, SendSelector, "makeKeyAndOrderFront:", sel);
}

fn void NSWindow.setIsVisible(&self, bool flag)
{
	objc::msg_send(self.id, SendBool, "setIsVisible:", flag);
}

fn void NSObject.alloc(&self)
{
	self.id = objc::msg_send(self.cls, SendVoid, "alloc");
}


fn void NSObject.release(&self)
{
	objc::msg_send(self.id, SendVoid, "release");
}

macro NSObject? NSObject.add_method(NSObject self, ZString name, void* imp, ZString types = "")
{
	if (!objc::class_addMethod(self.cls, objc::sel_registerName(name), imp, types)) return METHOD_NOT_SET~;
	return self;
}

macro ObjcClass? ObjcClass.add_method(ObjcClass self, ZString name, void* imp, ZString types = "")
{
	if (!objc::class_addMethod(self, register_name(name), imp, types)) return METHOD_NOT_SET~;
	return self;
}

// The std binding of class_addIvar (std::os::macos::objc) mistypes alignment
// as double: the real C signature is uint8_t. The double rides in a float
// register while the callee reads the integer registers, so the ivar gets
// registered with the LOW BYTE OF THE TYPES POINTER as its log2 alignment and
// a garbage types pointer — whenever the linker happens to place the types
// string at an address whose low byte is >= 31, the ivar offset overflows to
// 2^31 and the next setInstanceVariable crashes. Correctly-typed binding:
extern fn bool class_add_ivar(ObjcClass cls, ZString name, usz size, char alignment, ZString types) @cname("class_addIvar");

macro NSObject? NSObject.add_ivar(NSObject self, ZString name, usz size, char alignment, ZString types)
{
	if (!class_add_ivar(self.cls, name, size, alignment, types)) return IVAR_NOT_SET~;
	return self;
}

macro ObjcIvar? ObjcId.get_ivar(ObjcId self, ZString name)
{
	ObjcIvar out;
	if (!objc::getInstanceVariable(self, name, &out)) return IVAR_NOT_FOUND~;
	return out;
}

macro void NSObject.setInstanceVariable(NSObject self, ZString name, NSObject out)
{
	objc::setInstanceVariable(self.id, name, out.id);
}

fn NSPoint NSEvent.locationInWindow(self) => objc::msg_send(self, GetPoint, "locationInWindow");
fn int NSEvent.get_type(self) => objc::msg_send(self, GetInt, "type");
fn int NSEvent.get_key(self) => objc::msg_send(self, GetInt, "keyCode");
fn int NSEvent.get_scroll(self) => objc::msg_send(self, GetInt, "scrollingDeltaY");
fn double NSEvent.get_delta(self) => objc::msg_send(self, GetDouble, "deltaY");

fn NSString NSEvent.get_characters(self) => objc::msg_send(self, GetCharacters, "characters");
fn int NSEvent.get_modifierFlags(self) => objc::msg_send(self, GetInt, "modifierFlags");

// scrollingDeltaY returns CGFloat — must be read through a double-returning
// call (get_scroll above reads it as int, which returns garbage on arm64).
fn double NSEvent.get_scrolling_delta(self) => objc::msg_send(self, GetDouble, "scrollingDeltaY");

// The horizontal half of the same gesture. A wheel mouse never sets it; a
// trackpad's two-finger swipe fills in both axes, which is the whole reason a
// scroll is a vector here rather than a number.
fn double NSEvent.get_scrolling_delta_x(self) => objc::msg_send(self, GetDouble, "scrollingDeltaX");

<*
 Whether this scroll came from a surface that reports pixels rather than
 detents — a trackpad or a Magic Mouse, as against a wheel that clicks.

 Worth surfacing because the two are not the same quantity in different units.
 A wheel notch is one event worth roughly a unit; a trackpad flick is a stream
 of events worth tens of points between two frames. Anything that scales a
 scroll — a zoom especially — has to know which it is holding, or it is calm
 under one input device and violent under the other.
*>
fn bool NSEvent.has_precise_scrolling_deltas(self)
	=> objc::msg_send(self, GetBool, "hasPreciseScrollingDeltas") != 0;

// The typed characters of a key event as UTF-8. Goes through the NSString id
// directly: returning the 16-byte NSString struct from msgSend (as
// get_characters does) scrambles the fields on arm64.
fn ZString NSEvent.get_characters_utf8(self)
{
	void* chars = objc::msg_send(self, GetPtr, "characters");
	if (!chars) return "";
	return (ZString)objc::msg_send(chars, GetPtr, "UTF8String");
}
// fn void* NSView.get_frame(self) => objc::msg_send(self, GetPtr, "frame");

fn void NSView.wants_Layer(self, bool value) => objc::msg_send(self.id, SendBool, "setWantsLayer:", value);
fn void NSView.set_layer(self, CALayer layer) => objc::msg_send(self.id, SendId, "setLayer:", layer.id);

// backingScaleFactor returns CGFloat — must go through a double-returning
// call, like get_scrolling_delta above.
fn double NSWindow.backing_scale_factor(&self) => objc::msg_send(self.id, GetDouble, "backingScaleFactor");
fn void CALayer.set_contents_scale(&self, double scale) => objc::msg_send(self.id, SendDouble, "setContentsScale:", scale);

fn void NSWindow.set_view(&self, NSView view) => objc::msg_send(self.id, SendId, "contentView", view.id);
fn NSPoint NSWindow.get_mouse_pos(&self) => objc::msg_send(self.id, GetPoint, "mouseLocationOutsideOfEventStream");

fn NSView NSWindow.get_view(&self)
{
	return { .cls = objc::getClass("NSView"), .id = objc::msg_send(self.id, GetID, "contentView") };
}

struct NSPoint
{
	double x;
	double y;
}

struct NSSize
{
	double width;
	double height;
}

struct NSRect
{
	NSPoint origin;
	NSSize size;
}
