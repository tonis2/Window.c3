# Window.c3
Window manager for [C3](https://c3-lang.org/)

Basic window manager for vulkan.

Currently supports
* Windows (win32)
* MacOS (cocoa)
* Linux (X11, Wayland)

### How to use
Add `window.c3l` file to your C3 project dependencies folder, and then link it in `project.json` 
with `"dependencies": ["c3w"]`

------
### Running with vulkan on macOS

Install VulkanSDK and add vulkan lib file path as `rpath` to the run command.
Its the folder with `vulkan.1.dylib` file
````
c3c run cube -z -rpath -z /Users/my_user/VulkanSDK/macOS/lib
````

------
### Running vulkan on linux
Choosing wayland or X11 can be done with feature tag to c3
```
"features": ["WAYLAND"]
"features": ["X11"]
```