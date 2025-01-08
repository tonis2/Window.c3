#include <windows.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

typedef struct Size
{
  uint32_t width;
  uint32_t height;
} Size;

typedef struct Event
{
  char type;
  char value;
  short mouse_x;
  short mouse_y;
  char mouse_btn;
} Event;

typedef struct WindowSrc
{
  HWND window;
  HINSTANCE instance;
  HDC device;
} WindowSrc;

typedef struct Window_Result {
    WindowSrc src;
    Size screen_info;
} Window_Result;

typedef struct Window_Params {
    int x;
    int y;
    int width;
    int height;
} Window_Params;

typedef struct MouseParams {
    uint8_t type;
    uint16_t x;
    uint16_t y;
    uint16_t root_x;
    uint16_t root_y;
} MouseParams;

char ready = 0;

LRESULT CALLBACK platform_window_callback(HWND window, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
      case WS_VISIBLE: {}
      case WM_SIZE:
      {
        RECT rect = {0};
        GetClientRect(window, &rect);
        // input->screenSize.x = (rect.right - rect.left);
        // input->screenSize.y = (rect.bottom - rect.top);
        break;
      }
      case WM_CLOSE:
            // running = false;
            break;
      }

    return DefWindowProcA(window, msg, wParam, lParam);
}

Event getEvent(Window_Result window) {
  Event event = {0};
  MSG message;
  if (GetMessage(&message, window.src.window, NULL, NULL) > 0) {
      TranslateMessage(&message);
      DispatchMessage(&message);
      ScreenToClient(window.src.window, &message.pt);
      event.type = message.message;
      event.value = message.wParam;
      event.mouse_x = message.pt.x;
      event.mouse_y = message.pt.y;
  }
  return event;
}

MouseParams getMousePos(Window_Result window)
{
    POINT point = {0};
    GetCursorPos(&point);
    ScreenToClient(window.src.window, &point);

    MouseParams params = {point.x, point.y};
    return params;
}

 void destroy(Window_Result window) {
    ReleaseDC(window.src.window, window.src.device);
    DestroyWindow(window.src.window);
}

Window_Result createWindow(Window_Params params)
{
    char* szWindowClass = "win32app";
    WNDCLASSEXA wc = {0};
    HWND window;
    MSG msg;
    HINSTANCE instance = {0};
    HDC device;

     // make sure all the members are zero-ed out to start
    wc.cbSize        = sizeof(wc);
    wc.style         = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc   = platform_window_callback;
    wc.hInstance     = instance;
    wc.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
    wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground  = (HBRUSH)(COLOR_WINDOW+1);
    wc.lpszClassName = szWindowClass;


  if (!RegisterClassEx((const WNDCLASSEXA*)&wc))
  {
      fprintf(stderr, "Could not register class.\n");
      exit(EXIT_FAILURE);
  }

  uint32_t windowStyle = WS_THICKFRAME | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_OVERLAPPED;

   window = CreateWindow(
        szWindowClass,
        wc.lpszClassName,
        WS_OVERLAPPEDWINDOW,
        params.x, params.y,
        params.width, params.height,
        NULL,
        NULL,
        instance,
        NULL
    );

    PIXELFORMATDESCRIPTOR pfd = {
        .nVersion = 1,
        .iPixelType = PFD_TYPE_RGBA,
        .dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
        .cColorBits = 32,
        .cAlphaBits = 8,
        .iLayerType = PFD_MAIN_PLANE,
        .cDepthBits = 24,
        .cStencilBits = 8,
    };

    if (window == 0)
    {
        fprintf(stderr, "Could not open display.\n");
        exit(EXIT_FAILURE);
    }

    device = GetDC(window);

    ShowWindow(window, SW_SHOW);
    UpdateWindow(window);
    
    Window_Result result = {
        {
          window,
          instance,
        },
        {
          100,
          100
        },
    };
    return result;
}
