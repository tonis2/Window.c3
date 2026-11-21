module c3w @feat(ANDROID);

// Android has no window this library can own: a NativeActivity app gets its
// surface from the activity, and an OpenXR app draws into the runtime's
// swapchains instead. So this backend is the API with nothing behind it, which
// is what lets code written against c3w build for Android unchanged.

struct AndroidWindow
{
	EventMap event_map;
	EventLog event_log;
}

fn Window? new(Params params, String name)
{
	return { .width = params.width, .height = params.height };
}

fn void Window.wake(&self) { }

fn EventMap Window.getEvent(&self, bool wait = false)
{
	self.src.event_log.clear();
	return self.src.event_map;
}

fn Event[] Window.events(&self) => self.src.event_log.view();

fn void Window.free(&self) { }

fn float[<2>] Window.getMousePos(self) => { 0, 0 };
fn float[<2>] Window.getMouseDelta(&self) => { 0, 0 };
fn void Window.setPointerLock(&self, bool locked) { }
fn bool Window.pointerLocked(&self) => false;

fn void Window.set_size(&self, int width, int height)
{
	self.width = (float)width;
	self.height = (float)height;
}

fn void Window.set_title(&self, String title) { }
fn bool Window.fullscreen(&self) => true;
fn void Window.set_fullscreen(&self, bool on) { }
fn void Window.maximize(&self) { }
fn void Window.set_minimized(&self, bool minimized) { }

fn float Window.get_scroll(&self) => 0;
fn float Window.get_scroll_x(&self) => 0;
fn bool Window.get_scroll_precise(&self) => false;
fn String Window.get_text(&self) => "";
fn bool Window.should_close(&self) => false;
fn void Window.set_cursor(&self, CursorShape shape) { }
fn float Window.get_scale(&self) => 1.0;

// Kept inside this process: there is no system clipboard to reach without JNI.
String local_clipboard @private;

fn void Window.set_clipboard(&self, String text)
{
	if (local_clipboard.ptr != null) local_clipboard.free(mem);
	local_clipboard = text.copy(mem);
}

fn String Window.get_clipboard(&self, Allocator alloc) => local_clipboard.copy(alloc);

fn String Window.take_drops(&self, Allocator alloc) => "".copy(alloc);

alias VkSurface = void*;
alias VkGetInstanceProcAddrFn = fn void*(void*, char*);

<*
 Always fails: there is no ANativeWindow here to make a surface from.
 An OpenXR app has no use for one.
*>
fn VkSurface? Window.create_vk_surface(&self, void* vk_instance, VkGetInstanceProcAddrFn get_instance_proc_addr = null)
{
	return FAILED_OPENING_WINDOW~;
}
