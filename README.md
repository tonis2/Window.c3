# Window.c3
Window manager for C3

#### Running with vulkan on macOS

Install VulkanSDK and add vulkan lib file path as `rpath` to the run command.
Its the folder with `vulkan.1.dylib` file
````
c3c run cube -z -rpath -z /Users/my_user/VulkanSDK/macOS/lib
````

#### On linux
Choosing wayland or X11 can be done with feature tag to c3
```
"features": ["WAYLAND"]
"features": ["X11"]
```