module xcb;

enum XCB_Event : uint (uint value) {
    ATOM_NONE = 0,
    ATOM_ANY = 0,
    ATOM_PRIMARY = 1,
    ATOM_SECONDARY = 2,
    ATOM_ARC = 3,
    ATOM_ATOM = 4,
    ATOM_BITMAP = 5,
    ATOM_CARDINAL = 6,
    ATOM_COLORMAP = 7,
    ATOM_CURSOR = 8,
    ATOM_CUT_BUFFER0 = 9,
    ATOM_CUT_BUFFER1 = 10,
    ATOM_CUT_BUFFER2 = 11,
    ATOM_CUT_BUFFER3 = 12,
    ATOM_CUT_BUFFER4 = 13,
    ATOM_CUT_BUFFER5 = 14,
    ATOM_CUT_BUFFER6 = 15,
    ATOM_CUT_BUFFER7 = 16,
    ATOM_DRAWABLE = 17,
    ATOM_FONT = 18,
    ATOM_INTEGER = 19,
    ATOM_PIXMAP = 20,
    ATOM_POINT = 21,
    ATOM_RECTANGLE = 22,
    ATOM_RESOURCE_MANAGER = 23,
    ATOM_RGB_COLOR_MAP = 24,
    ATOM_RGB_BEST_MAP = 25,
    ATOM_RGB_BLUE_MAP = 26,
    ATOM_RGB_DEFAULT_MAP = 27,
    ATOM_RGB_GRAY_MAP = 28,
    ATOM_RGB_GREEN_MAP = 29,
    ATOM_RGB_RED_MAP = 30,
    ATOM_STRING = 31,
    ATOM_VISUALID = 32,
    ATOM_WINDOW = 33,
    ATOM_WM_COMMAND = 34,
    ATOM_WM_HINTS = 35,
    ATOM_WM_CLIENT_MACHINE = 36,
    ATOM_WM_ICON_NAME = 37,
    ATOM_WM_ICON_SIZE = 38,
    ATOM_WM_NAME = 39,
    ATOM_WM_NORMAL_HINTS = 40,
    ATOM_WM_SIZE_HINTS = 41,
    ATOM_WM_ZOOM_HINTS = 42,
    ATOM_MIN_SPACE = 43,
    ATOM_NORM_SPACE = 44,
    ATOM_MAX_SPACE = 45,
    ATOM_END_SPACE = 46,
    ATOM_SUPERSCRIPT_X = 47,
    ATOM_SUPERSCRIPT_Y = 48,
    ATOM_SUBSCRIPT_X = 49,
    ATOM_SUBSCRIPT_Y = 50,
    ATOM_UNDERLINE_POSITION = 51,
    ATOM_UNDERLINE_THICKNESS = 52,
    ATOM_STRIKEOUT_ASCENT = 53,
    ATOM_STRIKEOUT_DESCENT = 54,
    ATOM_ITALIC_ANGLE = 55,
    ATOM_X_HEIGHT = 56,
    ATOM_QUAD_WIDTH = 57,
    ATOM_WEIGHT = 58,
    ATOM_POINT_SIZE = 59,
    ATOM_RESOLUTION = 60,
    ATOM_COPYRIGHT = 61,
    ATOM_NOTICE = 62,
    ATOM_FONT_NAME = 63,
    ATOM_FAMILY_NAME = 64,
    ATOM_FULL_NAME = 65,
    ATOM_CAP_HEIGHT = 66,
    ATOM_WM_CLASS = 67,
    ATOM_WM_TRANSIENT_FOR = 68
}

distinct EventType = inline char;
const EventType EMPTY = 0;
const EventType KEY_PRESSED = 2;
const EventType KEY_RELEASED = 3;
const EventType MOUSE_PRESSED = 4;
const EventType MOUSE_RELEASED = 5;
// const EventType MOUSE_RELEASED = 6;
const EventType WINDOW_INIT = 12;
const EventType WINDOW_REFRESH = 16;
const EventType QUIT = 32;
const EventType DND = 33;
const EventType DND_INIT = 34;

struct Event
{
   EventType type;
   char value;
   short mouse_x;
   short mouse_y;
}

struct RawEvent {
    EventType type;  
    char pad0;      
    ushort sequence;  
    uint[7] pad;
    uint full_sequence;
}

struct KeyPressEvent {
    char type; 
    char value;
    short sequence;
    uint time;      
    uint  root;
    uint  event;
    uint  child;
    short root_x;
    short root_y;
    short event_x;
    short event_y;
    short state;
    char same_screen;
}

enum MouseButton : char (char value)
{
    NONE = 0,
    LEFT_MOUSE = 1,
    MIDDLE_MOUSE = 2,
    RIGHT_MOUSE = 3,
    MOUSE_SCROLL_UP = 4,
    MOUSE_SCROLL_DOWN = 5,
}

enum Key : char {
    KEY_NULL,
    ESCAPE,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,

    BACKTICK,

    KEY_0,
    KEY_1,
    KEY_2,
    KEY_3,
    KEY_4,
    KEY_5,
    KEY_6,
    KEY_7,
    KEY_8,
    KEY_9,

    MINUS,
    EQUAL,
    BACKSPACE,
    TAB,
    CAPSLOCK,
    SHIFT_R,
    CONTROL_L,
    ALT_L,
    SUPER_L,
    SHIFT_L,
    CONTROL_R,
    ALT_R,
    SUPER_R,
    SPACE,

    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
}