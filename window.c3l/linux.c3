module c3w @if(env::LINUX || env::DARWIN);
import std::math;
import vk;
import std::io;

extern fn Window createWindow(Params params) @extern("createWindow");
extern fn void destroy(Window window) @extern("destroy");
extern fn void changeWindowName(Window window, ZString name) @extern("changeWindowName");
extern fn MouseParams getMousePos(Window window) @extern("getMousePos");
extern fn KeyPressEvent* getEvent(Window window) @extern("getEvent");

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

// Creates new XCB window
fn Window new(Params params, String name) {
    Window window = createWindow(params);
    changeWindowName(window, (ZString)name);
    return window;
}

fn Event Window.getEvent(&self) {
   KeyPressEvent* event = getEvent(*self);
   defer free(event);
   Event event_response = Event {.type = 0, .mouse_click = self.mouse_click};

   if (event != null) {
        EventType type = (EventType)event.type;
        switch (type) {
            case MOUSE_MOTION: {}
            case MOUSE_PRESSED: {  
                event_response = Event{
                    .type = (EventType)event.type, 
                    .value = event.value,
                    .mouse_x = event.event_x,
                    .mouse_y = event.event_y,
                };

                if ((MouseButton)event.value == LEFT_MOUSE) {
                    self.mouse_click = (MouseButton)1;
                }

                if ((MouseButton)event.value == RIGHT_MOUSE) {
                    self.mouse_click = (MouseButton)3;
                }
            }
            case MOUSE_RELEASED: {  
                event_response = Event{
                    .type = (EventType)event.type, 
                    .value = event.value,
                    .mouse_x = event.event_x,
                    .mouse_y = event.event_y,
                };

                if ((MouseButton)event.value == LEFT_MOUSE || (MouseButton)event.value == RIGHT_MOUSE) {
                    self.mouse_click = (MouseButton)0;
                }
                break;
            }
            case KEY_PRESSED:
            case KEY_RELEASED: {
                KeyPressEvent* key_event = (KeyPressEvent*)event;
                event_response = Event{ .type = (EventType)event.type, .value = key_event.value};
                break;
            }
            default: {};
        }
    }

    return event_response;
}

// Free and destroys window instance
fn void Window.free(self) {
    destroy(self);
}