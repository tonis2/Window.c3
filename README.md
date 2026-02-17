# Window.c3

A cross-platform window management library for [C3](https://c3-lang.org/), designed for use with Vulkan graphics applications.

### Supported Platforms

- Windows (Win32)
- macOS (Cocoa)
- Linux (Wayland, X11)

## Installation

1. Download the `window.c3l` file from releases
2. Place it in your project's dependency directory
3. Add it to your `project.json`:

```json
{
    "dependencies": ["c3w"]
}
```

### Linux Display Server

On Linux, select your display server by adding a feature flag in `project.json`:

```json
{
    "features": ["WAYLAND"]
}
```

or

```json
{
    "features": ["X11"]
}
```

## Quick Start

```c3
import c3w;

fn void main(String[] args)
{
    c3w::Window win = c3w::new(
        params: {
            .width = 900,
            .height = 600,
            .x = 0,
            .y = 0
        },
        name: "My Window"
    )!!;

    defer win.free();

    bool running = true;
    while (running) {
        c3w::EventMap event_map = win.getEvent();

        if (event_map.is_pressed(ESCAPE)) {
            running = false;
        }
    }
}
```

## API Reference

### `c3w::new`

Creates a new window.

```c3
fn Window? new(Params params, String name)
```

- `params` - Window position and size (`x`, `y`, `width`, `height`)
- `name` - Window title

Returns a `Window` or the fault `FAILED_OPENING_WINDOW`.

### `Window.getEvent`

Polls for window events and returns the current input state.

```c3
fn EventMap Window.getEvent(&self)
```

Returns an `EventMap` (a hashmap of pressed keys/buttons). Use `is_pressed()` to query it.

### `Window.getMousePos`

Returns the current mouse position relative to the window.

```c3
fn float[<2>] Window.getMousePos(self)
```

### `Window.free`

Releases window resources. Call when done with the window.

```c3
fn void Window.free(&self)
```

### `EventMap.is_pressed`

Checks if a key or mouse button is currently pressed.

```c3
fn bool EventMap.is_pressed(self, EventKey key)
```

### Event Types

The `EventType` enum indicates what kind of event occurred:

| Event | Description |
|---|---|
| `KEY_PRESSED` | A keyboard key was pressed |
| `KEY_RELEASED` | A keyboard key was released |
| `MOUSE_PRESSED` | A mouse button was pressed |
| `MOUSE_RELEASED` | A mouse button was released |
| `MOUSE_MOTION` | The mouse moved |
| `WINDOW_REFRESH` | The window needs redrawing |
| `QUIT` | The window was closed |

### Event Keys

The `EventKey` enum covers keyboard keys and mouse buttons:

- **Letters:** `A` - `Z`
- **Numbers:** `KEY_0` - `KEY_9`
- **Function keys:** `F1` - `F20`
- **Arrows:** `LEFT_ARROW`, `RIGHT_ARROW`, `UP_ARROW`, `DOWN_ARROW`
- **Modifiers:** `LEFT_SHIFT`, `RIGHT_SHIFT`, `LEFT_CTRL`, `RIGHT_CTRL`, `LEFT_ALT`, `RIGHT_ALT`, `LEFT_SUPER`, `RIGHT_SUPER`
- **Special:** `ESCAPE`, `RETURN`, `SPACE`, `TAB`, `BACKSPACE`, `DELETE`, `INSERT`, `CAPS_LOCK`
- **Navigation:** `HOME`, `END`, `PAGE_UP`, `PAGE_DOWN`
- **Mouse:** `LEFT_MOUSE`, `RIGHT_MOUSE`, `MIDDLE_MOUSE`, `MOUSE_SCROLL_UP`, `MOUSE_SCROLL_DOWN`

## Using with Vulkan on macOS

Install the [VulkanSDK](https://vulkan.lunarg.com/sdk/home#mac), then pass the Vulkan lib path as `rpath`:

```
c3c run cube -z -rpath -z /Users/my_user/VulkanSDK/macOS/lib
```

Use the path to the folder containing `vulkan.1.dylib`.
