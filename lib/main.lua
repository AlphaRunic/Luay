package.path = package.path .. ";lib/?.lua"
require "data"
require "core"
require "util"
require "std"
require "fstring"

namespace "luay" {
    std = std;
    util = util;
}

_G.std = nil
_G.util = nil