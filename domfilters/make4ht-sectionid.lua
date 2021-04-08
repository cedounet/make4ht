local domfilter = require "make4ht-domfilter"
local mkutils   = require "mkutils"
-- Unicode data distributed with TeX
-- defines "characters" table
require "char-def"
local chardata = characters.data or {}

local log = logging.new("tocid")

local toc = nil

local function is_letter(info)
  -- test if character is letter
  local category = info.category or ""
  return category:match("^l") 
end

local function is_space(info)
  local category = info.category or ""
  return category == "zs"
end

local uchar = utf8.char
local function normalize_letter(char, result)
  local info = chardata[char] or {}
  -- first get lower case of the letter
  local lowercase = info.lccode or char
  -- remove accents. the base letter is in the shcode field
  local lowerinfo = chardata[lowercase] or {}
  -- when no shcode, use the current lowercase char
  local shcode = lowerinfo.shcode or lowercase
  -- shcode can be table if it contains multiple characters
  -- normaliz it to a table, so we can add all letters to 
  -- the resulting string
  if type(shcode) ~= "table" then shcode = {shcode} end
  for _, x in ipairs(shcode) do
    result[#result+1] = uchar(x)
  end
end

local escape_name = function(name)
  local result = {}
  for _,char in utf8.codes(name) do
    local info = chardata[char] or {}
    if is_space(info) then
      result[#result+1] = " "
    elseif is_letter(info) then
      normalize_letter(char, result)
    end
  end
  --- convert table with normalized characters to string
  local name = table.concat(result)
  -- remove spaces
  return name:gsub("%s+", "-")
end

local function parse_toc_line(line)
  -- the section ids and titles are saved in the following format:
  -- \csname a:TocLink\endcsname{1}{x1-20001}{QQ2-1-2}{Nazdar světe}
  -- ............................... id ................. title ...
  local id, name = line:match("a:TocLink.-{.-}{(.-)}{.-}{(.-)}")
  if id then
    return id, escape_name(name)
  end
end


local function parse_toc(filename)
  local toc, used = {}, {}
  if not mkutils.file_exists(filename) then return nil, "Cannot open TOC file "  .. filename end
  for line in io.lines(filename) do
    local id, name = parse_toc_line(line)
    print(id,name)
    -- not all lines in the .4tc file contains TOC entries
    if id then
      -- test if the same name was used already. user should be notified
      if used[name] then
        log:warning("Duplicate id used")
      end
      used[name] = true
      toc[id] = name
    end
  end
  return toc
  
end


    

local process = domfilter{
  function(dom, par)
    local msg
    toc, msg = toc or parse_toc(par.input .. ".4tc")
    msg = msg or "Cannot load TOC"
    if not toc then log:warning(msg) end
    -- process all elements with id atribute or <a href>
    for _, el in ipairs(dom:query_selector "[id],a[href]") do
      -- print(el:get_element_name(), el:get_attribute("id"), el:get_attribute("href"))
      local id, href = el:get_attribute("id"), el:get_attribute("href") 
      if id then
        -- replace id with new section id
        local name = toc[id]
        if name then
          el:set_attribute("id", name)
        end
      elseif href then
        -- replace links to sections with new id
        local base, anchor = href:match("^(.*)%#(.+)")
        local name = toc[anchor]
        if name then
          el:set_attribute("href", base .. "#" .. name)
        end
      end
    end
    return dom
  end

}

Make:match("html$", process)

