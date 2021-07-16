do
    local function repr(data, level)
        if not level then
            level = 1
        end
    
        local data_type = type(data)
    
        if data_type == 'table' then
            if level == nil then
                level = 1
            end
    
            if data.__repr ~= nil then
                return data:__repr()
            end
    
            local length = 0
            local has_table = false
            local string_keys = false
            for i, v in pairs(data) do
                if type(v) == 'table' then
                    has_table = true
                end
                if type(i) ~= 'number' then
                    string_keys = true
                end
                length = length + 1
            end
    
            io.write('{')
    
            local iter_func = nil
            if string_keys then
                iter_func = pairs
            else
                iter_func = ipairs
            end
    
            local h = 1
            for i, v in iter_func(data) do
                if i ~= "meta" then
                    if has_table or string_keys then
                        io.write('\n  ')
                        for j=1, level do
                            if j > 1 then
                                io.write('  ')
                            end
                        end
                    end
                    if string_keys then
                        io.write('[')
                        repr(i, level + 1)
                        io.write('] = ')
                    end
                    if type(v) == 'table' then
                        repr(v, level + 1)
                    else
                        repr(v, level + 1)
                    end
                    h = h + 1
                end
            end
            if has_table or string_keys then
                io.write('\n')
                for j=1, level do
                    if j > 1 then
                        io.write('  ')
                    end
                end
            end
            io.write('}\n')
        elseif data_type == 'string' then
            io.write("'")
            for char in data:gmatch('.') do
                local num = string.byte(char)
                if (num >= 0 and num <= 8) or num == 11 or num == 12 or (num >= 14 and num <= 31) or num >= 127 then
                    io.write('\\x')
                    io.write(('%02X'):format(num))
                elseif num == 92 or num == 39 then
                    io.write('\\')
                    io.write(char)
                elseif num == 9 then
                    io.write('\\t')
                elseif num == 10 then
                    io.write('\\n')
                elseif num == 13 then
                    io.write('\\r')
                else
                    io.write(char)
                end
            end
            io.write("'")
        elseif data_type == 'nil' then
            io.write('nil')
        else
            io.write((not tostring(data) or tostring(data) == "") and "nil" or tostring(data))
        end
    
        io.flush()
    end
    
    ---@class Error
    ---@field message string
    local Error = class "Error" do
        function Error.new(message)
            return constructor(Error, function(self)
                self.message = message or "std::Error thrown!"
            end)
        end
    end
    
    ---@class Vector
    ---@field type type
    ---@field cache table
    local Vector = class "Vector" do
        ---@param T type
        ---@param base table
        ---@return Vector
        function Vector.new(T, base)
            assert(T and typeof(T) == "string", "cannot create std::Vector with no type")
            return constructor(Vector, function(self)
                self.cache = base or {}
                self.type = T

                function self.meta.__tostring()
                    return self:ToString()
                end

                function self.meta.__len()
                    return self:Size()
                end

                function self.meta.__bnot()
                    return self:Values()
                end

                function self.meta.__band(_, vec)
                    return self:Union(vec)
                end
            end)
        end
    
        local function TypeEquals(value, expected)
            if typeof(value) == expected then
                return true
            end
            return false
        end
    
        local function VectorTypeError(value, expected)
            if typeof(value) == "Function" and expected == "function" then
                return
            end
            throw(Error(("VectorTypeError: \n\tgot: %s\n\texpected: %s"):format(typeof(value), expected)), 3)
        end

        local function AssertType(self, value)
            if not TypeEquals(value, self.type) then
                VectorTypeError(value, self.type)
            end
        end

        function Vector:Join(sep)
            local res = ""
            for v in ~self do
                res = res + v
                if self:IndexOf(v) ~= #self then
                    res = res + sep
                end
            end
            return res
        end
        
        function Vector:Fill(amount, callback)
            for i = 1, amount do
                self:Add((callback or lambda "|i| -> i")(i))
            end
        end

        function Vector:Filter(predicate)
            local res = Vector(self.type)
            for v in ~self do
                local i = self:IndexOf(v)
                if predicate(v, i) then
                    res:Add(v)
                end
            end
            return res
        end

        function Vector:Map(transform)
            local res = Vector(self.type)
            for v in ~self do
                local i = self:IndexOf(v)
                res:Add(transform(v, i))
            end
            return res
        end

        function Vector:At(idx)
            return self.cache[idx]
        end

        function Vector:Union(vec)
            assert(
                TypeEquals(vec, "Vector") and vec.type == "string",
                "expected to merge Vector<" + self.type + ">"
            )

            local res = Vector(self.type, self.cache)
            for v in ~vec do
                res:Add(v)
            end
            return res
        end

        function Vector:Slice(start, finish)
            finish = finish or #self
            local res = Vector(self.type)
            for i = start, finish do
                res:Add(self:At(i))
            end
            return res
        end
    
        function Vector:Add(value)
            AssertType(self, value)
            table.insert(self.cache, value)
        end
    
        function Vector:First()
            return self.cache[1]
        end
    
        function Vector:Last()
            return self.cache[#self]
        end
    
        function Vector:Shift()
            self:Remove(self:First())
        end
    
        function Vector:Pop()
            self:Remove(self:Last())
        end
    
        function Vector:Remove(value)
            AssertType(self, value)
            local idx = self:IndexOf(value)
                self:RemoveIndex(idx)
        end
    
        function Vector:RemoveIndex(idx)
            table.remove(self.cache, idx)
        end
    
        function Vector:ForEach(callback)
            for i in self:Indices() do
                local v = self.cache[i]
                callback(v, i)
            end
        end
    
        function Vector:IndexOf(value)
            AssertType(self, value)
            local res
            self:ForEach(function(v, i)
                if v == value then
                    res = i
                end
            end)
            return res
        end

        function Vector:Unpack()
            return table.unpack(self.cache)
        end
    
        function Vector:Indices()
            return pairs(self.cache)
        end
    
        function Vector:Values()
            return values(self.cache)
        end
    
        function Vector:Display()
            repr(self)
        end
        
        function Vector:ToTable()
            return self.cache
        end

        function Vector:Size()
            return #self:ToTable()
        end
    
        function Vector:ToString()
            return ("Vector<%s>( size=%s )"):format(self.type, self:Size())
        end
    
        function Vector:__repr()
            repr(self.cache)
        end
    end
    
    ---@class List
    ---@field cache table
    local List = class "List" do
        ---@param base table
        function List.new(base)
            return constructor(List, function(self)
                self.cache = base or {}

                function self.meta.__tostring()
                    return self:ToString()
                end

                function self.meta.__len()
                    return self:Size()
                end

                function self.meta.__bnot()
                    return self:Values()
                end

                function self.meta.__band(_, list)
                    return self:Union(list)
                end
            end)
        end

        function List:Union(list)
            local res = List(self.cache)
            for v in ~list do
                res:Add(v)
            end
            return res
        end

        function List:Slice(start, finish)
            finish = finish or #self
            local res = List(self.cache)
            for i = start, finish do
                res:Add(self:At(i))
            end
            return res
        end

        function List:Shift()
            local val = self:First()
            self:Remove(val)
            return val
        end

        function List:Filter(predicate)
            local res = List()
            for v in ~self do
                local i = self:IndexOf(v)
                if predicate(v, i) then
                    res:Add(v)
                end
            end
            return res
        end

        function List:Map(transform)
            local res = List()
            for v in ~self do
                local i = self:IndexOf(v)
                res:Add(transform(v, i))
            end
            return res
        end

        function List:Unpack()
            return table.unpack(self.cache)
        end

        function List:At(idx)
            return self.cache[idx]
        end

        function List:Join(sep)
            local res = ""
            self:ForEach(function(v)
                res = res + tostring(v)
            end)
            return res
        end
    
        function List:First()
            return self.cache[1]
        end
    
        function List:Last()
            return self.cache[#self.cache]
        end
    
        function List:Add(value)
            table.insert(self.cache, value)
            return self
        end
    
        function List:RemoveIndex(idx)
            table.remove(self.cache, idx)
            return self
        end
    
        function List:Remove(value)
            local idx = self:IndexOf(value)
            return self:RemoveIndex(idx)
        end
    
        function List:ForEach(callback)
            for i in self:Indices() do
                local v = self.cache[i]
                callback(v, i)
            end
        end
    
        function List:IndexOf(value)
            local res
            self:ForEach(function(v, i)
                if v == value then
                    res = i
                end
            end)
            return res
        end
    
        function List:Indices()
            return pairs(self.cache)
        end
    
        function List:Values()
            return values(self.cache)
        end
        
        function List:Display()
            repr(self)
        end
    
        function List:ToTable()
            return self.cache
        end

        function List:Size()
            return #self:ToTable()
        end
    
        function List:ToString()
            return ("List( size=%s )"):format(self:Size())
        end
    
        function List:__repr()
            repr(self.cache)
        end
    end

    ---@class String
    ---@field content? string
    local String = class "String" do
        ---@param content string
        ---@return string
        function String.new(content)
            return constructor(String, function(self)
                self.content = content
            end)
        end

        --- Calls `predicate` for each
        --- character in the string. If
        --- `predicate` returns true,
        --- append the current character
        --- to the result returned by `:Filter`.
        ---@param predicate function
        ---@return string
        function String:Filter(predicate)
            local res = ""
            for i = 1, #self do
                local v = self:CharAt(i)
                if predicate(v, i) then
                    res = res + v
                end
            end
            return res
        end

        --- Calls `transform` for each
        --- character in the string and 
        --- appends the string returned
        --- by `transform`.
        ---@param transform function
        ---@return string
        function String:Map(transform)
            local res = ""
            for i = 1, #self do
                res = res + transform(self:CharAt(i), i)
            end
            return res
        end

        --- Trims a string from leading
        --- and trailing whitespaces.
        ---@return string
        function String:Trim()
            local s = self:GetContent()
            local _, i1 = s:find("^%s*")
            local i2 = s:find("%s*$")
            return self[{i1 + 1;i2 - 1}]
        end
    
        --- Returns itself
        ---@return string
        function String:GetContent()
            return self.content or self
        end

        --- Capitalizes the first
        --- character of the string
        --- and returns the result.
        ---@return string
        function String:CapitalizeFirst()
            local first = self[1]
            local rest = self[{2;#self}]
            return first:upper() + rest
        end


        --- Returns an iterator that
        --- returns each character of
        --- the string. Use the unary `~`
        --- operator on a string as
        --- an alias for this method.
        ---@return function
        function String:Chars()
            local i = 0
            return function()
                i = i + 1
                if i <= #self then
                    return self[i]
                end
            end
        end

        --- Splits a string into a
        --- `List` of strings, each
        --- element delimited by `sep`.
        ---@param sep string
        ---@return List
        function String:Split(sep)
            local res = Vector("string")
            if not sep then
                for c in ~self do
                    res:Add(c)
                end
            else
                for str in self:gmatch("([^" + sep + "]+)") do
                    res:Add(str)
                end
            end
            return res
        end

        --- Returns a tuple of
        --- each character inside
        --- of the string.
        ---@return ...
        function String:Unpack()
            local charList = Vector("string")
            for c in ~self do
                charList:Add(c)
            end
            return charList:Unpack()
        end

        --- Replaces each occurence of 
        --- `content` with `replacement` 
        --- and returns the result.
        ---@param content string
        ---@param replacement string
        ---@return string
        function String:Replace(content, replacement)
            return self:GetContent():gsub(content, replacement)
        end

        --- Returns true if there are
        --- any occurences of `sub`
        --- inside of the string,
        --- false otherwise.
        ---@param sub string
        ---@return boolean
        function String:Includes(sub)
            return self:GetContent():find(sub) and true or false
        end

        --- Returns true if the string
        --- is a valid e-mail address,
        --- false otherwise.
        ---@return boolean
        function String:IsEmail()
            return self:GetContent():match("[A-Za-z0-9%.%%%+%-%_]+@[A-Za-z0-9%.%%%+%-%_]+%.%w%w%w?%w?") ~= nil
        end

        --- Returns true if each character
        --- in the string is uppercase, false 
        --- otherwise.
        ---@return boolean
        function String:IsUpper()
            return not self:GetContent():find("%l")
        end

        --- Returns true if each character
        --- in the string is lowercase, false 
        --- otherwise.
        ---@return boolean
        function String:IsLower()
            return not self:GetContent():find("%u")
        end

        --- Returns true if each character
        --- in the string is a whitespace 
        --- (\n, \r, \t, and space), false 
        --- otherwise.
        ---@return boolean
        function String:IsBlank()
            return not self:IsAlphaNumeric() and self:Includes("%s+") or self == ""
        end

        ---@return boolean
        String.IsEmpty = String.IsBlank
        ---@return boolean
        String.IsWhite = String.IsBlank

        --- Returns true if each character
        --- in the string is a letter, false 
        --- otherwise.
        ---@return boolean
        function String:IsAlpha()
            return self:GetContent():find("%A")
        end

        --- Returns true if the string is
        --- a valid number, false otherwise.
        ---@return boolean
        function String:IsNumeric()
            return tonumber(self:GetContent()) and true or false
        end

        ---@return boolean
        String.IsDigit = String.IsNumeric

        --- Returns true if each character
        --- in the string is a letter or 
        --- the string is a valid number, 
        --- false otherwise.
        ---@return boolean
        function String:IsAlphaNumeric()
            return self:IsAlpha() or self:IsNumeric()
        end

        ---@return boolean
        String.IsAlphaNum = String.IsAlphaNumeric

        --- Returns a new string enclosed in 
        --- `wrap` repeated `repetitions` times.
        ---@param wrap string
        ---@param repetitions? integer
        ---@return string
        function String:Surround(wrap, repetitions)
            wrap = tostring(wrap):rep(repetitions or 1)
            return wrap + self:GetContent() + wrap
        end

        --- Encloses a string in quotation marks
        ---@return string
        function String:Quote()
            return self:GetContent():Wrap('"')
        end
    
        --- Returns the character at the 
        --- position `idx` in the string.
        ---@param idx integer
        ---@return string
        function String:CharAt(idx)
            return self:GetContent()[idx]
        end
    end
    
    setmetatable(string, { __index = String })
    
    ---@class Stack
    ---@field cache table
    local Stack = class "Stack" do
        ---@param base table
        function Stack.new(base)
            return constructor(Stack, function(self)
                self.cache = base or {}

                function self.meta.__tostring()
                    return self:ToString()
                end

                function self.meta.__len()
                    return self:Size()
                end

                function self.meta.__bnot()
                    return self:Values()
                end

                function self.meta.__band(_, stack)
                    return self:Union(stack)
                end
            end)
        end
        
        function Stack:Unpack()
            return table.unpack(self.cache)
        end

        function Stack:Union(stack)
            local res = Stack(self.cache)
            for v in ~stack do
                res:Push(v)
            end
            return res
        end
        
        function Stack:First()
            return self.cache[1]
        end
    
        function Stack:Last()
            return self.cache[#self.cache]
        end
    
        function Stack:Push(value)
            table.insert(self.cache, value)
            return #self.cache
        end
    
        function Stack:Pop()
            local idx = #self.cache
            local element = self.cache[idx]
            table.remove(self.cache, idx)
            return element
        end
    
        function Stack:Peek(offset)
            return self.cache[#self.cache + (offset or 0)]
        end

        function Stack:Values()
            return values(self.cache)
        end

        function Stack:Size()
            return #self:ToTable()
        end
    
        function Stack:ToString()
            return ("Stack( size=%s )"):format(self:Size())
        end
    
        function Stack:__repr()
            repr(self.cache)
        end
    end
    
    ---@class Map
    ---@field K type
    ---@field V type
    ---@field cache table
    local Map = class "Map" do
        ---@param K type
        ---@param V type
        ---@param cache table
        function Map.new(K, V, base)
            assert(K and typeof(K) == "string", "Map must have key type")
            assert(V and typeof(V) == "string", "Map must have value type")
            return constructor(Map, function(self)
                self.cache = base or {}
                self.K = K
                self.V = V

                function self.meta.__tostring()
                    return self:ToString()
                end

                function self.meta.__len()
                    return self:Size()
                end

                function self.meta.__bnot()
                    return self:Values()
                end
            end)
        end
    
        local function TypeEquals(value, expected)
            if typeof(value) == expected then
                return true
            end
            return false
        end
    
        local function MapTypeError(value, expected)
            throw(Error(("MapTypeError: \n\tgot: %s\n\texpected: %s"):format(type(value), expected)))
        end
        
        local function AssertType(value, expected)
            if not TypeEquals(value, expected) then
                MapTypeError(value, expected)
            end
        end

        function Map:Union(map)
            local res = Map(self.K, self.V, self.cache)
            for k, v in map:Keys() do
                res:Set(k, v)
            end
            return res
        end
    
        function Map:Set(key, value)
            AssertType(key, self.K)
            AssertType(value, self.V)
            self.cache[key] = value
        end
    
        function Map:Get(key)
            AssertType(key, self.K)
            return self.cache[key]
        end
    
        function Map:Delete(key)
            AssertType(key, self.K)
            self.cache[key] = nil
        end
    
        function Map:Keys()
            return pairs(self.cache)
        end
    
        function Map:Values()
            return values(self.cache)
        end
        
        function Map:Display()
            repr(self)
        end
    
        function Map:ToTable()
            return self.cache
        end
    
        function Map:ToString()
            return ("Map<%s, %s>( size=%s )"):format(self.K, self.V, self:Size())
        end
    
        function Map:Size()
            local count = 0
            for _ in self:Keys() do
                count = count + 1
            end
            return count
        end
    
        function Map:__repr()
            repr(self.cache)
        end
    end

    ---@class Map
    ---@field cache table
    local Queue = class "Queue" do
        ---@field base table
        function Queue.new(base)
            return constructor(Queue, function(self)
                self.cache = base or {}

                function self.meta.__tostring()
                    return self:ToString()
                end

                function self.meta.__len()
                    return self:Size()
                end

                function self.meta.__bnot()
                    return self:Values()
                end

                function self.meta.__band(_, queue)
                    return self:Union(queue)
                end
            end)
        end

        function Queue:Unpack()
            return table.unpack(self.cache)
        end

        function Queue:Union(queue)
            local res = Queue(self.cache)
            for v in ~queue do
                res:Add(v)
            end
            return res
        end

        function Queue:Slice(start, finish)
            finish = finish or #self
            local res = Queue(self.type)
            for i = start, finish do
                res:Add(self:At(i))
            end
            return res
        end

        function Queue:First()
            return self:At(1)
        end

        function Queue:Last()
            return self:At(#self)
        end

        function Queue:At(idx)
            return self.cache[idx]
        end

        function Queue:Enqueue(value)
            table.insert(self.cache, value)
        end
    
        function Queue:Dequeue()
            local v = self:First()
            table.remove(self.cache, 1)
            return v
        end

        function Queue:Indices()
            return pairs(self.cache)
        end
    
        function Queue:Values()
            return values(self.cache)
        end

        function Queue:Size()
            return #self:ToTable()
        end

        function Queue:ToTable()
            return self.cache
        end
    
        function Queue:ToString()
            return ("Queue( size=%s )"):format(self:Size())
        end

        function Queue:__repr()
            repr(self.cache)
        end
    end

    ---@class Deque
    ---@field cache table
    local Deque = class "Deque" do
        ---@param base table
        function Deque.new(base)
            extend(Deque, Queue.new(base))
            return constructor(Deque, function(self)
                function self.meta.__tostring()
                    return self:ToString()
                end

                function self.meta.__len()
                    return self:Size()
                end

                function self.meta.__bnot()
                    return self:Values()
                end
            end)
        end

        function Deque:Unpack()
            return table.unpack(self.cache)
        end

        function Deque:Slice(start, finish)
            finish = finish or #self
            local res = Deque()
            for i = start, finish do
                res:AddLast(self:At(i))
            end
            return res
        end

        function Deque:At(idx)
            return self.cache[idx]
        end

        function Deque:AddFirst(value)
            table.insert(self.cache, 1, value)
        end

        function Deque:RemoveFirst()
            table.remove(self.cache, 1)
        end

        function Deque:AddLast(value)
            self:Add(value)
        end

        function Deque:RemoveLast()
            self:Remove()
        end

        function Deque:Indices()
            return pairs(self.cache)
        end
    
        function Deque:Values()
            return values(self.cache)
        end

        function Deque:Size()
            return #self:ToTable()
        end

        function Deque:ToTable()
            return self.cache
        end
    
        function Deque:ToString()
            return ("Deque( size=%s )"):format(self:Size())
        end

        function Deque:__repr()
            repr(self.cache)
        end
    end

    ---@class Pair
    ---@field first any
    ---@field second any
    local Pair = class "Pair" do
        function Pair.new(first, second)
            return constructor(Pair, function(self)
                self.first = first
                self.second = second

                function self.meta.__bnot()
                    return values(self:ToTable())
                end
            end)
        end

        function Pair:Unpack()
            return table.unpack(self:ToTable())
        end

        function Pair:ToTable()
            return {self.first, self.second}
        end
    end

    ---@class KeyValuePair
    ---@field first string
    ---@field second any
    local KeyValuePair = class "KeyValuePair" do
        function KeyValuePair.new(first, second)
            assert(typeof(first) == "string", "key in KeyValuePair must be a string")
            return constructor(KeyValuePair, function(self)
                self.first = first
                self.second = second

                function self.meta.__bnot()
                    return values(self:ToTable())
                end
            end)
        end

        function KeyValuePair:Unpack()
            return table.unpack(self:ToTable())
        end

        function KeyValuePair:ToTable()
            return {self.first, self.second}
        end
    end


    ---@class StrictPair
    ---@field T1 type
    ---@field T2 type
    ---@field first T1
    ---@field second T2
    local StrictPair = class "StrictPair" do
        function StrictPair.new(T1, T2, first, second)
            assert(typeof(first) == T1, "first value in StrictPair must be of type '" + T1 + "'")
            assert(typeof(second) == T2, "second value in StrictPair must be of type '" + T2 + "'")
            return constructor(StrictPair, function(self)
                self.first = first
                self.second = second

                function self.meta.__bnot()
                    return values(self:ToTable())
                end
            end)
        end

        function StrictPair:Unpack()
            return table.unpack(self:ToTable())
        end

        function StrictPair:ToTable()
            return {self.first, self.second}
        end
    end

    ---@class StrictKeyValuePair
    ---@field V type
    ---@field first string
    ---@field second V
    local StrictKeyValuePair = class "StrictKeyValuePair" do
        function StrictKeyValuePair.new(V, first, second)
            assert(typeof(first) == "string", "key in StrictKeyValuePair must be a string")
            assert(typeof(second) == V, "value in StrictKeyValuePair must be of type '" + V + "'")
            return constructor(StrictKeyValuePair, function(self)
                self.first = first
                self.second = second

                function self.meta.__bnot()
                    return values(self:ToTable())
                end
            end)
        end

        function StrictKeyValuePair:Unpack()
            return table.unpack(self:ToTable())
        end

        function StrictKeyValuePair:ToTable()
            return {self.first, self.second}
        end
    end

    ---@class Set
    ---@field cache table
    local Set = class "Set" do
        ---@param base table
        function Set.new(base)
            return constructor(Set, function(self)
                self.cache = base or {}

                function self.meta.__tostring()
                    return self:ToString()
                end

                function self.meta.__len()
                    return self:Size()
                end

                function self.meta.__bnot()
                    return self:Values()
                end

                function self.meta.__band(_, set)
                    return self:Union(set)
                end

                function self.meta.__bor(_, set)
                    return self:Intersect(set)
                end
            end)
        end

        local function SetAlreadyContains(value)
            throw(Error("Set already contains value '" + tostring(value) + "'"))
        end

        function Set:Unpack()
            return table.unpack(self.cache)
        end

        function Set:Intersect(set)
            local res = Set(self.cache)
            for i in self:Indices() do
                res.cache[i] = set:At(i)
            end
            return res
        end

        function Set:Union(set)
            local res = Set(self.cache)
            for v in ~set do
                res:Add(v)
            end
            return res
        end

        function Set:Slice(start, finish)
            finish = finish or #self
            local res = Set()
            for i = start, finish do
                res:Add(self:At(i))
            end
            return res
        end

        function Set:At(idx)
            return self.cache[idx]
        end

        function Set:Has(value)
            local res = false
            for v in ~self do
                if v == value then
                    res = true
                end
            end
            return res
        end

        function Set:Add(value)
            if self:Has(value) then
                SetAlreadyContains(value)
            end
            table.insert(self.cache, value)
        end
    
        function Set:First()
            return self.cache[1]
        end
    
        function Set:Last()
            return self.cache[#self.cache]
        end
    
        function Set:Shift()
            self:Remove(self:First())
        end
    
        function Set:Pop()
            self:Remove(self:Last())
        end
    
        function Set:Remove(value)
            local idx = self:IndexOf(value)
            self:RemoveIndex(idx)
        end
    
        function Set:RemoveIndex(idx)
            table.remove(self.cache, idx)
        end
    
        function Set:ForEach(callback)
            for i in self:Indices() do
                local v = self.cache[i]
                callback(v, i)
            end
        end
    
        function Set:IndexOf(value)
            local res
            self:ForEach(function(v, i)
                if v == value then
                    res = i
                end
            end)
            return res
        end
    
        function Set:Indices()
            return pairs(self.cache)
        end
    
        function Set:Values()
            return values(self.cache)
        end
    
        function Set:Display()
            repr(self)
        end
        
        function Set:ToTable()
            return self.cache
        end

        function Set:Size()
            return #self:ToTable()
        end
    
        function Set:ToString()
            return ("Set( size=%s )"):format(self:Size())
        end
    
        function Set:__repr()
            repr(self.cache)
        end
    end

    ---@class LinkedNode
    ---@field value any
    ---@field next? LinkedNode
    local LinkedNode = class "LinkedNode" do
        ---@param value any
        ---@return LinkedNode
        function LinkedNode.new(value)
            return constructor(LinkedNode, function(self)
                self.value = value
                self.next = nil

                function self.meta.__tostring()
                    return self:ToString()
                end
            end)
        end

        function LinkedNode:Next()
            return self.next
        end

        function LinkedNode:ToString()
            return ("LinkedNode( value=%s next=%s )"):format(self.value, self.next)
        end
    end

    ---@class LinkedList
    ---@field root? LinkedNode
    local LinkedList = class "LinkedList" do
        ---@return LinkedList
        function LinkedList.new()
            return constructor(LinkedList, function(self)
                self.root = nil

                function self.meta.__len()
                    return self:Size()
                end

                function self.meta.__tostring()
                    return self:ToString()
                end

                function self.meta.__bnot()
                    return self:Nodes()
                end
            end)
        end

        function LinkedList:Remove(value)
            local parent
            for node in ~self do
                if node.value == value then
                    if parent == nil then
                        self.root = nil
                    else
                        parent.next = nil
                    end
                end
                parent = node
            end
        end

        function LinkedList:GetNodes()
            local nodes = Vector("LinkedNode")
            local current = self.root

            while true do
                if current ~= nil then
                    nodes:Add(current)
                    current = current:Next()
                else
                    break
                end
            end

            return nodes
        end

        function LinkedList:Nodes()
            return self:GetNodes():Values()
        end

        function LinkedList:ForEach(callback)
            local nodes = self:GetNodes()
            for node in ~nodes do
                callback(node)
            end
        end

        ---@param value any
        ---@return LinkedList
        function LinkedList:Add(value)
            if self.root == nil then
                self.root = LinkedNode(value, nil)
            else
                local current = self.root
                local node = current
                while true do
                    current = current:Next()
                    if current == nil then
                        break
                    else
                        node = current
                    end
                end
                node.next = LinkedNode(value, nil)
            end
            return self
        end

        ---@return LinkedNode
        function LinkedList:Next()
            return self.root
        end

        ---@return integer
        function LinkedList:Size()
            local size = 1
            local current
            while true do
                if self.root == nil then
                    break
                else
                    current = (current or self.root):Next()
                    if current ~= nil then
                        size = size + 1
                    else
                        break
                    end
                end
            end
            return size
        end

        ---@return string
        function LinkedList:ToString()
            return ("LinkedList( size=%s root=%s )"):format(#self, self.root)
        end

        ---@return void
        function LinkedList:__repr()
            repr(self.root)
        end
    end

    local MultiMap = class "MultiMap" do
        function MultiMap.new(K, V)
            return constructor(MultiMap, function(self)
                self.cache = {}
                self.K = K
                self.V = V
            end)
        end

        local function TypeEquals(value, expected)
            if typeof(value) == expected then
                return true
            end
            return false
        end
    
        local function MapTypeError(value, expected)
            throw(Error(("MultiMapTypeError: \n\tgot: %s\n\texpected: %s"):format(typeof(value), expected)), 2)
        end
        
        local function AssertType(value, expected)
            if not TypeEquals(value, expected) then
                MapTypeError(value, expected)
            end
        end

        function MultiMap:Delete(key)
            AssertType(key, self.K)
            self.cache[key] = nil
            return self
        end

        ---@return Vector
        function MultiMap:Get(key)
            AssertType(key, self.K)
            return self.cache[key]
        end

        function MultiMap:Set(key, ...)
            AssertType(key, self.K)
            if self.cache[key] == nil then
                self.cache[key] = Vector(self.V)
            end

            for v in varargs(...) do
                AssertType(v, self.V)
                self.cache[key]:Add(v)
            end
            return self
        end

        function MultiMap:__repr()
            repr(self.cache)
        end
    end
    
    ---@class EventEmitter
    ---@field listeners Map
    local EventEmitter = class "EventEmitter" do
        ---@return EventEmitter
        function EventEmitter.new()
            return constructor(EventEmitter, function(self)
                self.listeners = Map("string", "Vector")
            end)
        end

        ---@param event string
        ---@return Vector
        function EventEmitter:GetListener(event)
            local callbacks = self.listeners:Get(event)
            if not callbacks then
                self.listeners:Set(event, Vector("function"))
                return self:GetListener(event)
            end
            return self.listeners:Get(event)
        end

        ---@param event string
        ---@return integer
        function EventEmitter:ListenerCount(event)
            return #self:GetListener(event)
        end
    
        ---@param event string
        ---@param callback function
        ---@return EventEmitter
        function EventEmitter:AddListener(event, callback)
            self:GetListener(event):Add(callback)
            return self
        end
    
        ---@param event string
        ---@param callback function
        ---@return EventEmitter
        function EventEmitter:RemoveListener(event, callback)
            self:GetListener(event):Remove(callback)
            return self
        end
    
        ---@param event string
        ---@vararg ...
        ---@return EventEmitter
        function EventEmitter:Emit(event, ...)
            local callbacks = self:GetListener(event)
            for callback in ~callbacks do
                callback(...)
            end
            return self
        end
    
        ---@param event string
        ---@param callback function
        ---@return EventEmitter
        function EventEmitter:On(event, callback)
            return self:AddListener(event, callback)
        end
    
        ---@param event string
        ---@param callback function
        ---@return EventEmitter
        function EventEmitter:Once(event, callback)
            local function doOnce(...)
                callback(...)
                self:Off(event, doOnce)
            end
            return self:On(event, doOnce)
        end
    
        ---@param event string
        ---@param callback function
        ---@return EventEmitter
        function EventEmitter:Off(event, callback)
            return self:RemoveListener(event, callback)
        end

        ---@return void
        function EventEmitter:Destroy()
            self.listeners = nil
            self.meta.__index = function()
                throw(Error("EventEmitter no longer exists."))
            end
            
            self.meta.__newindex = function()
                throw(Error("EventEmitter no longer exists."))
            end
        end
    end

    ---@param fn function
    ---@vararg ...
    function spawn(fn, ...)
        local e = EventEmitter()
        e:Once("callFn", fn)
        e:Emit("callFn", ...)
        e:Destroy()
    end

    ---@class Input
    local Input = class "Input" do
        ---@return Input
        function Input.new()
            return constructor(Input, function(self)
                function self.meta.__shr(_, prompt)
                    io.write(prompt)
                    io.flush()
                    return io.read()
                end

                function self.meta.__tostring()
                    return "<stdin>"
                end
            end)
        end
    end

    ---@class Output
    local Output = class "Output" do
        ---@return Output
        function Output.new()
            return constructor(Output, function(self)
                function self.meta.__shl(output, content)
                    io.write(content)
                    return output
                end

                function self.meta.__tostring()
                    return "<stdout>"
                end
            end)
        end
    end

    local lout = Output()
    local lin = Input()
    do
        extend(Process, EventEmitter())
        Process.stdout = lout
        Process.stdin = lin

        ---@param code? integer
        function Process:Exit(code)
            self:Emit("exit", code or 1)
            throw(Error(""))
        end
    end

    do
        local Stream = class "Stream" do
            function Stream.new()
                extend(Stream, EventEmitter())
                return constructor(Stream)
            end
    
            function Stream:Pipe(dest, opts)
                local onData, onDrain, onEnd, onClose, onError, cleanup
    
                function onData(chunk)
                    if dest.writable then
                        if dest:Write() and self.Pause then
                            self:Pause()
                        end
                    end
                end
    
                function onDrain()
                    if self.readable and self.Resume then
                        self:Resume()
                    end
                end
    
                self:On("data", onData)
                dest:On("drain", onDrain)
    
                local didOnEnd = false
                function onEnd()
                    if didOnEnd then return end
                    didOnEnd = true
                    dest:End()
                end
    
                function onClose()
                    if didOnEnd then return end
                    didOnEnd = true
    
                    if typeof(dest.Destroy) == "function" then
                        dest:Destroy()
                    end
                end
    
                if not dest.isStdIO and (not opts or opts._end ~= false) then
                    self:On("end", onEnd)
                    self:On("close", onClose)
                end
    
                function onError(err)
                    cleanup()
                    if self:ListenerCount("error") == 0 then
                        throw(err)
                    end
                end
    
                self:On("error", onError)
                dest:On("error", onError)
    
                function cleanup()
                    self:Off("data", onData)
                    dest:Off("drain", onDrain)
    
                    self:Off("end", onEnd)
                    self:Off("close", onClose)
    
                    self:Off("error", onError)
                    dest:Off("error", onError)
    
                    self:Off("end", cleanup)
                    self:Off("close", cleanup)
                    dest:Off("close", cleanup)
                end
    
                self:On("end", cleanup)
                self:On("close", cleanup)
                dest:On("close", cleanup)
                dest:Emit("pipe", self)
    
                return dest
            end
        end

        local ReadableState = class "ReadableState" do
            function ReadableState.new(opts, stream)
                return constructor(ReadableState, function(self)
                    opts = opts or {}
                    
                    local hwm = opts.highWaterMark
                    local defaultHwm = 16
                    if not opts.objectMode then
                        defaultHwm = 16 * 1024
                    end

                    self.highWaterMark = hwm or defaultHwm
                    self.buffer = {}
                    self.length = 0
                    self.pipes = nil
                    self.pipesCount = 0
                    self.flowing = nil
                    self.ended = false
                    self.endEmitted = false
                    self.reading = false
                    self.sync = true
                    self.needReadable = false
                    self.emittedReadable = false
                    self.readableListening = false
                    self.objectMode = not not opts.readableObjectMode
                    if instanceof(stream, "Duplex") then
                        self.objectMode = self.objectMode or (not not opts.readableObjectMode)
                    end

                    self.ranOut = false
                    self.awaitDrain = 0
                    self.readingMore = false
                end)
            end    
        end

        local Readable = class "Readable" do
            function Readable.new(opts)
                return constructor(Readable, function(self)
                    extend(Readable, Stream())
                    self.readableState = ReadableState(opts, self)
                end)
            end

            local len, readableAddChunk, chunkInvalid, onEofChunk, emitReadable,
                maybeReadMore, needMoreData, roundUpToNextPowerOf2, howMuchToRead,
                endReadable, fromList, emitReadable_, flow, maybeReadMore_, resume,
                resume_, pipeOnDrain

            function Readable:Push(chunk)
                return readableAddChunk(self, self.readableState, chunk, false)
            end

            function Readable:Unshift(chunk)
                return readableAddChunk(self, self.readableState, chunk, "", true)
            end

            function Readable:Read(n)
                local state = self.readableState
                local nOrig = n

                if typeof(n) ~= "number" or n > 0 then
                    state.emittedReadable = false
                end

                if 
                    n == 0 and 
                    state.needReadable and 
                    (state.length >= state.highWaterMark or state.ended) 
                then
                    if state.length == 0 and state.ended then
                        endReadable(self)
                    else
                        emitReadable(self)
                    end
                    return nil
                end

                n = howMuchToRead(n, state)

                if n == 0 and state.ended then
                    if state.length == 0 then
                        endReadable(self)
                    end
                    return nil
                end

                local doRead = state.needReadable
                if state.length == 0 or state.length - n < state.highWaterMark then
                    doRead = true
                end

                if state.ended or state.reading then
                    doRead = false
                end

                if doRead then
                    state.reading = true
                    state.sync = true

                    if state.length == 0 then
                        state.needReadable = true
                    end

                    self:_Read(state.highWaterMark)
                    state.sync = false
                end

                if doRead and not state.reading then
                    n = howMuchToRead(nOrig, state)
                end

                local ret
                if n > 0 then
                    ret = fromList(n, state)
                end

                if ret == nil then
                    state.needReadable = true
                    n = 0
                end

                state.length = state.length - n
                if state.length == 0 and not state.ended then
                    state.needReadable = true
                end

                if
                    nOrig ~= n and
                    state.ended and
                    state.length == 0
                then
                    endReadable(self)
                end

                if ret ~= nil then
                    self:Emit("data", ret)
                end

                return ret
            end

            --abstract method, meant to be overridden
            function Readable:_Read(n)
                self:Emit("error", Error("not implemented"))
            end

            function Readable:Pipe(dest, pipeOpts)
                local state = self.readableState

                local onUnpipe, onEnd, cleanup, onData, onError, onClose, onFinish, onDrain, unpipe
                local endFn

                function onUnpipe(readable)
                    if self == readable then
                        cleanup()
                    end
                end

                function onEnd()
                    dest:End()
                end

                function cleanup()
                    dest:Off("close", onClose)
                    dest:Off("finish", onFinish)
                    dest:Off("drain", onDrain)
                    dest:Off("error", onError)
                    dest:Off("unpipe", onUnpipe)
                    
                    self:Off("end", onEnd)
                    self:Off("end", cleanup)
                    self:Off("data", onData)

                    if
                        state.awaitDrain and
                        (not dest.writableStream or dest.writableStream.needDrain)
                    then
                        onDrain()
                    end
                end

                function onData(chunk)
                    local ret = dest:Write(chunk)
                    if ret == false then
                        self.readableState.awaitDrain = self.readableState.awaitDrain + 1
                        self:Pause()
                    end
                end

                function onError(err)
                    unpipe()
                    dest:Off("error", onError)
                    if dest:ListenerCount("error") == 0 then
                        dest:Emit("error", err)
                    end
                end

                function onClose()
                    dest:Off("finish", onFinish)
                    unpipe()
                end

                function onFinish()
                    dest:Off("close", onClose)
                    unpipe()
                end

                function unpipe()
                    self:Unpipe(dest)
                end

                if state.pipesCount == 0 then
                    state.pipes = dest
                elseif state.pipesCount == 1 then
                    state.pipes = {state.pipes, dest}
                else
                    table.insert(state.pipes, dest)
                end
                state.pipesCount = state.pipesCount + 1

                local doEnd = (not pipeOpts or pipeOpts._end ~= false) and
                    dest ~= Process.stdout and
                    dest ~= Process.stderr

                if doEnd then
                    endFn = onEnd
                else
                    endFn = cleanup
                end

                if state.endEmitted then
                    coroutine.wrap(endFn)()
                else
                    self:Once("end", endFn)
                end

                dest:On("unpipe", onUnpipe)

                onDrain = pipeOnDrain(self)
                dest:On("drain", onDrain)
                self:On("data", onData)
                dest:Once("close", onClose)
                dest:Once("finish", onFinish)

                dest:Emit("pipe", self)
                if not state.flowing then
                    self:Resume()
                end

                return dest
            end

            function Readable:Unpipe(dest)
                local state = self.readableState
                if state.pipesCount == 0 then
                    return self
                end

                if state.pipesCount == 1 then
                    if dest and dest ~= state.pipes then
                        return self
                    end

                    if not dest then
                        dest = state.pipes
                    end

                    state.pipes = nil
                    state.pipesCount = 0
                    state.flowing = false
                    if dest then
                        dest:Emit("unpipe", self)
                    end

                    return self
                end

                if not dest then
                    local dests = state.pipes
                    local len = state.pipesCount
                    state.pipes = nil
                    state.pipesCount = 0
                    state.flowing = false

                    for i in luay.util.range(1, len, 1) do
                        dests[i]:Emit("unpipe", self)
                    end

                    return self
                end

                local i
                for j, pipe in ipairs(state.pipes) do
                    if pipe == dest then
                        i = j
                    end
                end

                if i == nil then
                    return self
                end

                table.remove(state.pipes, i)
                state.pipesCount = state.pipesCount - 1
                if state.pipesCount == 1 then
                    state.pipes = state.pipes[1]
                end

                dest:Emit("unpipe", self)
                return self
            end

            function Readable:On(event, callback)
                local res = Stream.On(self, event, callback)

                if event == "data" and self.readableState.flowing then
                    self:Resume()
                end

                if event == "readable" and self.readable then
                    local state = self.readableState
                    if not state.readableListening then
                        state.readableListening = true
                        state.emittedReadable = false
                        state.needReadable = true
                        if not state.reading then
                            local _self = self
                            coroutine.wrap(function()
                                _self:Read(0)
                            end)()
                        elseif state.length then
                            emitReadable(self, state)
                        end
                    end
                end

                return res
            end

            Readable.AddListener = Readable.On

            function Readable:Resume()
                local state = self.readableState
                if not state.flowing then
                    state.flowing = true
                    if not state.reading then
                        self:Read(0)
                    end
                    resume(self, state)
                end
                return self
            end

            function Readable:Pause()
                if self.readableState.flowing ~= false then
                    self.readableState.flowing = false
                    self:Emit("pause")
                end
                return self
            end

            function Readable:Wrap(stream)
                local state = stream.readableState
                local paused = false

                stream:On("end", function()
                    self:Emit("end")
                    self:Push(nil)
                end)

                stream:On("data", function(chunk)
                    if chunk == nil or not state.objectMode and len(chunk) == 0 then
                        return
                    end

                    local ret = self:Push(chunk)
                    if not ret then
                        paused = true
                        stream:Pause()
                    end
                end)

                for i in pairs(stream) do
                    if typeof(stream[i]) == "function" and self[i] == nil then
                        self[i] = stream[i]
                    end
                end

                local events = {"error", "close", "destroy", "resume", "pause"}
                for v in values(events) do
                    stream:On(v, luay.util.bind(self.Emit, self, v))
                end

                self._Read = function()
                    if paused then
                        paused = false
                        stream:Resume()
                    end
                end

                return self
            end

            function fromList(n, state)
                local list = state.buffer
                local length = state.length
                local objectMode = not not state.objectMode
                local ret

                if len(list) == 0 then
                    return nil
                end
            
                if length == 0 then
                    ret = nil
                elseif objectMode then
                    ret = table.remove(list, 1)
                elseif not n or n >= length then
                    ret = table.concat(list, "")
                    state.buffer = {}
                else
                    if n < len(list[1]) then
                        local buf = list[1]
                        ret = buf[{1;n}]
                        list[1] = buf[{n+1;-1}]
                    elseif n == len(list[1]) then
                        ret = table.remove(list, 1)
                    else
                        local tmp = {}
                        local c = 0
                        for i in luay.util.range(1, len(list), 1) do
                            if n - c >= len(list[1]) then
                                c = c + list[1]
                                table.insert(tmp, table.remove(list, 1))
                            else
                                c = n
                                table.insert(tmp, list[1][{1;n-c}])
                                list[1] = list[1][{n+1;-1}]
                                break
                            end
                        end
                        ret = table.concat(tmp)
                    end
                end
                return ret
            end

            function endReadable(stream)
                local state = stream.readableState
                if state.length == 0 then
                    throw(Error("endReadable() called on non-empty stream"))
                end

                if not state.endEmitted then
                    state.ended = true
                    coroutine.wrap(function()
                        if not state.endEmitted and state.length == 0 then
                            state.endEmitted = true
                            stream.readable = false
                            stream:Emit("end")
                        end
                    end)
                end
            end

            function flow(stream)
                local state = stream.readableState
                if state.flowing then
                    local chunk = stream:Read()
                    while chunk ~= nil and state.flowing do
                        chunk = stream:Read()
                    end
                end
            end

            function resume_(stream, state)
                state.resumeScheduled = false
                stream:Emit("resume")
                flow(stream)
                if state.flowing and not state.reading then
                    stream:Read(0)
                end
            end

            function resume(stream, state)
                if not state.resumeScheduled then
                    state.resumeScheduled = true
                    coroutine.wrap(resume_)(stream, state)
                end
            end

            function pipeOnDrain(src)
                return function()
                    local state = src.readableState
                    if state.awaitDrain ~= 0 then
                        state.awaitDrain = state.awaitDrain - 1
                    end

                    if state.awaitDrain == 0 and src:ListenerCount("data") ~= 0 then
                        state.flowing = true
                        flow(src)
                    end
                end
            end

            function maybeReadMore_(stream, state)
                local len = state.length
                while 
                    not state.reading and 
                    not state.flowing and 
                    not state.ended and 
                    state.length < state.highWaterMark 
                do
                    stream:Read(0)
                    if len == state.length then
                        break
                    else
                        len = state.length
                    end
                end
                state.readingMore = false
            end

            function maybeReadMore(stream, state)
                if not state.readingMore then
                    state.readingMore = true
                    coroutine.wrap(function()
                        maybeReadMore_(stream, state)
                    end)()
                end
            end

            function emitReadable_(stream)
                stream:Emit("readable")
                flow(stream)
            end

            function emitReadable(stream)
                local state = stream.readableState
                state.needReadable = false

                if not state.emittedReadable then
                    coroutine.wrap(function()
                        emitReadable_(stream)
                    end)()
                else
                    emitReadable_(stream)
                end
            end

            function onEofChunk(stream, state)
                state.ended = true
                emitReadable(stream)
            end

            function chunkInvalid(state, chunk)
                local err
                if typeof(chunk) ~= "string" and chunk and not state.objectMode then
                    err = Error("Invalid non-string/buffer chunk")
                end
                return err
            end

            function readableAddChunk(stream, state, chunk, addToFront)
                local err = chunkInvalid(state, chunk)
                if err then
                    stream:Emit("error", err)
                elseif chunk == nil then
                    state.reading = false
                    if not state.ended then
                        onEofChunk(stream, state)
                    end
                elseif state.objectMode or chunk or len(chunk) > 0 then
                    if state.ended and not addToFront then
                        local e = Error("stream:Push() after EOF")
                        stream:Emit("error", e)
                    else
                        if not addToFront then
                            state.reading = false
                        end

                        if state.flowing and state.length == 0 and not state.sync then
                            stream:Emit("data", chunk)
                            stream:Read(0)
                        else
                            if state.objectMode then
                                state.length = state.length + 1
                            else
                                state.length = state.length + len(chunk)
                            end

                            if addToFront then
                                table.insert(state.buffer, 1, chunk)
                            else
                                table.insert(state.buffer, chunk)
                            end

                            if state.needReadable then
                                emitReadable(stream)
                            end
                        end
                        maybeReadMore(stream, state)
                    end
                elseif not addToFront then
                    state.reading = false
                end

                return needMoreData(state)
            end

            function needMoreData(state)
                return not state.ended and (
                    state.needReadable or 
                    state.length < state.highWaterMark or
                    state.length == 0
                )
            end

            local MAX_HWM = 0x800000
            function roundUpToNextPowerOf2(n)
                if n >= MAX_HWM then
                    n = MAX_HWM
                else
                    n = n - 1
                    local p = 1
                    while p < 32 do
                        n = n | n >> p
                        p = p << 1
                    end
                    n = n + 1
                end
                return n
            end

            function howMuchToRead(n, state)
                if state.length == 0 and state.ended then
                    return 0
                end

                if state.objectMode then
                    if n == 0 then
                        return 0
                    else
                        return 1
                    end
                end

                if luay.util.isNaN(n) or not n then
                    if state.flowing and len(state.buffer) > 0 then
                        return len(state.buffer[1])
                    else
                        return state.length
                    end
                end

                if n <= 0 then
                    return 0
                end

                if n > state.highWaterMark then
                    state.highWaterMark = roundUpToNextPowerOf2(n)
                end

                if n > state.length then
                    if not state.ended then
                        state.needReadable = true
                        return 0
                    else
                        return state.length
                    end
                end

                return n
            end

            function len(buf)
                if typeof(buf) == "string" then
                    return buf:len()
                elseif typeof(buf) == "table" then
                    return #buf
                else
                    return -1
                end
            end
        end

        namespace "stream" {
            Stream = Stream;
            ReadableState = ReadableState;
            Readable = Readable;
        } : alias "std::stream"
    end
    
    namespace "std" {
        String = String;
        EventEmitter = EventEmitter;
        Error = Error;
        Vector = Vector;
        List = List;
        Stack = Stack;
        Map = Map;
        Queue = Queue;
        Deque = Deque;
        Set = Set;
        LinkedList = LinkedList;
        LinkedNode = LinkedNode;
        MultiMap = MultiMap;

        stream = stream;
    
        repr = repr;
    
        lout = lout;
        lin = lin;
        endl = "\n";
        
        printf = function(str)
            print(f(str))
        end;
    }

    _ENV.Stream = nil
end