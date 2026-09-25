module c3w @feat(LINUX);
import std::io;

<*
 The system clipboard, as text.

 `set_clipboard` takes ownership of the clipboard for this window and answers
 whoever asks for it from then on; `get_clipboard` asks whoever owns it and
 waits (up to about a second) for the answer. Only text is offered and taken:
 UTF-8, with the plain-text names older clients look for.

 **Wayland**: `wl_data_device`. Setting needs the serial of a recent key or
 button event of this window's, which the compositor checks - a paste bound to
 a key press satisfies it without anyone thinking about it. The compositor
 only tells a client what is on the clipboard while it has keyboard focus.

 **X11**: the CLIPBOARD selection. The answer to a request arrives as an event,
 so `get_clipboard` reads events until it comes; any other event it meets on
 the way is kept for the next `getEvent`, not lost.
*>
fn void Window.set_clipboard(&self, String text)
{
	switch (self.src.backend)
	{
		case WAYLAND: wayland_set_clipboard((WaylandWindow*)self.src.backend_data, text);
		case X11:     x11_set_clipboard((X11Window*)self.src.backend_data, text);
		default:      break;
	}
}

<*
 What the clipboard holds, as text, allocated with `alloc`. Empty when it holds
 nothing, holds something that is not text, or its owner did not answer.
*>
fn String Window.get_clipboard(&self, Allocator alloc)
{
	switch (self.src.backend)
	{
		case WAYLAND: return wayland_get_clipboard((WaylandWindow*)self.src.backend_data, alloc);
		case X11:     return x11_get_clipboard((X11Window*)self.src.backend_data, alloc);
		default:      return "".copy(alloc);
	}
}

// How long a paste waits for the clipboard's owner, in 50 ms polls.
const int CLIPBOARD_WAIT_POLLS = 20;

// --- Wayland -----------------------------------------------------------------

// What a wl_data_offer said it can be read as. One per offer the compositor
// makes, the listener's data, freed with the offer.
struct ClipOffer
{
	Proxy proxy;
	bool utf8;  // text/plain;charset=utf-8 or UTF8_STRING
	bool plain; // text/plain, TEXT or STRING
}

struct DataDeviceListener
{
	void* data_offer;
	void* enter;
	void* leave;
	void* motion;
	void* drop;
	void* selection;
}

struct DataOfferListener
{
	void* offer;
	void* source_actions;
	void* action;
}

struct DataSourceListener
{
	void* target;
	void* send;
	void* cancelled;
	void* dnd_drop_performed;
	void* dnd_finished;
	void* action;
}

DataDeviceListener dataDeviceListener = { &ddDataOffer, &ddEnter, &ddLeave, &noop, &ddDrop, &ddSelection };
DataOfferListener dataOfferListener = { &offerMime, &noop, &noop };
DataSourceListener dataSourceListener = { &noop, &sourceSend, &sourceCancelled, &noop, &noop, &noop };

const ZString MIME_UTF8 = "text/plain;charset=utf-8";
const ZString[5] MIME_OFFERED = { "text/plain;charset=utf-8", "text/plain", "UTF8_STRING", "TEXT", "STRING" };

fn void clip_offer_free(ClipOffer* offer) @private
{
	if (offer == null) return;
	// wl_data_offer.destroy, opcode 2.
	proxy_marshal_flags(offer.proxy, 2, null, proxy_get_version(offer.proxy), WL_MARSHAL_FLAG_DESTROY);
	free(offer);
}

fn void ddDataOffer(WaylandWindow* self, Proxy device, Proxy offer) @private
{
	ClipOffer* state = mem::new(ClipOffer);
	*state = { .proxy = offer };
	proxy_add_listener(offer, &dataOfferListener, state);
}

fn void offerMime(ClipOffer* state, Proxy offer, char* mime) @private
{
	String name = ((ZString)mime).str_view();
	if (name == "text/plain;charset=utf-8" || name == "UTF8_STRING") state.utf8 = true;
	if (name == "text/plain" || name == "TEXT" || name == "STRING") state.plain = true;
}

// A drag entering the window. Nothing is dropped here yet, so the offer is
// only held until the drag leaves or drops.
fn void ddEnter(WaylandWindow* self, Proxy device, uint serial, Surface surface, int x, int y, Proxy offer) @private
{
	clip_offer_free(self.dnd_offer);
	self.dnd_offer = offer != null ? (ClipOffer*)proxy_get_user_data(offer) : null;
}

fn void ddLeave(WaylandWindow* self, Proxy device) @private
{
	clip_offer_free(self.dnd_offer);
	self.dnd_offer = null;
}

fn void ddDrop(WaylandWindow* self, Proxy device) @private
{
	clip_offer_free(self.dnd_offer);
	self.dnd_offer = null;
}

