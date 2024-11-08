import std;

fn void run() @init @if(env::WIN32)
{
  io::printfn("const String VKPATH = `%s %s`;", env::get_var("VK_SDK_PATH")!!, "vulkan.1.lib");
}