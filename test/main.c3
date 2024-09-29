import c3w;
import std;


fn void! main(String[] args)
{
    c3w::new(
        params: {
            .width = 500,
            .height = 500,
            .x = 0,
            .y = 0
        },
        name: "Cube"
    );
}