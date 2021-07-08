f = {} do
    local load = load

    local function scan_using(scanner, arg, searched)
        local i = 1
        repeat
            local name, value = scanner(arg, i)
            if name == searched then
                return true, value
            end
            i = i + 1
        until name == nil
        return false
    end

    local function snd(_, b) return b end

    local function format(_, str)
        local outer_env = _ENV and (snd(scan_using(debug.getlocal, 3, "_ENV")) or snd(scan_using(debug.getupvalue, debug.getinfo(2, "f").func, "_ENV")) or _ENV) or getfenv(2)
        return (str:gsub("%b{}", function(block)
            local code, fmt = block:match("{(.*):(%%.*)}")
            code = code or block:match("{(.*)}")
            local exp_env = {}
            setmetatable(exp_env, { __index = function(_, k)
                local level = 6
                while true do
                    local funcInfo = debug.getinfo(level, "f")
                    if not funcInfo then break end
                    local ok, value = scan_using(debug.getupvalue, funcInfo.func, k)
                    if ok then return value end
                    ok, value = scan_using(debug.getlocal, level + 1, k)
                    if ok then return value end
                    level = level + 1
                end
                return rawget(outer_env, k)
            end })
            local fn, err = load("return "..code, "expression `"..code.."`", "t", exp_env)
            if fn then
                return fmt and string.format(fmt, fn()) or tostring(fn() or "")
            else
                throw(std.Error(err))
            end         
        end))
    end

    setmetatable(f, {
        __call = format
    })
end