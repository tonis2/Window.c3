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

    // case WM_DROPFILES:
    // {
    //     HDROP drop = (HDROP)wParam;

    //     uint32_t fileCount = DragQueryFileA(drop, INVALID_IDX, 0, 0);

    //     for (uint32_t i = 0; i < fileCount; i++)
    //     {
    //         uint32_t fileNameLength = DragQueryFileA(drop, i, 0, 0);

    //         char filePath[500] = {};

    //         DragQueryFileA(drop, i, filePath, fileNameLength + 1);

    //         // Convert File to DDS and copy into Assets folder
    //         {
    //             char command[300] = {};

    //             sprintf(command, "lib\\texconv.exe -y -m 1 -f R8G8B8A8_UNORM \"%s\" -o assets/textures",
    //                     filePath);

    //             CAKEZ_ASSERT(!system(command), "Failed to import Asset: %s", filePath);
    //         }
    //     }
    // }
    // break;

    // case WM_KEYDOWN:
    // case WM_KEYUP:
    // {
    //     bool isDown = msg == WM_KEYDOWN ? true : false;
    //     uint32_t keyID = INVALID_IDX;

    //     switch ((int)wParam)
    //     {
    //     case 'A':
    //         keyID = KEY_A;
    //         break;

    //     case 'D':
    //         keyID = KEY_D;
    //         break;

    //     case 'S':
    //         keyID = KEY_S;
    //         break;

    //     case 'W':
    //         keyID = KEY_W;
    //         break;

    //     case VK_ESCAPE:
    //         keyID = KEY_ESC;
    //         break;
    //     }

    //     if (keyID < KEY_COUNT)
    //     {
    //         // if (input.keys[keyID].isDown != isDown)
    //         // {
    //         input.keys[keyID].halfTransitionCount++;
    //         input.keys[keyID].isDown = isDown;
    //         // }
    //     }
    // }
    // break;

    // case WM_MOUSEMOVE:
    //     input.mousePos = input.mousePos;
    //     input.mousePos = {(float)GET_X_LPARAM(lParam),
    //                       (float)GET_Y_LPARAM(lParam)};
    //     break;

    // case WM_LBUTTONDOWN:
    // case WM_MBUTTONDOWN:
    // case WM_RBUTTONDOWN:
    // case WM_LBUTTONUP:
    // case WM_MBUTTONUP:
    // case WM_RBUTTONUP:
    // {
    //     bool isDown = msg == WM_LBUTTONDOWN || msg == WM_RBUTTONDOWN || msg == WM_MBUTTONDOWN
    //                       ? true
    //                       : false;

    //     KeyID keyID = (msg == WM_LBUTTONDOWN || msg == WM_LBUTTONUP)
    //                       ? KEY_LEFT_MOUSE
    //                   : (msg == WM_MBUTTONDOWN || msg == WM_MBUTTONUP)
    //                       ? KEY_MIDDLE_MOUSE
    //                       : KEY_RIGHT_MOUSE;

    //     input.keys[keyID].halfTransitionCount++;
    //     input.keys[keyID].isDown = isDown;

    //     input.mouseClickPos = {(float)GET_X_LPARAM(lParam),
    //                            (float)GET_Y_LPARAM(lParam)};

    //     break;
    // }

    case WM_CLOSE:
        // running = false;
        break;
    }

    return DefWindowProcA(window, msg, wParam, lParam);
}

Window_Result createWindow(Window_Params params)
{
  HWND window;
  // HANDLE dc = GetDC(window);

  HINSTANCE instance = GetModuleHandleA(0);

  WNDCLASS wc;
  wc.lpfnWndProc = platform_window_callback;
  wc.hInstance = instance;
  wc.lpszClassName = "vulkan_engine_class";

  if (!RegisterClassA(&wc))
  {
      fprintf(stderr, "Could not register class.\n");
      exit(EXIT_FAILURE);
  }

   uint32_t windowStyle = WS_THICKFRAME | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_OVERLAPPED;

    window = CreateWindowExA(
    WS_EX_APPWINDOW,
    "vulkan_engine_class",
    "Pong",
    windowStyle,
    params.width, params.height, params.x, params.y, 0, 0, instance, 0);

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
