module example;

import c3w;

c3w::Window win;

fn void init() @export("init")
{
	win = c3w::new(
		params: { .width = 900, .height = 600, .x = 0, .y = 0 },
		name: "Window"
	)!!;
}

fn void frame() @export("frame")
{
	c3w::EventMap event_map = win.getEvent();
}
