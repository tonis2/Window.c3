module c3w @if(env::DARWIN);
import std::os::macos::objc;
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
alias SendString = fn void*(void*, ObjcSelector, ZString);
alias GetInt = fn int(void*, ObjcSelector);
alias GetDouble = fn double(void*, ObjcSelector);
// alias GetView = fn NSView(void*, ObjcSelector);
alias GetRect = fn NSRect(void*, ObjcSelector);
alias GetCharacters = fn NSString(void*, ObjcSelector);
alias GetPoint = fn NSPoint(void*, ObjcSelector);
alias GetID = fn ObjcId*(void*, ObjcSelector);
alias GetPtr = fn void*(void*, ObjcSelector);

faultdef IVAR_NOT_SET, IVAR_NOT_FOUND, METHOD_NOT_SET;

struct NSObject {
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
    return (NSEvent)objc::msg_send(self.id, SendDequeueEvent, "nextEventMatchingMask:untilDate:inMode:dequeue:", mask, until_date.id, in_mode.id, dequeue);
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

fn void NSApplication.setActivationPolicy(&self, ApplicationActivationPolicy policy)
{ 
    objc::msg_send(self.id, SendInt, "setActivationPolicy:", policy.val);
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
    self.id = objc::msg_send(self.id, SendContentRec, "initWithContentRect:styleMask:backing:defer:", rect, style_mask, backing, is_defer);
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

<* @require self.id == null `NSObject is already initialized` *>
macro NSObject? NSObject.add_method(NSObject self, ZString name, void* imp, ZString types = "")
{
    if(!objc::class_addMethod(self.cls, objc::sel_registerName(name), imp, types)) return METHOD_NOT_SET?;
    return self;
}

macro ObjcClass? ObjcClass.add_method(ObjcClass self, ZString name, void* imp, ZString types = "") 
{
    if(!objc::class_addMethod(self, register_name(name), imp, types)) return METHOD_NOT_SET?;
    return self;
}

macro NSObject? NSObject.add_ivar(NSObject self, ZString name, int size, double alignment, ZString types) 
{
    if(!objc::class_addIvar(self.cls, name, size, alignment, types)) return IVAR_NOT_SET?;
    return self;
}

macro ObjcIvar? ObjcId.get_ivar(ObjcId self, ZString name)
{
    ObjcIvar out;
    if(!objc::getInstanceVariable(self, name, &out)) return IVAR_NOT_FOUND?; 
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
// fn void* NSView.get_frame(self) => objc::msg_send(self, GetPtr, "frame");

fn void NSView.wants_Layer(self, bool value) => objc::msg_send(self.id, SendBool, "setWantsLayer:", value);
fn void NSView.set_layer(self, CALayer layer) => objc::msg_send(self.id, SendId, "setLayer:", layer.id);

fn void NSWindow.set_view(&self, NSView view) => objc::msg_send(self.id, SendId, "contentView", view.id);
fn NSPoint NSWindow.get_mouse_pos(&self) => objc::msg_send(self.id, GetPoint, "mouseLocationOutsideOfEventStream");

fn NSView NSWindow.get_view(&self) {
    return {
        .cls = objc::getClass("NSView"),
        .id = objc::msg_send(self.id, GetID, "contentView")
    };
}

struct NSPoint {
    double x;
    double y;
}

struct NSSize {
    double width;
    double height;
}

struct NSRect {
    NSPoint origin;
    NSSize size;
}