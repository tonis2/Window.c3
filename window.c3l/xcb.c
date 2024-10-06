#include <X11/Xlib-xcb.h>
#include <X11/Xlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <xcb/xproto.h>

typedef struct Size
{
    uint32_t width;
    uint32_t height;
} Size;

typedef struct WindowSrc
{
    Display *dpy;
    xcb_connection_t *connection;
    xcb_window_t window;
} WindowSrc;

typedef struct Window_Result
{
    WindowSrc src;
    Size screen_info;
} Window_Result;

typedef struct Window_Params
{
    int depth;
    int x;
    int y;
    int width;
    int height;
    int border_width;
} Window_Params;

typedef struct MouseParams
{
    uint8_t type;
    uint16_t x;
    uint16_t y;
    uint16_t root_x;
    uint16_t root_y;
} MouseParams;

void destroy(Window_Result window)
{
    xcb_destroy_window(window.src.connection, window.src.window);
    xcb_disconnect(window.src.connection);
}

void changeWindowName(Window_Result window, const char *name)
{
    xcb_change_property(window.src.connection, XCB_PROP_MODE_REPLACE, window.src.window, XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8, sizeof(name), name);
}

xcb_button_press_event_t *getEvent(Window_Result window)
{
    xcb_button_press_event_t *event = (xcb_button_press_event_t *)xcb_poll_for_event(window.src.connection);
    return event;
}

MouseParams getMousePos(Window_Result window)
{
    xcb_query_pointer_cookie_t cookie = xcb_query_pointer(window.src.connection, window.src.window);
    xcb_generic_error_t *err;
    xcb_query_pointer_reply_t *response = xcb_query_pointer_reply(window.src.connection, cookie, &err);

    MouseParams params = {
        response->response_type,
        response->win_x,
        response->win_y,
        response->root_x,
        response->root_y};
    free(response);
    free(err);
    return params;
}

Window_Result createWindow(Window_Params params)
{
    // XCB_Window xcb_window;
    Display *dpy = XOpenDisplay(NULL);

    if (!dpy)
    {
        fprintf(stderr, "Could not open display.\n");
        exit(EXIT_FAILURE);
    }

    /* Now that we have an open Display object, cast it to an
     * XCBConnection object so it can be used with native XCB
     * functions.
     */
    xcb_connection_t *connection = XGetXCBConnection(dpy);

    if (!connection)
    {
        fprintf(stderr, "Could not cast the Display object to an "
                        "XCBConnection object.\n");
        exit(EXIT_FAILURE);
    }

    /* Do something meaningful, fun, and interesting with the new
     * XCBConnection object.
     */
    const xcb_setup_t *setup = xcb_get_setup(connection);
    xcb_screen_t *screen = (xcb_setup_roots_iterator(setup)).data;
    xcb_window_t window = xcb_generate_id(connection);

    xcb_cw_t mask = XCB_CW_EVENT_MASK;
    xcb_event_mask_t event_masks[] = {XCB_EVENT_MASK_EXPOSURE | XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE | XCB_EVENT_MASK_KEY_PRESS | XCB_EVENT_MASK_KEY_RELEASE | XCB_EVENT_MASK_STRUCTURE_NOTIFY};

    xcb_void_cookie_t cookie = xcb_create_window(
        connection,
        params.depth,
        window,
        screen->root,
        params.x, params.y,
        params.width,
        params.height,
        params.border_width,
        InputOutput,
        screen->root_visual,
        mask, event_masks);

    xcb_map_window(connection, window);
    xcb_flush(connection);

    // xcb_get_keyboard_mapping_reply_t *keyboard_mapping =
    //     xcb_get_keyboard_mapping_reply(
    //         connection,
    //         xcb_get_keyboard_mapping(
    //             connection,
    //             setup->min_keycode,
    //             setup->max_keycode - setup->min_keycode + 1),
    //         NULL);

    // xcb_keysym_t* keysyms  = (xcb_keysym_t*)(keyboard_mapping + 1);
    // int nkeycodes = keyboard_mapping->length / keyboard_mapping->keysyms_per_keycode;
    // for(int keycode_idx=0; keycode_idx < nkeycodes; ++keycode_idx) {
    //     printf("keycode %3u ", setup->min_keycode + keycode_idx);
    //     for(int keysym_idx=0; keysym_idx < keyboard_mapping->keysyms_per_keycode; ++keysym_idx){
    //         printf(" %8x", keysyms[keysym_idx + keycode_idx * keyboard_mapping->keysyms_per_keycode]);
    //     }
    //     putchar('\n');
    // }

    // free(keyboard_mapping);
    // printf("root: %d\n", cookie.sequence);
    // printf("Connection: %p\n", connection);
    // printf("Window: %d\n", window);

    Window_Result result = {
        {dpy,
         connection,
         window},
        {screen->width_in_pixels,
         screen->height_in_pixels}};

    return result;
}