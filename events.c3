module xcb;

distinct EventType = inline char;
const EventType EMPTY_EVENT = 0;
const EventType KEY_PRESSED = 2;
const EventType KEY_RELEASED = 3;
const EventType MOUSE_PRESSED = 4;
const EventType MOUSE_RELEASED = 5;
const EventType MOUSE_MOTION = 6;

const EventType WINDOW_INIT = 12;
const EventType WINDOW_REFRESH = 16;
const EventType QUIT = 32;
const EventType DND = 33;
const EventType DND_INIT = 34;

distinct Key = inline char;
const Key EMPTY_KEY = 0;
const Key ESCAPE = 9;

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




// enum Key : char {
//     KEY_NULL,
//     ESCAPE,
//     F1,
//     F2,
//     F3,
//     F4,
//     F5,
//     F6,
//     F7,
//     F8,
//     F9,
//     F10,
//     F11,
//     F12,

//     BACKTICK,

//     KEY_0,
//     KEY_1,
//     KEY_2,
//     KEY_3,
//     KEY_4,
//     KEY_5,
//     KEY_6,
//     KEY_7,
//     KEY_8,
//     KEY_9,

//     MINUS,
//     EQUAL,
//     BACKSPACE,
//     TAB,
//     CAPSLOCK,
//     SHIFT_R,
//     CONTROL_L,
//     ALT_L,
//     SUPER_L,
//     SHIFT_L,
//     CONTROL_R,
//     ALT_R,
//     SUPER_R,
//     SPACE,

//     A,
//     B,
//     C,
//     D,
//     E,
//     F,
//     G,
//     H,
//     I,
//     J,
//     K,
//     L,
//     M,
//     N,
//     O,
//     P,
//     Q,
//     R,
//     S,
//     T,
//     U,
//     V,
//     W,
//     X,
//     Y,
//     Z,
// }