fn void ddSelection(WaylandWindow* self, Proxy device, Proxy offer) @private
{
	ClipOffer* next = offer != null ? (ClipOffer*)proxy_get_user_data(offer) : null;
	if (next == self.selection_offer) return;
	clip_offer_free(self.selection_offer);
	self.selection_offer = next;
}

fn void sourceSend(WaylandWindow* self, Proxy source, char* mime, int fd) @private
{
	String text = self.clip_text.str_view();
	usz done = 0;
	while (done < text.len)
	{
		sz wrote = write_fd(fd, &text[done], text.len - done);
		if (wrote <= 0) break;
		done += (usz)wrote;
	}
	close_fd(fd);
}

fn void sourceCancelled(WaylandWindow* self, Proxy source) @private
{
	if (source == self.clip_source) self.clip_source = null;
	// wl_data_source.destroy, opcode 1.
	proxy_marshal_flags(source, 1, null, proxy_get_version(source), WL_MARSHAL_FLAG_DESTROY);
}

<*
 Make the seat's data device, once the registry has given both halves.
*>
fn void wayland_clipboard_init(WaylandWindow* self)
{
	if (self.data_device != null || self.data_device_manager == null || self.seat == null) return;
	if (wl_data_device_interface == null || proxy_get_user_data == null) return;
	// wl_data_device_manager.get_data_device, opcode 1.
	self.data_device = proxy_marshal_flags(self.data_device_manager, 1, wl_data_device_interface,
		proxy_get_version(self.data_device_manager), 0, null, self.seat);
	if (self.data_device != null) proxy_add_listener(self.data_device, &dataDeviceListener, self);
}

fn void wayland_set_clipboard(WaylandWindow* self, String text)
{
	wayland_clipboard_init(self);
	if (self.data_device == null || wl_data_source_interface == null) return;
	self.clip_text.clear();
	self.clip_text.append(text);

	// wl_data_device_manager.create_data_source, opcode 0; then an offer
	// (opcode 0) for each name the text answers to.
	Proxy source = proxy_marshal_flags(self.data_device_manager, 0, wl_data_source_interface,
		proxy_get_version(self.data_device_manager), 0, null);
	if (source == null) return;
	proxy_add_listener(source, &dataSourceListener, self);
	foreach (mime : MIME_OFFERED) proxy_marshal_flags(source, 0, null, proxy_get_version(source), 0, (char*)mime);
	// wl_data_device.set_selection(source, serial), opcode 1. The source it
	// replaces is cancelled by the compositor, which is where it is destroyed.
	proxy_marshal_flags(self.data_device, 1, null, proxy_get_version(self.data_device), 0, source, self.input_serial);
	self.clip_source = source;
	display_flush(self.display);
}

fn String wayland_get_clipboard(WaylandWindow* self, Allocator alloc)
{
	// Our own selection is answered from here: a read through the compositor
	// would wait on this very thread to write the other end.
	if (self.clip_source != null) return self.clip_text.str_view().copy(alloc);

	// The compositor may have said something since the last poll.
	dispatch_pending(self.display);
	ClipOffer* offer = self.selection_offer;
	if (offer == null || (!offer.utf8 && !offer.plain)) return "".copy(alloc);

	int[2] fds = { -1, -1 };
	if (pipe2(&fds[0], O_CLOEXEC) != 0) return "".copy(alloc);
	// wl_data_offer.receive(mime, fd), opcode 1.
	ZString mime = offer.utf8 ? MIME_UTF8 : "text/plain";
	proxy_marshal_flags(offer.proxy, 1, null, proxy_get_version(offer.proxy), 0, (char*)mime, fds[1]);
	display_flush(self.display);
	close_fd(fds[1]);

	DString text = dstring::new(alloc);
	char[4096] chunk;
	for (int waited = 0; waited < CLIPBOARD_WAIT_POLLS;)
	{
		PollFd[1] watch = { { .fd = fds[0], .events = POLLIN, .revents = 0 } };
		if (poll(&watch[0], 1, 50) <= 0)
		{
			waited++;
			continue;
		}
		sz got = read_fd(fds[0], &chunk[0], chunk.len);
		if (got <= 0) break;
		text.append(chunk[:got]);
	}
	close_fd(fds[0]);
	String result = text.str_view().copy(alloc);
	text.free();
	return result;
}

fn void wayland_clipboard_free(WaylandWindow* self)
{
	clip_offer_free(self.selection_offer);
	clip_offer_free(self.dnd_offer);
	self.selection_offer = null;
	self.dnd_offer = null;
	if (self.clip_source != null)
	{
		proxy_marshal_flags(self.clip_source, 1, null, proxy_get_version(self.clip_source), WL_MARSHAL_FLAG_DESTROY);
		self.clip_source = null;
	}
	if (self.data_device != null)
	{
		// wl_data_device.release (opcode 2) from v2; a plain destroy before.
		if (proxy_get_version(self.data_device) >= 2)
		{
			proxy_marshal_flags(self.data_device, 2, null, proxy_get_version(self.data_device), WL_MARSHAL_FLAG_DESTROY);
		}
		else
		{
			proxy_destroy(self.data_device);
		}
		self.data_device = null;
	}
	if (self.data_device_manager != null) proxy_destroy(self.data_device_manager);
	self.data_device_manager = null;
	self.clip_text.free();
}

