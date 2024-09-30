module c3w @if(env::WIN32);
import std::math;
import std::os::win32;
import vk;
import std::io;

extern fn Window createWindow(Params params) @extern("createWindow");

fn Window new(Params params, String name) {
    return createWindow(params);
}

fn void Window.free(self) {
  
}