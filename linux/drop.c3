module c3w @feat(LINUX);

<*
 Files dropped on the window, from a file manager or a browser's download bar.

 `take_drops` answers with the local paths dropped since it was last asked, one
 per line, and forgets them: a drop is an event, and one that nobody took by the
 next ask is still waiting rather than lost. Only `file://` URIs are kept; a
 dragged link or a remote file has no path to give.

 While a drag is over the window the cursor follows it (`getMousePos`), so what
 is under the cursor when the paths arrive is where they were dropped.

 **Wayland**: `wl_data_device`, the same device the clipboard reads through. The
 drag's offer is accepted as `text/uri-list` with the copy action; without an
 action the compositor treats the drop as refused and never sends it.

 **X11** (XDND), macOS and Windows do not report drops yet: `take_drops` is
 always empty there.
*>
fn String Window.take_drops(&self, Allocator alloc)
{
	switch (self.src.backend)
	{
		case WAYLAND:
			WaylandWindow* wl = (WaylandWindow*)self.src.backend_data;
			String paths = wl.drops.str_view().copy(alloc);
			wl.drops.clear();
			return paths;
		default:
			return "".copy(alloc);
	}
}

const ZString MIME_URI_LIST = "text/uri-list";
const uint DND_ACTION_COPY = 1;

<*
 Say whether the drag that just entered can be dropped here: yes for a list of
 files, no for anything else.
*>
fn void wayland_drop_enter(WaylandWindow* self, uint serial)
{
	ClipOffer* offer = self.dnd_offer;
	if (offer == null) return;
	uint version = proxy_get_version(offer.proxy);
	// wl_data_offer.accept(serial, mime), opcode 0: a null type refuses.
	proxy_marshal_flags(offer.proxy, 0, null, version, 0, serial, offer.uri_list ? (char*)MIME_URI_LIST : null);
	if (version >= 3)
	{
		// wl_data_offer.set_actions(actions, preferred), opcode 4.
		uint action = offer.uri_list ? DND_ACTION_COPY : 0;
		proxy_marshal_flags(offer.proxy, 4, null, version, 0, action, action);
	}
	display_flush(self.display);
}

<*
 Read the dropped list and keep its local paths. Waits for the source to write
 it, up to about a second, the same as a paste.
*>
fn void wayland_drop_receive(WaylandWindow* self, ClipOffer* offer)
{
	if (offer == null || !offer.uri_list) return;
	int[2] fds = { -1, -1 };
	if (pipe2(&fds[0], O_CLOEXEC) != 0) return;
	uint version = proxy_get_version(offer.proxy);
	// wl_data_offer.receive(mime, fd), opcode 1.
	proxy_marshal_flags(offer.proxy, 1, null, version, 0, (char*)MIME_URI_LIST, fds[1]);
	display_flush(self.display);
	close_fd(fds[1]);

	@pool()
	{
		DString list = dstring::new(tmem);
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
			list.append(chunk[:got]);
		}
		close_fd(fds[0]);
		uri_list_paths(list.str_view(), &self.drops);
	};

	// wl_data_offer.finish, opcode 3: the drop is done with, so the source
	// may let go of its data.
	if (version >= 3) proxy_marshal_flags(offer.proxy, 3, null, version, 0);
	display_flush(self.display);
}

<*
 The local paths in a `text/uri-list`, appended to `out` a line each. Lines are
 CRLF by the RFC and LF by some senders; `#` lines are comments.
*>
fn void uri_list_paths(String list, DString* out)
{
	usz at = 0;
	while (at < list.len)
	{
		usz end = at;
		while (end < list.len && list[end] != '\n') end++;
		String line = list[at:end - at];
		at = end + 1;
		while (line.len > 0 && (line[^1] == '\r' || line[^1] == ' ')) line = line[:line.len - 1];
		if (line.len < 8 || line[0] == '#') continue;
		if (line[:7] != "file://") continue;
		// file://host/path: the host is empty or localhost, and the path is
		// what follows it.
		String rest = line[7..];
		usz slash = 0;
		while (slash < rest.len && rest[slash] != '/') slash++;
		if (slash == rest.len) continue;
		percent_decode(rest[slash..], out);
		out.append_char('\n');
	}
}

fn void percent_decode(String text, DString* out) @private
{
	for (usz i = 0; i < text.len; i++)
	{
		char c = text[i];
		if (c == '%' && i + 2 < text.len)
		{
			int hi = hex_value(text[i + 1]);
			int lo = hex_value(text[i + 2]);
			if (hi >= 0 && lo >= 0)
			{
				out.append_char((char)(hi * 16 + lo));
				i += 2;
				continue;
			}
		}
		out.append_char(c);
	}
}

fn int hex_value(char c) @private
{
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}
