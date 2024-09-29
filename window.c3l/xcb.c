#include <X11/Xlib-xcb.h>
#include <X11/Xlib.h>
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <xcb/xproto.h>

typedef struct Size {
    uint32_t width;
    uint32_t height;
} Size;

typedef struct Window_Result {
    Display* dpy;
    xcb_connection_t* connection;
    xcb_window_t window;
    uint32_t padding;
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

typedef struct MouseParams {
    uint8_t type;
    uint16_t x;
    uint16_t y;
    uint16_t root_x;
    uint16_t root_y;
} MouseParams;

void destroy(Window_Result window) {
    xcb_destroy_window( window.connection, window.window );
    xcb_disconnect(window.connection);
}

void changeWindowName(Window_Result window, const char* name) {
    xcb_change_property(window.connection, XCB_PROP_MODE_REPLACE, window.window, XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8, sizeof(name), name);
}

xcb_generic_event_t* getEvent(Window_Result window) {
   return xcb_poll_for_event(window.connection);
}

MouseParams getMousePos(Window_Result window) {
   xcb_query_pointer_cookie_t cookie = xcb_query_pointer(window.connection, window.window);
   xcb_generic_error_t* err;
   xcb_query_pointer_reply_t* response = xcb_query_pointer_reply(window.connection, cookie, &err);

   MouseParams params = {
        response->response_type,
        response->win_x,
        response->win_y,
        response->root_x,
        response->root_y
   };
   free(response);
   free(err);
   return params;
}

Window_Result createWindow(Window_Params params) {
    // XCB_Window xcb_window;
    Display* dpy = XOpenDisplay(NULL);

    if (!dpy)
    {
        fprintf(stderr, "Could not open display.\n");
        exit(EXIT_FAILURE);
    }

    /* Now that we have an open Display object, cast it to an
     * XCBConnection object so it can be used with native XCB
     * functions.
     */
    xcb_connection_t* connection = XGetXCBConnection(dpy);

    if (!connection)
    {
        fprintf(stderr, "Could not cast the Display object to an "
                        "XCBConnection object.\n");
        exit(EXIT_FAILURE);
    }

    /* Do something meaningful, fun, and interesting with the new
     * XCBConnection object.
     */
    const xcb_setup_t* setup = xcb_get_setup (connection);
    xcb_screen_t* screen = (xcb_setup_roots_iterator (setup)).data;
    xcb_window_t window = xcb_generate_id (connection);

    xcb_cw_t mask = XCB_CW_EVENT_MASK;
    xcb_event_mask_t event_masks[] = {XCB_EVENT_MASK_EXPOSURE | XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE | XCB_EVENT_MASK_KEY_PRESS | XCB_EVENT_MASK_KEY_RELEASE | XCB_EVENT_MASK_STRUCTURE_NOTIFY};

    xcb_void_cookie_t cookie = xcb_create_window (
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
    xcb_map_window (connection, window);
    xcb_flush (connection);

    // printf("root: %d\n", cookie.sequence);
    // printf("Connection: %p\n", connection);
    // printf("Window: %d\n", window);

    Size screen_info = {
        screen -> width_in_pixels,
        screen -> height_in_pixels
    };
    
    Window_Result result = {
        dpy,
        connection,
        window,
        0,
        screen_info
    };
    return result;
}