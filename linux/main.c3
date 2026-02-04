module c3w;

// Convert Linux/X11 scancode to unified EventKey
// Linux scancodes are evdev codes + 8
fn EventKey linuxScancodeToEventKey(uint scancode) {
    switch (scancode) {
        // Special keys
        case 9: return ESCAPE;
        case 36: return RETURN;
        case 65: return SPACE;
        case 119: return DELETE;
        case 23: return TAB;
        case 22: return BACKSPACE;
        case 118: return INSERT;
        case 66: return CAPS_LOCK;
        // Modifier keys
        case 50: return LEFT_SHIFT;
        case 62: return RIGHT_SHIFT;
        case 37: return LEFT_CTRL;
        case 105: return RIGHT_CTRL;
        case 64: return LEFT_ALT;
        case 108: return RIGHT_ALT;
        case 133: return LEFT_SUPER;
        case 134: return RIGHT_SUPER;
        case 135: return MENU;
        // Number row
        case 19: return KEY_0;
        case 10: return KEY_1;
        case 11: return KEY_2;
        case 12: return KEY_3;
        case 13: return KEY_4;
        case 14: return KEY_5;
        case 15: return KEY_6;
        case 16: return KEY_7;
        case 17: return KEY_8;
        case 18: return KEY_9;
        // Letters (QWERTY layout)
        case 38: return A;
        case 56: return B;
        case 54: return C;
        case 40: return D;
        case 26: return E;
        case 41: return F;
        case 42: return G;
        case 43: return H;
        case 31: return I;
        case 44: return J;
        case 45: return K;
        case 46: return L;
        case 58: return M;
        case 57: return N;
        case 32: return O;
        case 33: return P;
        case 24: return Q;
        case 27: return R;
        case 39: return S;
        case 28: return T;
        case 30: return U;
        case 55: return V;
        case 25: return W;
        case 53: return X;
        case 29: return Y;
        case 52: return Z;
        // Arrow keys
        case 113: return LEFT_ARROW;
        case 114: return RIGHT_ARROW;
        case 111: return UP_ARROW;
        case 116: return DOWN_ARROW;
        // Numpad
        case 77: return NUMLOCK;
        case 90: return NUM_0;
        case 87: return NUM_1;
        case 88: return NUM_2;
        case 89: return NUM_3;
        case 83: return NUM_4;
        case 84: return NUM_5;
        case 85: return NUM_6;
        case 79: return NUM_7;
        case 80: return NUM_8;
        case 81: return NUM_9;
        case 104: return KP_RETURN;
        case 86: return KP_ADD;
        case 82: return KP_SUBTRACT;
        case 63: return KP_MULTIPLY;
        case 106: return KP_DIVIDE;
        case 91: return KP_DECIMAL;
        // Function keys
        case 67: return F1;
        case 68: return F2;
        case 69: return F3;
        case 70: return F4;
        case 71: return F5;
        case 72: return F6;
        case 73: return F7;
        case 74: return F8;
        case 75: return F9;
        case 76: return F10;
        case 95: return F11;
        case 96: return F12;
        case 191: return F13;
        case 192: return F14;
        case 193: return F15;
        case 194: return F16;
        case 195: return F17;
        case 196: return F18;
        case 197: return F19;
        case 198: return F20;
        // Navigation
        case 110: return HOME;
        case 115: return END;
        case 112: return PAGE_UP;
        case 117: return PAGE_DOWN;
        // Punctuation and symbols
        case 20: return MINUS;
        case 21: return EQUALS;
        case 34: return LEFT_BRACKET;
        case 35: return RIGHT_BRACKET;
        case 51: return BACKSLASH;
        case 47: return SEMICOLON;
        case 48: return APOSTROPHE;
        case 49: return GRAVE;
        case 59: return COMMA;
        case 60: return PERIOD_KEY;
        case 61: return SLASH_KEY;
        // Lock keys
        case 78: return SCROLL_LOCK;
        case 127: return PAUSE;
        case 107: return PRINT_SCREEN;
        default: return EMPTY_KEY;
    }
}
