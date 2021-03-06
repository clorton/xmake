--!A cross-platform build utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2019, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        string.lua
--

-- define module: string
local string = string or {}

-- save original interfaces
string._dump = string._dump or string.dump

-- make string with the level
function string._makestr(object, deflate, serialize, level)
    if type(object) == "string" then
        return serialize and string.format("%q", object) or object
    elseif type(object) == "boolean" or type(object) == "number" then  
        return tostring(object)
    elseif not serialize and type(object) == "table" and (getmetatable(object) or {}).__tostring then
        return tostring(object)
    elseif type(object) == "table" then  

        -- make head
        local s = ""
        if deflate then
            s = s .. "{"
        else
            if level > 0 then
                s = s .. "\n"
            end
            for l = 1, level do
                s = s .. "    "
            end
            s = s .. "{\n"
        end

        -- make body
        local i = 0
        for k, v in pairs(object) do  

            if deflate then
                s = s .. (i ~= 0 and "," or "")
            else
                for l = 1, level do
                    s = s .. "    "
                end
                if i == 0 then
                    s = s .. "    "
                else
                    s = s .. ",   "
                end
            end
            
            -- make key = value
            if type(k) == "string" then
                if serialize and not k:match("^%a[%w_]+$") then
                    k = string.format("[%q]", k)
                end
                if deflate then
                    s = s .. k .. "=" 
                else
                    s = s .. k .. " = " 
                end
            end
            local substr, errors = string._makestr(v, deflate, serialize, level + 1)  
            if substr == nil then
                return nil, errors
            end
            s = s .. substr

            if not deflate then
                s = s .. "\n"
            end
            i = i + 1
        end  

        -- make tail
        if not deflate then
            for l = 1, level do
                s = s .. "    "
            end
        end
        s = s .. "}"
        return s
    elseif serialize and type(object) == "function" then 
        return string.format("%q", string._dump(object))
    elseif serialize then
        return nil, "cannot serialize object: " .. type(object)
    elseif object ~= nil then
        return "<" .. tostring(object) .. ">"
    else
        return "nil"
    end
end

-- load table from string in table
function string._loadstr(object)
    -- only load luajit function data: e.g. "\27LJ\2\0\6=stdin"
    if type(object) == "string" and object:startswith("\27LJ") then
        return loadstring(object)
    elseif type(object) == "table" then  
        for k, v in pairs(object) do
            local value, errors = string._loadstr(v)
            if value ~= nil then
                object[k] = value
            else
                return nil, errors
            end
        end
    end
    return object
end

-- find the last substring with the given pattern
function string:find_last(pattern, plain)

    -- find the last substring
    local curr = 0
    repeat
        local next = self:find(pattern, curr + 1, plain)
        if next then
            curr = next
        end
    until (not next)

    -- found?
    if curr > 0 then
        return curr
    end
end

-- split string with the given characters
--
-- ("1\n\n2\n3"):split('\n') => 1, 2, 3
-- ("1\n\n2\n3"):split('\n', true) => 1, , 2, 3
--
function string:split(delimiter, strict)
    local result = {}
    if strict then
        for match in (self .. delimiter):gmatch("(.-)" .. delimiter) do
            table.insert(result, match)
        end
    else
        self:gsub("[^" .. delimiter .."]+", function(v) table.insert(result, v) end)
    end
    return result
end

-- trim the spaces
function string:trim()
    return (self:gsub("^%s*(.-)%s*$", "%1"))
end

-- trim the left spaces
function string:ltrim()
    return (self:gsub("^%s*", ""))
end

-- trim the right spaces
function string:rtrim()
    local n = #self
    while n > 0 and s:find("^%s", n) do n = n - 1 end
    return self:sub(1, n)
end

-- append a substring with a given separator
function string:append(substr, separator)

    -- check
    assert(self)

    -- not substr? return self
    if not substr then
        return self
    end

    -- append it
    local s = self
    if #s == 0 then
        s = substr
    else
        s = string.format("%s%s%s", s, separator or "", substr)
    end
    
    -- ok
    return s
