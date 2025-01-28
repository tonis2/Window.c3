module c3w @if(env::DARWIN);
import std::os::macos::objc;
import std::io;
import std::math;


def SendBool = fn void*(void*, ObjcSelector, bool);
def SendContentRec = fn void*(void*, ObjcSelector, NSRect, long, long, bool);
def SendDequeueEvent = fn void*(void*, ObjcSelector, long, void*, ObjcId, bool);
def SendDouble = fn void*(void*, ObjcSelector, double);
def SendEvent = fn void*(void*, ObjcSelector, NSEvent);
def SendId = fn void*(void*, ObjcSelector, ObjcId);
def SendIdId = fn void*(void*, ObjcSelector, ObjcId, ObjcId);
def SendInt = fn void*(void*, ObjcSelector, int);
def SendPtr = fn void*(void*, ObjcSelector, void*);
def SendSelector = fn void*(void*, ObjcSelector, ObjcSelector);
def SendSize = fn void*(void*, ObjcSelector, NSSize);
def SendString = fn void*(void*, ObjcSelector, ZString);
def GetInt = fn int(void*, ObjcSelector);
// def GetView = fn NSView(void*, ObjcSelector);
def GetRect = fn NSRect(void*, ObjcSelector);
def GetCharacters = fn NSString(void*, ObjcSelector);
def GetPoint = fn NSPoint(void*, ObjcSelector);
def GetID = fn ObjcId*(void*, ObjcSelector);
def GetPtr = fn void*(void*, ObjcSelector);

fault ObjcFault {
    IVAR_NOT_SET,
    IVAR_NOT_FOUND,
    METHOD_NOT_SET,
}

struct NSObject {
    ObjcClass cls;
    ObjcId* id;
}


def NSApplication = NSObject;
def NSStatusBar = NSObject;
def NSImage = NSObject;
def NSMenu = NSObject;
def NSMenuItem = NSObject;
def NSString = NSObject;
def NSWindow = NSObject;
def NSAutoreleasePool = NSObject;
def NSValue = NSObject;
def NSDate = NSObject;
def CALayer = NSObject;
def NSView = NSObject;

distinct NSEvent = void*;
distinct NSStatusBarItem = void*;

fn NSObject NSObject.new(ZString cls_name = "NSObject") @operator(construct)
{
    NSObject self;
    self.cls = objc::getClass(cls_name);
    return self;
}

<* @require self.id `self is not initialized` *>
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

<* @require self.id `NSApplication is not initialized` *>
fn void NSApplication.setDelegate(&self, NSObject delegate)
{
    objc::msg_send(self.id, SendId, "setDelegate:", delegate.id);
}

<* @require self.id `NSApplication is not initialized` *>
fn void NSWindow.setTitle(&self, NSString title)
{
    objc::msg_send(self.id, SendId, "setTitle:", title.id);
}

<* @require self.id `NSApplication is not initialized` *>
fn void NSApplication.terminate(&self)
{
    objc::msg_send(self.id, SendId, "terminate:", self.id);
}

<* @require self.id `NSApplication is not initialized` *>
fn void NSApplication.activateIgnoringOtherApps(&self, bool flag)
{
    objc::msg_send(self.id, SendBool, "activateIgnoringOtherApps:", flag);
}

<* @require self.id `NSApplication is not initialized` *>
fn NSEvent NSApplication.nextEventMatchingMask(&self, long mask, NSDate until_date, NSObject in_mode, bool dequeue)
{
    return (NSEvent)objc::msg_send(self.id, SendDequeueEvent, "nextEventMatchingMask:untilDate:inMode:dequeue:", mask, until_date.id, in_mode.id, dequeue);
}

<* @require self.id `NSApplication is not initialized` *>
fn void NSApplication.finishLaunching(&self)
{
    objc::msg_send(self.id, SendVoid, "finishLaunching");
}

<* @require self.id `NSApplication is not initialized` *>
fn void NSApplication.updateWindows(&self)
{
    objc::msg_send(self.id, SendVoid, "updateWindows");
}

<* @require self.id `NSApplication is not initialized` *>
fn void NSApplication.sendEvent(&self, NSEvent event)
{
    objc::msg_send(self.id, SendEvent, "sendEvent:", event);
}

