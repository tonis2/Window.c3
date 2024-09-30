import c3w;
import std;


fn void! main(String[] args)
{
    c3w::Window win = c3w::new(
        params: {
            .width = 900,
            .height = 600,
            .x = 0,
            .y = 0
        },
        name: "Cube"
    );
    defer win.free();
}