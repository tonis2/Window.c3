module c3w @if(env::LINUX && $feature(WAYLAND)) @link("wayland-client");
import std::math;
import vk;
import std::io;
import std::core::types;

struct Message {
	 char* name;
	 char* signature;
	 Interface*[]* types;
}

Interface wl_output_interface;
Interface wl_seat_interface;
Interface xdg_popup_interface;
Interface xdg_positioner_interface;
Interface xdg_toplevel_interface;


Interface*[] create_positioner = { &xdg_positioner_interface };
Interface*[] get_xdg_surface = { &xdg_surface_interface, &wl_surface_interface };

Interface wm_base_interface = {
    .name = "xdg_wm_base",
    .version = 6,
    .method_count = 4,
    .methods = &&Message[*]{
        { "destroy", "", null },
        { "create_positioner", "n", &create_positioner },
        { "get_xdg_surface", "no", &get_xdg_surface },
        { "pong", "u", null },
    },
    .event_count = 1,
    .events = &&Message[*]{
        { "ping", "", null },
    },
};

Interface*[] get_toplevel = { &xdg_toplevel_interface };
Interface*[] get_popup = { &xdg_popup_interface, null, &xdg_positioner_interface };

Interface xdg_surface_interface = {
    .name = "xdg_surface",
    .version = 6,
    .method_count = 5,
    .methods = &&Message[*]{
        { "destroy", "", null },
        { "get_toplevel", "n", &get_toplevel },
        { "get_popup", "n?oo", &get_popup },
        { "set_window_geometry", "iii", null },
        { "ack_configure", "u", null },
    },
    .event_count = 1,
    .events = &&Message[*]{
        { "configure", "u", null },
    },
};