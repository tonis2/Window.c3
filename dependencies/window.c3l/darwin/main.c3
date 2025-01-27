module c3w @if(env::DARWIN);
import std::math;
import std::io;
import std::core::types;
import std::os::macos::objc;

struct DarwinWindow {
    NSWindow window;
    NSApplication app;
}

fn bool on_close(ObjcId self)
{
    io::printn("closing window..");
    if (catch self.get_ivar("NSWindow")) return true;
    return true;
}

fn NSSize resize_window(ObjcId self, NSSize frame)
{
    if (catch self.get_ivar("NSWindow")) return frame;
	io::printfn("window resized to %f %f", frame.width, frame.height);
    return frame;
}

fn Window! new(Params params, String name) {
    NSObject object = NSObject.new("NSObject"); 
    object.add_method("windowShouldClose:", &on_close)!!;

    NSApplication app = NSApplication { .cls = objc::getClass("NSApplication") };
    app.sharedApplication();
    app.setActivationPolicy(ApplicationActivationPolicy.REGULAR);

    NSWindow win = NSObject.new("NSWindow");
    win.alloc();
    ulong window_style = WindowStyleMask.CLOSABLE.val | WindowStyleMask.MINIATURIZABLE.val | BackingStore.BUFFERED.val | WindowStyleMask.TITLED.val | WindowStyleMask.RESIZABLE.val;
    win.initWithContentRect(NSRect {{params.x, params.y}, {params.width, params.height}}, window_style, window_style, false);
   
    NSString window_title = NSObject.new("NSString");
    window_title.stringWithUTF8String((ZString)name);
    win.setTitle(window_title);

    NSObject delegate = NSObject.new("NSObject");
    delegate.alloc_class_pair("WindowDelegate", 0);
    delegate.add_ivar("NSWindow", $sizeof(win), math::log2($sizeof(win)), "L")!!;
    delegate.add_method("windowWillResize:toSize:", &resize_window, "{NSSize=ff}@:{NSSize=ff}")!!;
    delegate.alloc();
    delegate.init();
    delegate.setInstanceVariable("NSWindow", win);
    win.setDelegate(delegate);
    win.makeKeyAndOrderFront(null);
    win.setIsVisible(true);
    app.activateIgnoringOtherApps(true);
    app.finishLaunching();

   Window response = Window {
        .src = {
            .window = win,
            .app = app,
        }
   };

    foreach (index, item: EventKey.values) {
        response.event_map[index] = {
           .key = item,
           .selected = false
        };
    }

    return response;
}


fn Event Window.getEvent(&self) {
    Event event_response;

    NSAutoreleasePool pool = NSObject.new("NSAutoreleasePool"); 
    pool.alloc();
    pool.init();
    defer pool.release();

    NSString loop = NSObject.new("NSString");
    loop.stringWithUTF8String("kCFRunLoopDefaultMode");

    NSDate until; 
    // NSDate until = objc::new("NSDate"); 
    // until.distantFuture();
    NSEvent event = self.src.app.nextEventMatchingMask(long.max, until, loop, true);
    int type = event.get_type();
    NSPoint pos = event.locationInWindow();

    if (type != 0) {
        // EventKey value = @enum_from_value(EventKey, value, event.value)!!;
        event_response = Event {
            .type = @enum_from_value(EventType, value, type) ?? (EventType)0,
            // .value = value,
            .mouse_x = (float)pos.x,
            .mouse_y = (float)pos.y,
        };

        switch (event_response.type) {
            case KEY_RELEASED:
            case LEFT_MOUSE_UP: 
            case RIGHT_MOUSE_UP:
            {
                // foreach (&item: self.event_map) {
                //     if (item.key == value) {
                //         item.selected = false;
                //         break;
                //     };
                // };
            }
            case LEFT_MOUSE_DOWN:
            case RIGHT_MOUSE_DOWN:
            case KEY_PRESSED: {
                // foreach (&item: self.event_map) {
                //     if (item.key == value) {
                //         item.selected = true;
                //         break;
                //     };
                // };
                break;
            }
            default: {};
        }
    }

    self.src.window.sendEvent(event);
    self.src.app.updateWindows();
    return event_response;
}

fn void Window.free(&self) {
    self.src.window.release();
    self.src.app.release();
}


enum EventType : uint (uint value)
{
    EMPTY_KEY = 0,

    LEFT_MOUSE_DOWN     = 1,
	LEFT_MOUSE_UP       = 2,
	RIGHT_MOUSE_DOWN    = 3,
	RIGHT_MOUSE_UP      = 4,
	MOUSE_MOVED         = 5,
	LEFT_MOUSE_DRAGGED  = 6,
	RIGHT_MOUSE_DRAGGED = 7,
	MOUSE_ENTERED       = 8,
	MOUSE_EXITED        = 9,
	KEY_PRESSED         = 10,
	KEY_RELEASED        = 11,
	FLAGS_CHANGED       = 12,
	APPKIT_DEFINED      = 13,
	SYSTEM_DEFINED      = 14,
	APPLICATION_DEFINED = 15,
	PERIODIC            = 16,
	CURSOR_UPDATE       = 17,
	SCROLL_WHEEL        = 22,
	TABLET_POINT        = 23,
	TABLET_PROXIMITY    = 24,
	OTHER_MOUSE_DOWN    = 25,
	OTHER_MOUSE_UP      = 26,
	OTHER_MOUSE_DRAGGED = 27,
	GESTURE             = 29,
	MAGNIFY             = 30,
	SWIPE               = 31,
	ROTATE              = 18,
	BEGIN_GESTURE       = 19,
	END_GESTURE         = 20,
	SMART_MAGNIFY       = 32,
	QUICK_LOOK          = 33,
	PRESSURE            = 34,
	DIRECT_TOUCH        = 37,
	CHANGE_MODE         = 38,
}

enum EventKey : uint (uint value)
{
    EMPTY_KEY = 0,
    ESCAPE = 9,
    A = 38,
    B = 56,
    C = 54,
    D = 40,
    E = 26,
    F = 41,
    G = 42,
    H = 43,
    I = 31,
    J = 44,
    K = 45,
    L = 46,
    M = 58,
    N = 57,
    O = 32,
    P = 33,
    Q = 24,
    R = 27,
    S = 39,
    T = 28,
    U = 30,
    V = 55,
    W = 25,
    X = 53,
    Y = 29,
    Z = 52,

    RETURN = 36,
    DELETE = 119,   
    NUMLOCK = 77,  
    SLASH = 106,
    MULTIPLY = 63,    
    SUBTRACT = 82,  
    NUM_0 = 87,
    NUM_1 = 88,    
    NUM_2 = 89, 
    NUM_3 = 83,  
    NUM_4 = 84,   
    NUM_5 = 85,    
    NUM_6 = 79, 
    NUM_7 = 80,  
    NUM_8 = 81,   
    NUM_9 = 90,    
    PERIOD = 91,    
    KP_RETURN = 104
}