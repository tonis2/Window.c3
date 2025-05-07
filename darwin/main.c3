module c3w @if(env::DARWIN);
import std::math;
import std::io;
import std::core::types;
import std::os::macos::objc;

struct DarwinWindow {
    NSWindow window;
    NSApplication app;
    NSView view;
    CALayer layer;
    EventMap event_map;
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
	io::printfn("window sresized to %f %f", frame.width, frame.height);
    return frame;
}

fn Window? new(Params params, String name) {
    NSObject object = NSObject.new("NSObject"); 
    object.add_method("windowShouldClose:", &on_close)!!;

    NSApplication app = { .cls = objc::getClass("NSApplication") };
    app.sharedApplication();
    app.setActivationPolicy(ApplicationActivationPolicy.REGULAR);

    NSWindow win = new_object("NSWindow");
    win.alloc();

    ulong window_style = WindowStyleMask.CLOSABLE.val | WindowStyleMask.MINIATURIZABLE.val | BackingStore.BUFFERED.val | WindowStyleMask.TITLED.val | WindowStyleMask.RESIZABLE.val;
    win.initWithContentRect(NSRect {{params.x, params.y}, {params.width, params.height}}, window_style, window_style, false);
   
    NSString window_title = new_object("NSString");
    window_title.stringWithUTF8String((ZString)name);
    win.setTitle(window_title);

    NSObject delegate = new_object("NSObject");
    delegate.alloc_class_pair("WindowDelegate", 0);
    delegate.add_ivar("NSWindow", $sizeof(win), math::log2($sizeof(win)), "L")!!;
    delegate.add_method("windowWillResize:toSize:", &resize_window, "{NSSize=ff}@:{NSSize=ff}")!!;
    // delegate.add_method("windowDidMiniaturize::", &resize_window, "")!!;
    // delegate.add_method("windowDidDeminiaturize::", &resize_window, "")!!;
    

    delegate.alloc();
    delegate.init();
    delegate.setInstanceVariable("NSWindow", win);
    win.setDelegate(delegate);

    win.makeKeyAndOrderFront(null);
    win.setIsVisible(true);
  
    app.activateIgnoringOtherApps(true);
    app.finishLaunching();

    NSView view = win.get_view();
    // NSObject.new("NSView");
    // view.alloc();
    // view.init();

    CALayer layer = new_object("CAMetalLayer");
    layer.alloc();
    layer.init();

    view.set_layer(layer);
    view.wants_Layer(true);
    win.set_view(view);
  
    Window response = {
        .src = {
            .window = win,
            .app = app,
            .view = view,
            .layer = layer
        },
        .width = params.width,
        .height = params.height
    };

    return response;
}

fn float[<2>] Window.getMousePos(self) {
   NSPoint point = self.src.window.get_mouse_pos();
   return {(float)point.x, (float)point.y};
}

fn EventMap[] Window.getEvent(&self) {
    NSAutoreleasePool pool = new_object("NSAutoreleasePool"); 
    pool.alloc();
    pool.init();
    defer pool.release();

    NSString loop = new_object("NSString");
    loop.stringWithUTF8String("kCFRunLoopDefaultMode");

    NSDate until; 
    // NSDate until = objc::new("NSDate"); 
    // until.distantFuture();
    NSEvent event = self.src.app.nextEventMatchingMask(long.max, until, loop, true);
    int type = event.get_type();

    self.src.event_map.set(MOUSE_SCROLL_UP, true);
    self.src.event_map.set(MOUSE_SCROLL_UP, true);

    if (type != 0) {
        EventType event_type = @enum_from_value(EventType, value, type)!!;
        switch (event_type) {
            case SCROLL_WHEEL: {
                double delta = event.get_delta();
                if (delta > 0) {
                    self.src.event_map.set(MOUSE_SCROLL_UP, true);
                }
                else {
                    self.src.event_map.set(MOUSE_SCROLL_DOWN, true);
                }
                break;
            }
            case LEFT_MOUSE_UP:
            case RIGHT_MOUSE_UP:
            {
                self.src.event_map.set(event_type, false);
                break;
            }
            case LEFT_MOUSE_DOWN:
            case RIGHT_MOUSE_DOWN: {
                self.src.event_map.set(event_type, true);
                break;
            }
            case KEY_PRESSED: {
                int key = event.get_key();
                EventKey event_value = @enum_from_value(EventKey, value, key) ?? EventKey.A;
                self.src.event_map.set(event_value, true);
            }
            case KEY_RELEASED: {
                int key = event.get_key();
                EventKey event_value = @enum_from_value(EventKey, value, key) ?? EventKey.A;
                self.src.event_map.set(event_value, false);
            }
            default: {};
        }
    }

    self.src.window.sendEvent(event);
    self.src.app.updateWindows();
    return self.src.event_map;
}

fn void Window.free(&self) {
    self.src.layer.release();
    self.src.window.release();
    self.src.app.terminate();
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
    A = 0,
    B = 11,
    C = 8,
    D = 2,
    E = 14,
    F = 3,
    G = 5,
    H = 4,
    I = 34,
    J = 38,
    K = 40,
    L = 37,
    M = 46,
    N = 45,
    O = 31,
    P = 35,
    Q = 12,
    R = 15,
    S = 1,
    T = 17,
    U = 32,
    V = 9,
    W = 13,
    X = 7,
    Y = 16,
    Z = 6,

    ESCAPE = 53,
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
    KP_RETURN = 104,
    F1 = 122,
    F2 = 120,
    F3 = 99,
    F4 = 118,
    F5 = 96,
    F6 = 97,
    F7 = 98,
    F8 = 100,
    F9 = 101,
    F10 = 109,
    F11 = 103,
    F12 = 111,
    F13 = 105,
    F14 = 107,
    F15 = 113,
    F16 = 106,
    F17 = 64,
    F18 = 79,
    F19 = 80,
    F20 = 90,
    VOLUME_UP = 72,
    VOLUME_DOWN = 73,
    MUTE = 74,
    HOME = 115,
    END = 119,
    PAGE_UP = 116,
    PAGE_DOWN = 121,
    LEFT_ARROW = 123,
    RIGHT_ARROW = 124,
    DOWN_ARROW = 125,
    UP_ARROW = 126,

    MOUSE_SCROLL_DOWN = 270,
    MOUSE_SCROLL_UP = 271,

    LEFT_MOUSE = 272,
    RIGHT_MOUSE = 273,
    MIDDLE_MOUSE = 274,
}