<* @require self.id `NSApplication is not initialized` *>
fn void NSApplication.setActivationPolicy(&self, ApplicationActivationPolicy policy)
{ 
    objc::msg_send(self.id, SendInt, "setActivationPolicy:", policy.val);
}

<* 
    @require self.id `NSImage is not allocated` 
    @require str.id `NSString is not initialized` 
*>
fn void NSImage.initWithContentsOfFile(&self, NSString str)
{
    self.id = objc::msg_send(self.id, SendId, "initWithContentsOfFile:", str.id);
}

<* @require self.id `NSImage is not initialized` *>
fn void NSImage.setSize(&self, NSSize size)
{
    objc::msg_send(self.id, SendSize, "setSize:", size);
}

<* @require self.id `NSObject is not allocated` *>
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

<* @require self.id `NSWindow is not initialized` *>
fn void NSWindow.initWithContentRect(&self, NSRect rect, ulong style_mask, ulong backing, bool is_defer)
{
    self.id = objc::msg_send(self.id, SendContentRec, "initWithContentRect:styleMask:backing:defer:", rect, style_mask, backing, is_defer);
}

<* @require self.id `NSWindow is not initialized` *>
fn void NSWindow.makeKeyAndOrderFront(&self, ObjcSelector sel)
{
    objc::msg_send(self.id, SendSelector, "makeKeyAndOrderFront:", sel);
}

<* @require self.id `NSWindow is not initialized` *>
fn void NSWindow.setIsVisible(&self, bool flag)
{
    objc::msg_send(self.id, SendBool, "setIsVisible:", flag);
}


fn void NSObject.alloc(&self)
{
    self.id = objc::msg_send(self.cls, SendVoid, "alloc");
}

<* @require self.id `NSObject is not allocated` *>
fn void NSObject.release(&self)
{
    objc::msg_send(self.id, SendVoid, "release");
}

<* @require self.id == null `NSObject is already initialized` *>
macro NSObject! NSObject.add_method(NSObject self, ZString name, void* imp, ZString types = "")
{
    if(!objc::class_addMethod(self.cls, objc::sel_registerName(name), imp, types)) return ObjcFault.METHOD_NOT_SET?;
    return self;
}

macro ObjcClass! ObjcClass.add_method(ObjcClass self, ZString name, void* imp, ZString types = "") 
{
    if(!objc::class_addMethod(self, register_name(name), imp, types)) return ObjcFault.METHOD_NOT_SET?;
    return self;
}

macro NSObject! NSObject.add_ivar(NSObject self, ZString name, int size, double alignment, ZString types) 
{
    if(!objc::class_addIvar(self.cls, name, size, alignment, types)) return ObjcFault.IVAR_NOT_SET?;
    return self;
}

macro ObjcIvar! ObjcId.get_ivar(ObjcId self, ZString name)
{
    ObjcIvar out;
    if(!objc::getInstanceVariable(self, name, &out)) return ObjcFault.IVAR_NOT_FOUND?; 
    return out;
}

<* @require self.id `NSObject is not initialized` *>
macro void NSObject.setInstanceVariable(NSObject self, ZString name, NSObject out)
{
    objc::setInstanceVariable(self.id, name, out.id);
}

fn NSPoint NSEvent.locationInWindow(self) => objc::msg_send(self, GetPoint, "locationInWindow");
fn int NSEvent.get_type(self) => objc::msg_send(self, GetInt, "type");
fn int NSEvent.get_key(self) => objc::msg_send(self, GetInt, "keyCode");
fn NSString NSEvent.get_characters(self) => objc::msg_send(self, GetCharacters, "characters");
fn int NSEvent.get_modifierFlags(self) => objc::msg_send(self, GetInt, "modifierFlags");
// fn void* NSView.get_frame(self) => objc::msg_send(self, GetPtr, "frame");

fn void NSView.wants_Layer(self, bool value) => objc::msg_send(self.id, SendBool, "setWantsLayer:", value);
fn void NSView.set_layer(self, CALayer layer) => objc::msg_send(self.id, SendId, "setLayer:", layer.id);


<* @require self.id `NSWindow is not initialized` *>
fn void NSWindow.set_view(&self, NSView view) => objc::msg_send(self.id, SendId, "contentView", view.id);

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