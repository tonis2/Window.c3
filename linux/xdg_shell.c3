module c3w @if(env::LINUX && $feature ( WAYLAND )) @link("wayland-client");
import std::math;
import std::io;
import std::core::types;

alias XDG_surface = void*;
alias XDG_top_level = void*;

alias ShellSurfaceEvent = fn void(
	LinuxWindow* data,
	XDG_surface shell_surface,
	uint serial
);

alias TopSurfaceEvent = fn void(
	LinuxWindow* data,
	XDG_top_level top_level,
	int width,
	int height,
	void* states
);
alias TopSurfaceClose = fn void(LinuxWindow* data, XDG_top_level top_level);
alias TopSurfaceConfigureBounds = fn void(
	LinuxWindow* data,
	XDG_top_level top_level,
	int width,
	int height
);
alias TopSurfaceCapabilities = fn void(
	LinuxWindow* data,
	XDG_top_level top_level,
	void* capabilities
);

struct ShellSurfaceListener
{
	ShellSurfaceEvent configure;
}

struct TopSurfaceListener
{
	TopSurfaceEvent configure;
	TopSurfaceClose close;
	TopSurfaceConfigureBounds bounds;
	TopSurfaceCapabilities capabilities;
}

struct Message
{
	char* name;
	char* signature;
	Interface*[]* types;
}

Interface*[] create_positioner = { &xdg_positioner_interface };
Interface*[] get_xdg_surface = {
	&xdg_surface_interface,
	&wl_surface_interface
};
Interface*[] get_toplevel = { &xdg_toplevel_interface };
Interface*[] get_popup = {
	&xdg_popup_interface,
	&wl_surface_interface,
	&xdg_positioner_interface
};
Interface*[] set_parent = { &xdg_toplevel_interface };
Interface*[] show_window_menu = { &wl_seat_interface, null, null, null };
Interface*[] move = { &wl_seat_interface, null };
Interface*[] resize_edge = { &wl_seat_interface, null, null };
Interface*[] set_fullscreen = { &wl_output_interface };

Interface*[] grab = { &wl_seat_interface, null };

Message[*] base_methods = {
	{ "destroy", "", null },
	{ "create_positioner", "n", &create_positioner },
	{ "get_xdg_surface", "no", &get_xdg_surface },
	{ "pong", "u", null },
};

Message[*] base_events = { { "ping", "", null }, };

Interface xdg_wm_base_interface = {
	.name = "xdg_wm_base",
	.version = 6,
	.method_count = base_methods.len,
	.methods = &base_methods,
	.event_count = base_events.len,
	.events = &base_events
};

Message[*] surface_events = { { "configure", "u", null }, };

Message[*] surface_method = {
	{ "destroy", "", null },
	{ "get_toplevel", "n", &get_toplevel },
	{ "get_popup", "n?oo", &get_popup },
	{ "set_window_geometry", "iiii", null },
	{ "ack_configure", "u", null },
};

Interface xdg_surface_interface = {
	.name = "xdg_surface",
	.version = 6,
	.method_count = surface_method.len,
	.methods = &surface_method,
	.event_count = surface_events.len,
	.events = &surface_events
};

Message[*] popup_methods = {
	{ "destroy", "", null },
	{ "grab", "oi", &grab },
	{ "repositioned", "u", null },
};

Message[*] popup_events = {
	{ "configure", "iiii", null },
	{ "popup_done", "", null },
};

Interface xdg_popup_interface = {
	.name = "xdg_popup",
	.version = 6,
	.method_count = popup_methods.len,
	.methods = &popup_methods,
	.event_count = popup_events.len,
	.events = &popup_events,
};


Message[*] top_methods = {
	{ "destroy", "", null },
	{ "set_parent", "?o", &set_parent },
	{ "set_title", "s", null },
	{ "set_app_id", "s", null },
	{ "show_window_menu", "ouii", &show_window_menu },
	{ "move", "ou", &move },
	{ "resize_edge", "ouu", &resize_edge },
	{ "set_max_size", "ii", null },
	{ "set_min_size", "ii", null },
	{ "set_maximized", "", null },
	{ "unset_maximized", "", null },
	{ "set_fullscreen", "?o", &set_fullscreen },
	{ "unset_fullscreen", "", null },
	{ "set_minimized", "", null },
};

Message[*] top_events = {
	{ "configure", "iia", null },
	{ "close", "", null },
	{ "configure_bounds", "4ii", null },
	{ "wm_capabilities", "5a", null },
};

Interface xdg_toplevel_interface = {
	.name = "xdg_toplevel",
	.version = 6,
	.method_count = top_methods.len,
	.methods = &top_methods,
	.event_count = top_events.len,
	.events = &top_events,
};


Message[*] positioner_methods = {
	{ "destroy", "", null },
	{ "set_size", "ii", null },
	{ "set_anchor_rect", "iiii", null },
	{ "set_anchor", "u", null },
	{ "set_gravity", "u", null },
	{ "set_constraint_adjustment", "u", null },
	{ "set_offset", "ii", null },
	{ "set_reactive", "", null },
	{ "set_parent_size", "ii", null },
	{ "set_parent_configure", "u", null },
};

Interface xdg_positioner_interface = {
	.name = "xdg_positioner",
	.version = 6,
	.method_count = positioner_methods.len,
	.methods = &positioner_methods,
	.event_count = 0,
	.events = null
};
