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


LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch(msg)
    {
        case WM_CLOSE:
            DestroyWindow(hwnd);
        break;
        case WM_DESTROY:
            PostQuitMessage(0);
        break;
        default:
            return DefWindowProc(hwnd, msg, wParam, lParam);
    }
    return 0;
}

int APIENTRY WinMain(HINSTANCE hInst, HINSTANCE hInstPrev, PSTR cmdline, int cmdshow)
{
    return MessageBox(NULL, "hello, world", "caption", 0);
}