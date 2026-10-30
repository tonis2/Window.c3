module c3w @feat(DARWIN);
import std::os::darwin, std::os::darwin::objc;
import std::os::macos;
import std::io;
import std::math;


alias SendBool = fn ObjId(ObjId, ObjSel, bool);
alias SendContentRec = fn ObjId(ObjId, ObjSel, NSRect, long, long, bool);
alias SendDequeueEvent = fn ObjId(ObjId, ObjSel, long, ObjId, ObjId, bool);
alias SendDouble = fn ObjId(ObjId, ObjSel, double);
alias SendEvent = fn ObjId(ObjId, ObjSel, NSEvent);
alias SendId = fn ObjId(ObjId, ObjSel, ObjId);
alias SendIdId = fn ObjId(ObjId, ObjSel, ObjId, ObjId);
alias SendInt = fn ObjId(ObjId, ObjSel, int);
alias SendPtr = fn ObjId(ObjId, ObjSel, void*);
alias SendSelector = fn ObjId(ObjId, ObjSel, ObjSel);
alias SendSize = fn ObjId(ObjId, ObjSel, NSSize);
// -[NSWindow setFrame:display:]. NSRect rides in the float registers as an HFA,
// the same way it does in SendContentRec.
alias SendRectBool = fn ObjId(ObjId, ObjSel, NSRect, bool);
// -[NSView initWithFrame:]. Same HFA rule for the NSRect.
alias SendRect = fn ObjId(ObjId, ObjSel, NSRect);
alias SendString = fn ObjId(ObjId, ObjSel, ZString);
alias SendPostEvent = fn ObjId(ObjId, ObjSel, NSEvent, bool);
// +[NSEvent otherEventWithType:location:modifierFlags:timestamp:windowNumber:
//  context:subtype:data1:data2:] — the one NSEvent constructor that takes no
//  hardware state, and so the only one an application can make up out of thin
//  air. NSPoint rides in the float registers as an HFA, the same way NSRect
//  does in SendContentRec.
alias SendOtherEvent = fn ObjId(ObjId, ObjSel, ulong, NSPoint, ulong, double, long, void*, short, long, long);
alias GetInt = fn int(ObjId, ObjSel);
// +[NSEvent pressedMouseButtons] returns an NSUInteger, which is 64 bits wide
// on every Mac this builds for. Reading it back as an int would work by luck —
// the flags that matter live in the low three bits — and stop working the day
// anything above bit 31 is ever set.
alias GetULong = fn ulong(ObjId, ObjSel);
alias GetDouble = fn double(ObjId, ObjSel);
// Objective-C BOOL is a signed char, so only the low byte of the return
// register is defined — reading one back as an int picks up whatever was in the
// rest of it. Same family of arm64 return-ABI trap as get_scrolling_delta below.
alias GetBool = fn char(ObjId, ObjSel);
// alias GetView = fn NSView(ObjId, ObjSel);
alias GetRect = fn NSRect(ObjId, ObjSel);
alias GetCharacters = fn NSString(ObjId, ObjSel);
alias GetPoint = fn NSPoint(ObjId, ObjSel);
alias GetID = fn ObjId(ObjId, ObjSel);
alias GetPtr = fn ObjId(ObjId, ObjSel);

faultdef IVAR_NOT_SET, METHOD_NOT_SET;

struct NSObject
{
	ObjClass cls;
	ObjId id;
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
	return (($FunctionType)&objc::msgSend)((ObjId)self.id, objc::sel_getUid($selector), $vasplat);
}

macro ObjId.call(ObjId self, $FunctionType, ZString $selector, ...)
{
	return (($FunctionType)&objc::msgSend)(self, objc::sel_getUid($selector), $vasplat);
}

fn void NSObject.alloc_class_pair(&self, ZString name, uint extra_bytes)
{
	self.cls = objc::allocateClassPair(self.cls, name, extra_bytes);
}

fn void NSApplication.sharedApplication(&self)
{
	self.id = objc::msg_send(self.cls, GetPtr, "sharedApplication");
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
	self.id = objc::msg_send(self.id, GetPtr, "init");
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
	self.id = objc::msg_send(self.cls, GetPtr, "distantFuture");
}

