module c3w @if(env::DARWIN);
import std::math;
import vk;
import std::io;

extern fn int createWindow(Params params) @extern("createWindow");

fn void new(Params params, String name) {
    int window = createWindow(params);
}

fn void Window.free(self) {
  
}