// --- X11 ---------------------------------------------------------------------

alias FnXcbSetSelectionOwner = fn uint(Connection, uint owner, uint selection, uint time);
alias FnXcbConvertSelection = fn uint(Connection, uint requestor, uint selection, uint target, uint property, uint time);
alias FnXcbGetProperty = fn uint(Connection, char delete, uint window, uint property, uint type, uint offset, uint length);
alias FnXcbGetPropertyReply = fn void*(Connection, uint cookie, void* err);
alias FnXcbGetPropertyValue = fn void*(void* reply);
alias FnXcbGetPropertyValueLength = fn int(void* reply);
alias FnXcbGetFileDescriptor = fn int(Connection);
alias FnXcbChangePropertyRaw = fn uint(Connection, char mode, uint window, uint property, uint type, char format, uint len, void* data);
alias FnXcbSendEventRaw = fn uint(Connection, char propagate, uint destination, uint mask, void* event);

FnXcbSetSelectionOwner xcbSetSelectionOwner;
FnXcbConvertSelection xcbConvertSelection;
FnXcbGetProperty xcbGetProperty;
FnXcbGetPropertyReply xcbGetPropertyReply;
FnXcbGetPropertyValue xcbGetPropertyValue;
FnXcbGetPropertyValueLength xcbGetPropertyValueLength;
FnXcbGetFileDescriptor xcbGetFileDescriptor;
FnXcbChangePropertyRaw xcbChangePropertyRaw;
FnXcbSendEventRaw xcbSendEventRaw;

const uint X_ATOM_ATOM = 4;
const uint X_ATOM_STRING = 31;

// xcb_selection_request_event_t
struct SelectionRequestEvent
{
	char response_type;
	char pad0;
	ushort sequence;
	uint time;
	uint owner;
	uint requestor;
	uint selection;
	uint target;
	uint property;
}

// xcb_selection_notify_event_t, padded to the 32 bytes send_event sends.
struct SelectionNotifyEvent
{
	char response_type;
	char pad0;
	ushort sequence;
	uint time;
	uint requestor;
	uint selection;
	uint target;
	uint property;
	char[12] pad1;
}

fn bool x11_clipboard_load(X11Window* self) @private
{
	if (xcbSetSelectionOwner == null)
	{
		xcbSetSelectionOwner = (FnXcbSetSelectionOwner)dlsym(_xcb_lib, "xcb_set_selection_owner");
		xcbConvertSelection = (FnXcbConvertSelection)dlsym(_xcb_lib, "xcb_convert_selection");
		xcbGetProperty = (FnXcbGetProperty)dlsym(_xcb_lib, "xcb_get_property");
		xcbGetPropertyReply = (FnXcbGetPropertyReply)dlsym(_xcb_lib, "xcb_get_property_reply");
		xcbGetPropertyValue = (FnXcbGetPropertyValue)dlsym(_xcb_lib, "xcb_get_property_value");
		xcbGetPropertyValueLength = (FnXcbGetPropertyValueLength)dlsym(_xcb_lib, "xcb_get_property_value_length");
		xcbGetFileDescriptor = (FnXcbGetFileDescriptor)dlsym(_xcb_lib, "xcb_get_file_descriptor");
		xcbChangePropertyRaw = (FnXcbChangePropertyRaw)dlsym(_xcb_lib, "xcb_change_property");
		xcbSendEventRaw = (FnXcbSendEventRaw)dlsym(_xcb_lib, "xcb_send_event");
	}
	if (xcbSetSelectionOwner == null || xcbConvertSelection == null || xcbGetProperty == null
		|| xcbGetPropertyReply == null || xcbGetPropertyValue == null || xcbGetPropertyValueLength == null
		|| xcbGetFileDescriptor == null || xcbChangePropertyRaw == null || xcbSendEventRaw == null) return false;
	if (self.atom_clipboard == 0)
	{
		self.atom_clipboard = x11_intern_atom(self.connection, "CLIPBOARD");
		self.atom_utf8 = x11_intern_atom(self.connection, "UTF8_STRING");
		self.atom_targets = x11_intern_atom(self.connection, "TARGETS");
		self.atom_clip_property = x11_intern_atom(self.connection, "_C3W_CLIPBOARD");
	}
	return self.atom_clipboard != 0;
}

