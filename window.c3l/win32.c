#include <windows.h>
#include <stdlib.h>
#include <stdint.h>

typedef struct Size {
    uint32_t width;
    uint32_t height;
} Size;

typedef struct Window_Result {
    HWND window;
    Size screen_info;
} Window_Result;


const char g_szClassName[] = "myWindowClass";

LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
  if (message == WM_CLOSE && hwnd == window) return OnWindowClose(hwnd, message, wParam, lParam);
  if (message == WM_SIZE && hwnd == window) return OnWindowResize(hwnd, message, wParam, lParam);
  if (message == WM_PAINT && hwnd == window) return OnWindowPaint(hwnd, message, wParam, lParam);
  return CallWindowProc(defWndProc, hwnd, message, wParam, lParam);
}

LRESULT OnWindowClose(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
  PostQuitMessage(0);
  return CallWindowProc(defWndProc, hwnd, message, wParam, lParam);
}

LRESULT OnWindowResize(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam) {
  LRESULT result = CallWindowProc(defWndProc, hwnd, message, wParam, lParam);
  RECT rect;
  GetClientRect(hwnd, &rect);
  InvalidateRect(hwnd, &rect, false);
  return result;
}

Window_Result APIENTRY createWindow(HINSTANCE hInst, HINSTANCE hInstPrev, PSTR cmdline, int cmdshow)
{
    HWND window = CreateWindowEx(0, WC_DIALOG, L"Hello world (Paint)", WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 316, 340, nullptr, nullptr, nullptr, nullptr);
    WNDPROC defWndProc = nullptr;
    defWndProc = (WNDPROC)SetWindowLongPtr(window, GWLP_WNDPROC, (LONG_PTR)WndProc);
    ShowWindow(window, SW_SHOW);

//     MSG message = { 0 };
//   while (GetMessage(&message, nullptr, 0, 0))
//     DispatchMessage(&message);
//   return (int)message.wParam;
}