import c3w;
import std;

fn void main(String[] args)
{
    c3w::Window win = c3w::new(
        params: {
            .width = 900,
            .height = 600,
            .x = 0,
            .y = 0
        },
        name: "Window"
    )!!;

    defer win.free();
    
    bool running = true;
    while (running) {

        c3w::EventMap event_map = win.getEvent();

        if (event_map.is_pressed(ESCAPE)) {
             running = false;
        }
    }    
}