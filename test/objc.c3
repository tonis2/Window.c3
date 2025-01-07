import std::io, std::os::darwin::cocoa, std::os::macos::objc;

enum WindowStyleMask : (int val)
{
    BORDERLESS                = 0,
    TITLED                    = 1 << 0,
    CLOSABLE                  = 1 << 1,
	MINIATURIZABLE            = 1 << 2,
	RESIZABLE                 = 1 << 3,
	TEXTURED_BACKGROUND       = 1 << 8,
	UNIFIED_TITLE_AND_TOOLBAR = 1 << 12,
	FULL_SCREEN               = 1 << 14,
	FULL_SIZE_CONTENT_VIEW    = 1 << 15,
	UTILITY_WINDOW            = 1 << 4,
	DOC_MODAL_WINDOW          = 1 << 6,
	NONACTIVATING_PANEL       = 1 << 7,
	HUD_WINDOW                = 1 << 13
}

distinct BackingStoreType = inline int;
const BackingStoreType BACKING_STORE_RETAINED = 0;
const BackingStoreType BACKING_STORE_NON_RETAINED = 1;
const BackingStoreType BACKING_STORE_BUFFERED = 2;

def NSApplication = void*;
def NSWindow = void*;
def AppWindow = void*;

def MsgSendEmpty = fn void*(void*, ObjcSelector);
def MsgSendId = fn void*(void*, ObjcSelector, uint);
def MsgSendPtr = fn void*(void*, ObjcSelector, void*);
def SendContentRec = fn void*(void*, ObjcSelector, Rect, long, long, bool);

extern fn ObjcClass allocateClassPair(ObjcClass class, ZString name, int) @extern("objc_allocateClassPair");
extern fn bool class_addIvar(ObjcClass class, ZString name, int size, int alignment, ZString types) @extern("class_addIvar");
extern fn ObjcIvar set_instance_variable(ObjcId class, ZString selector, void* value) @extern("object_setInstanceVariable");

fn ObjcId alloc_class(ObjcClass class) => objc::msg_send(class, MsgSendEmpty, "alloc");

struct Rect {
    int x;
    int y;
    int width;
    int height;
}

fn void! main(String[] args)
{
    ObjcId poolAlloc = objc::msg_send(objc::class_by_name("NSAutoreleasePool")!!, MsgSendEmpty, "alloc");
    ObjcId pool = objc::msg_send(poolAlloc, MsgSendEmpty, "init");
    defer objc::msg_send(pool, MsgSendEmpty, "drain");

    int macArgs = WindowStyleMask.CLOSABLE.val | WindowStyleMask.TITLED.val | BACKING_STORE_BUFFERED;

    NSApplication app = objc::msg_send(objc::class_by_name("NSApplication")!!, MsgSendEmpty, "sharedApplication");
    objc::msg_send(app, MsgSendId, "setActivationPolicy:", 0);

    NSWindow window = objc::msg_send(
                                    alloc_class(objc::class_by_name("NSWindow")!!), 
                                    SendContentRec, 
                                    "initWithContentRect:styleMask:backing:defer:",
                                    Rect {200, 200, 500, 500},
                                    macArgs,
                                    macArgs,
                                    false
                                    );

    defer objc::msg_send(window, MsgSendEmpty, "autorelease");
    if (window == null) {
        io::printfn("Failed to create window");
        return;
    };

    ObjcClass delegateClass = allocateClassPair(objc::class_by_name("NSObject")!!, "WindowDelegate", 0);
    class_addIvar(delegateClass, "RGFW_window", AppWindow.sizeof, AppWindow.sizeof * 4, "L");

    ObjcId delegate = objc::msg_send(alloc_class(delegateClass), MsgSendEmpty, "init");
    defer objc::msg_send(delegate, MsgSendEmpty, "autorelease");
    set_instance_variable(delegate, "NSWindow", window);

    objc::msg_send(window, MsgSendPtr, "setDelegate:", delegate);
    objc::msg_send(window, MsgSendId, "setIsVisible:", 1);
    objc::msg_send(window, MsgSendPtr, "makeKeyAndOrderFront:", null);
    objc::msg_send(app, MsgSendId, "activateIgnoringOtherApps:", 1);
    objc::msg_send(app, MsgSendEmpty, "finishLaunching");

    bool running = true;                  
    while (running) {

    }
}