# Window.c3
Window manager for [C3](https://c3-lang.org/)

Basic window manager, currently meant to be used with vulkan.

Currently supports
* Windows (win32) (todo)
* MacOS (cocoa)
* Linux (X11, Wayland)

### How to use
Add `window.c3l` file to your C3 project dependencies folder, and then link it in `project.json` 
with `"dependencies": ["c3w"]`


Running example:
Install [C3](https://c3-lang.org/), [VulkanSDK](https://vulkan.lunarg.com/sdk/home)
Then run example with `c3c run cube`

------
### Running with vulkan on macOS

Install [VulkanSDK](https://vulkan.lunarg.com/sdk/home#mac) and add vulkan lib file path as `rpath` to the run command.
Its the folder with `vulkan.1.dylib` file
````
c3c run cube -z -rpath -z /Users/my_user/VulkanSDK/macOS/lib
````

------
### Running vulkan on linux
Install [VulkanSDK](https://vulkan.lunarg.com/sdk/home#mac)

Choosing wayland or X11 can be done with feature tag inside C3 `project.json`
```
"features": ["WAYLAND"]
"features": ["X11"]
```
