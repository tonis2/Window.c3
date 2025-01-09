module c3w @if(env::DARWIN);
import std::math;
import vk;
import std::io;
import std::core::types;

extern fn void new(Params params) @extern("new");