fn void NSDate.distantPast(&self)
{
	self.id = objc::msg_send(self.cls, GetPtr, "distantPast");
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

fn void NSWindow.makeKeyAndOrderFront(&self, ObjSel sel)
{
	objc::msg_send(self.id, SendSelector, "makeKeyAndOrderFront:", sel);
}

fn void NSWindow.setIsVisible(&self, bool flag)
{
	objc::msg_send(self.id, SendBool, "setIsVisible:", flag);
}

fn void NSObject.alloc(&self)
{
	self.id = objc::msg_send(self.cls, GetPtr, "alloc");
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

// The std binding of class_addIvar (std::os::darwin::objc) types size as int:
// the real C signature is size_t. On arm64 the upper half of a 32-bit argument
// register is undefined, so the runtime would read whatever was left there as
// the ivar's size. Correctly-typed binding:
extern fn bool class_add_ivar(ObjClass cls, ZString name, usz size, char alignment, ZString types) @cname("class_addIvar");

macro NSObject? NSObject.add_ivar(NSObject self, ZString name, usz size, char alignment, ZString types)
{
	if (!class_add_ivar(self.cls, name, size, alignment, types)) return IVAR_NOT_SET~;
	return self;
}

macro void NSObject.setInstanceVariable(NSObject self, ZString name, NSObject out)
{
	objc::object_setInstanceVariable(self.id, name, (void*)out.id);
}

fn NSPoint NSEvent.locationInWindow(self) => objc::msg_send(self, GetPoint, "locationInWindow");
fn int NSEvent.get_type(self) => objc::msg_send(self, GetInt, "type");
fn int NSEvent.get_key(self) => objc::msg_send(self, GetInt, "keyCode");
fn int NSEvent.get_scroll(self) => objc::msg_send(self, GetInt, "scrollingDeltaY");
fn double NSEvent.get_delta(self) => objc::msg_send(self, GetDouble, "deltaY");

<*
 The mouse's own movement for this event, in points, independent of where the
 cursor ended up.

 **This is what pointer lock is made of.** `mouseLocationOutsideOfEventStream`
 stops moving the moment the cursor reaches the edge of the screen, and it stops
 moving entirely once the cursor is decoupled from the mouse — so a look built
 by differencing positions ends at the screen's edge, which is the whole problem
 a lock exists to solve. `deltaX`/`deltaY` are the hardware's report and keep
 arriving.

 Positive x is right; positive y is DOWN, which is AppKit's convention for these
 two fields and the opposite of `locationInWindow`'s. `Window.getMouseDelta`
 hands them on unchanged and `scene/input.c3` is where the flip happens.
*>
fn double NSEvent.get_delta_x(self) => objc::msg_send(self, GetDouble, "deltaX");
fn double NSEvent.get_delta_y(self) => objc::msg_send(self, GetDouble, "deltaY");

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
	ObjId chars = objc::msg_send(self, GetPtr, "characters");
	if (!chars) return "";
	return (ZString)objc::msg_send(chars, GetPtr, "UTF8String");
}
// fn void* NSView.get_frame(self) => objc::msg_send(self, GetPtr, "frame");

fn void NSView.wants_Layer(self, bool value) => objc::msg_send(self.id, SendBool, "setWantsLayer:", value);
fn void NSView.set_layer(self, CALayer layer) => objc::msg_send(self.id, SendId, "setLayer:", layer.id);

// backingScaleFactor returns CGFloat — must go through a double-returning
// call, like get_scrolling_delta above.
fn ulong NSWindow.style_mask(&self) => objc::msg_send(self.id, GetULong, "styleMask");
// `toggleFullScreen:` and not `setFullScreen:`, because AppKit has no setter —
// the state is read off the style mask and changed by asking for the change.
fn void NSWindow.toggle_fullscreen(&self) => objc::msg_send(self.id, SendPtr, "toggleFullScreen:", null);
fn double NSWindow.backing_scale_factor(&self) => objc::msg_send(self.id, GetDouble, "backingScaleFactor");
fn void CALayer.set_contents_scale(&self, double scale) => objc::msg_send(self.id, SendDouble, "setContentsScale:", scale);

// The selector here was "contentView" — the *getter*, sent with an argument the
// runtime then ignored. It read as a setter and set nothing, which went unnoticed
// because the only caller passed the view it had just read back off the window.
fn void NSWindow.set_view(&self, NSView view) => objc::msg_send(self.id, SendId, "setContentView:", view.id);

// Returns BOOL — the window refuses if the current first responder will not
// resign. Nothing here has anything to resign, so the answer is not read.
fn void NSWindow.make_first_responder(&self, NSView view) => objc::msg_send(self.id, SendId, "makeFirstResponder:", view.id);

fn void NSView.initWithFrame(&self, NSRect frame)
{
	self.id = objc::msg_send(self.id, SendRect, "initWithFrame:", frame);
}
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