fn void x11_set_clipboard(X11Window* self, String text)
{
	if (!x11_clipboard_load(self)) return;
	self.clip_text.clear();
	self.clip_text.append(text);
	self.clip_owned = true;
	xcbSetSelectionOwner(self.connection, (uint)(uptr)self.window, self.atom_clipboard, 0);
	xcbFlush(self.connection);
}

fn String x11_get_clipboard(X11Window* self, Allocator alloc)
{
	if (!x11_clipboard_load(self)) return "".copy(alloc);
	if (self.clip_owned) return self.clip_text.str_view().copy(alloc);

	uint window = (uint)(uptr)self.window;
	foreach (target : (uint[2]){ self.atom_utf8, X_ATOM_STRING })
	{
		xcbConvertSelection(self.connection, window, self.atom_clipboard, target, self.atom_clip_property, 0);
		xcbFlush(self.connection);
		uint property = 0;
		if (!x11_await_selection(self, &property)) return "".copy(alloc);
		if (property == 0) continue;

		// Deleted as it is read, which is what tells an INCR sender to go on;
		// INCR itself (a clipboard of more than a few hundred KB) is not read.
		void* reply = xcbGetPropertyReply(self.connection,
			xcbGetProperty(self.connection, 1, window, property, 0, 0, 1 << 24), null);
		if (reply == null) return "".copy(alloc);
		int len = xcbGetPropertyValueLength(reply);
		char* value = xcbGetPropertyValue(reply);
		String result = len > 0 ? ((String)value[:len]).copy(alloc) : "".copy(alloc);
		free(reply);
		return result;
	}
	return "".copy(alloc);
}

<*
 Read events until the SelectionNotify for our request, keeping the rest for
 the next poll. False when the owner never answered.
*>
fn bool x11_await_selection(X11Window* self, uint* property) @private
{
	int fd = xcbGetFileDescriptor(self.connection);
	for (int waited = 0; waited < CLIPBOARD_WAIT_POLLS;)
	{
		KeyPressEvent* event = xcbPollEvent(self.connection);
		if (event == null)
		{
			PollFd[1] watch = { { .fd = fd, .events = POLLIN, .revents = 0 } };
			if (poll(&watch[0], 1, 50) <= 0) waited++;
			continue;
		}
		uint type = (uint)event.type & 0x7f;
		if (type == 31 && ((SelectionNotifyEvent*)event).requestor == (uint)(uptr)self.window)
		{
			*property = ((SelectionNotifyEvent*)event).property;
			free(event);
			return true;
		}
		if (type == 29 || type == 30 || self.stash_count >= self.stash.len)
		{
			x11_handleEvent(self, event);
			free(event);
			continue;
		}
		self.stash[self.stash_count++] = event;
	}
	return false;
}

<*
 Events `x11_await_selection` set aside, handled at the start of the next poll
 in the order they came.
*>
fn void x11_drain_stash(X11Window* self)
{
	for (int i = 0; i < self.stash_count; i++)
	{
		x11_handleEvent(self, self.stash[i]);
		free(self.stash[i]);
	}
	self.stash_count = 0;
}

// xcb_selection_clear_event_t
struct SelectionClearEvent
{
	char response_type;
	char pad0;
	ushort sequence;
	uint time;
	uint owner;
	uint selection;
}

// Someone else took the clipboard.
fn void x11_selection_clear(X11Window* self, KeyPressEvent* event)
{
	if (((SelectionClearEvent*)event).selection == self.atom_clipboard) self.clip_owned = false;
}

// Another client asks for the clipboard we hold: write the answer onto its
// window and tell it where.
fn void x11_selection_request(X11Window* self, KeyPressEvent* event)
{
	SelectionRequestEvent* request = (SelectionRequestEvent*)event;
	uint property = request.property != 0 ? request.property : request.target;
	String text = self.clip_text.str_view();
	if (!self.clip_owned || request.selection != self.atom_clipboard)
	{
		property = 0;
	}
	else if (request.target == self.atom_targets)
	{
		uint[3] targets = { self.atom_targets, self.atom_utf8, X_ATOM_STRING };
		xcbChangePropertyRaw(self.connection, 0, request.requestor, property, X_ATOM_ATOM, 32, 3, &targets[0]);
	}
	else if (request.target == self.atom_utf8 || request.target == X_ATOM_STRING)
	{
		xcbChangePropertyRaw(self.connection, 0, request.requestor, property, request.target, 8, (uint)text.len, text.ptr);
	}
	else
	{
		property = 0;
	}
	SelectionNotifyEvent notify = {
		.response_type = 31,
		.time = request.time,
		.requestor = request.requestor,
		.selection = request.selection,
		.target = request.target,
		.property = property,
	};
	xcbSendEventRaw(self.connection, 0, request.requestor, 0, &notify);
	xcbFlush(self.connection);
}
