module c3w @if(env::WIN32) @link(env::WIN32, env::VKPATH);
import std::math;
import std::os::win32;
import vk;
import std::io;


extern fn Window createWindow(Params params) @extern("createWindow");
extern fn Event getEvent(Window window) @extern("getEvent");
extern fn MouseParams getMousePos(Window window) @extern("getMousePos");
extern fn void destroy(Window window) @extern("destroy");

fn Window new(Params params, String name) {
    return createWindow(params);
}

fn Event Window.getEvent(self) {
    Event event = getEvent(self);
    if (event.value > 0 && event.value <= 5) {
        event.mouse_click = (MouseButton)event.value;
    }
   
    return event;
}

fn void Window.free(self) {
  destroy(self);
}