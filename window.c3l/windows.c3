module c3w @if(env::WIN32);
import std::math;
import std::os::win32;
import vk;
import std::io;

const CS_VREDRAW = 0x0001;
const CS_HREDRAW = 0x0002;
const CS_DBLCLKS = 0x0008;
const CS_OWNDC = 0x0020;
const CS_CLASSDC = 0x0040;
const CS_PARENTDC = 0x0080;
const CS_NOCLOSE  = 0x0200;
const CS_SAVEBITS  = 0x0800;
const CS_BYTEALIGNCLIENT = 0x1000;
const CS_BYTEALIGNWINDOW = 0x2000;
const CS_GLOBALCLASS = 0x4000;

const Win32_DWORD WS_VISIBLE = 0x10000000L;
const Win32_DWORD WS_VSCROLL = 0x00200000L;
const Win32_DWORD WM_CLOSE = 0x0010;
const Win32_DWORD WM_QUIT = 0x0012;

const Win32_LPCWSTR IDC_ARROW = (Win32_LPCWSTR)32512;
const Win32_LPCWSTR IDI_APPLICATION = (Win32_LPCWSTR)32512;

extern fn Win32_HWND createWindow(Win32_WNDCLASSEXW window) @extern("CreateWindow");

fn Win32_LRESULT platform_window_callback(Win32_HWND window, Win32_UINT msg, Win32_WPARAM wParam, Win32_LPARAM lParam)
{
    switch (msg)
    {
      case WS_VISIBLE: {}
      // case WM_SIZE:
      // {
      //   // RECT rect = {0};
      //   // GetClientRect(window, &rect);
      //   // input->screenSize.x = (rect.right - rect.left);
      //   // input->screenSize.y = (rect.bottom - rect.top);
      //   break;
      // }
      case WM_CLOSE:
            // running = false;
            break;
      }

    return win32::defWindowProcW(window, msg, wParam, lParam);
}

fn Window new(Params params) {
    Win32_HINSTANCE instance;
    WString className = "win32app".to_wstring(allocator::heap())!!;
    Win32_WNDCLASSEXW win = {
        .cbSize = Win32_WNDCLASSEXW.sizeof,
        .style = CS_HREDRAW | CS_VREDRAW,
        .hInstance = instance,
        .hbrBackground  = (Win32_HBRUSH)(5),
        .lpszClassName = className
    };
    
    win32::registerClassExW(&win);

    Win32_HWND hwnd = win32::createWindowExW(
        0,
        className,
        className,
        win32::WS_OVERLAPPEDWINDOW,
        0, 0, 500, 500,
        null,        
        null,
        instance,
        null
    );

    if (hwnd == null)
    {
        io::printfn("window error");
    }

    Window response = Window {
        .src = Win32Window {
            .window = hwnd,
            .instance = instance,
        },
        .width = 0,
        .height = 0
    };

    return response;
}

// struct Win32Window {
//     vk::Hwnd window;
//     vk::Hinstance instance;
//     Win32_HDC hdc;
// }

// fn void Window.free(self) {
//   destroy(self);
// }