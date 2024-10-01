#include <windows.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

typedef struct Size
{
  uint32_t width;
  uint32_t height;
} Size;

typedef struct WindowSrc
{
  HWND window;
  HINSTANCE instance;
} WindowSrc;

typedef struct Window_Result {
    WindowSrc src;
    Size screen_info;
} Window_Result;

typedef struct Window_Params {
    int depth;
    int x;
    int y;
    int width;
    int height;
    int border_width;
} Window_Params;

LRESULT CALLBACK platform_window_callback(HWND window, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {

    case WM_CLOSE:
        // running = false;
        break;
    }

    return DefWindowProcA(window, msg, wParam, lParam);
}



Window_Result createWindow(Window_Params params)
{
    char* szWindowClass = "win32app";
    WNDCLASSEXA wc = {0};
    HWND window;
    MSG     msg;
    HINSTANCE instance = {0};
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
        "Window title",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        params.height, params.width,
        NULL,
        NULL,
        instance,
        NULL
    );

    if (window == 0)
    {
        fprintf(stderr, "Could not open display.\n");
        exit(EXIT_FAILURE);
    }

    ShowWindow(window, SW_SHOW);

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