end

-- encode: ' ', '=', '\"', '<'
function string:encode()

    -- null?
    if self == nil then return end

    -- done
    return (self:gsub("[%s=\"<]", function (w) return string.format("%%%x", w:byte()) end))
end

-- decode: ' ', '=', '\"'
function string:decode()

    -- null?
    if self == nil then return end

    -- done
    return (self:gsub("%%(%x%x)", function (w) return string.char(tonumber(w, 16)) end))
end

-- join array to string with the given separator
function string.join(items, sep)

    -- join them
    local str = ""
    local index = 1
    local count = #items
    for _, item in ipairs(items) do
        str = str .. item
        if index ~= count and sep ~= nil then
            str = str .. sep
        end
        index = index + 1
    end

    -- ok?
    return str
end

-- try to format
function string.tryformat(format, ...)

    -- attempt to format it
    local ok, str = pcall(string.format, format, ...)
    if ok then
        return str
    else
        return format
    end
end

-- case-insensitive pattern-matching 
--
-- print(("src/dadasd.C"):match(string.ipattern("sR[cd]/.*%.c", true)))
-- print(("src/dadasd.C"):match(string.ipattern("src/.*%.c", true)))
--
-- print(string.ipattern("sR[cd]/.*%.c"))
--   [sS][rR][cd]/.*%.[cC]
--
-- print(string.ipattern("sR[cd]/.*%.c", true))
--   [sS][rR][cCdD]/.*%.[cC]
--
function string.ipattern(pattern, brackets)
    local tmp = {}
    local i = 1
    while i <= #pattern do
        
        -- get current charactor
        local char = pattern:sub(i, i)

        -- escape?
        if char == '%' then
            tmp[#tmp + 1] = char
            i = i + 1
            char = pattern:sub(i,i)
            tmp[#tmp + 1] = char

            -- '%bxy'? add next 2 chars
            if char == 'b' then
                tmp[#tmp + 1] = pattern:sub(i + 1, i + 2)
                i = i + 2
            end
        -- brackets?
        elseif char == '[' then 
            tmp[#tmp + 1] = char
            i = i + 1
            while i <= #pattern do
                char = pattern:sub(i, i)
                if char == '%' then
                    tmp[#tmp + 1] = char
                    tmp[#tmp + 1] = pattern:sub(i + 1, i + 1)
                    i = i + 1
                elseif char:match("%a") then 
                    tmp[#tmp + 1] = not brackets and char or char:lower() .. char:upper()
                else 
                    tmp[#tmp + 1] = char
                end
                if char == ']' then break end 
                i = i + 1
            end
        -- letter, [aA]
        elseif char:match("%a") then
            tmp[#tmp + 1] = '[' .. char:lower() .. char:upper() .. ']'
        else
            tmp[#tmp + 1] = char
        end
        i = i + 1
    end
    return table.concat(tmp)
end

-- dump to string from the given object (more readable)
--
-- @param deflate       deflate empty characters
--
-- @return              string, errors
-- 
function string.dump(object, deflate)
    return string._makestr(object, deflate, false, 0)
end

-- serialize to string from the given object
--
-- @param deflate       deflate empty characters
--
-- @return              string, errors
-- 
function string.serialize(object, deflate)
    return string._makestr(object, deflate, true, 0)
end

-- deserialize string to object
--
-- @param str           the serialized string
--
-- @return              object, errors
-- 
function string:deserialize()

    -- load table as script
    local result = nil
    local script, errors = loadstring("return " .. self)
    if script then
        
        -- load object
        local ok, object = pcall(script)
        if ok and object then
            result = object
        elseif object then
            -- error
            errors = object
        else
            -- error
            errors = string.format("cannot deserialize string: %s", self)
        end
    end

    -- load function from string in table
    if result then
        result, errors = string._loadstr(result)
    end

    -- ok?
    return result, errors
end

-- return module: string
return string
