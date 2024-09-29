module c3w @if(env::WIN32);
import std::math;
import std::os::win32;
import vk;
import std::io;

extern fn void createWindow() @extern("WinMain");

fn void new(Params params, String name) {
    createWindow();
}