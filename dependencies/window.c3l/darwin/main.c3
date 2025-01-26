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
   
    NSObject window_title = NSObject.new("NSString");
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

    return Window {
        .src = {
            .window = win,
            .app = app,
        }
    };
}