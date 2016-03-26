require "Apollo"
require "ChatSystemLib"

local MAJOR, MINOR = "Jos_eu:DevTools-1.3", 1
local _pkg = Apollo.GetPackage(MAJOR)
if _pkg and (_pkg.nVersion or 0) >= MINOR then
	return -- no upgrade is needed
end
local Lib = _pkg and _pkg.tPackage or {}

Lib.nVersion = MINOR

local type, tostring, tonumber, string = type, tostring, tonumber, string
local strfind, strsub, strrep, strlen, strformat = string.find, string.sub, string.rep, string.len, string.format
local getmetatable, pairs, select = getmetatable, pairs, select

local t2s, o2s, mt2s, explode, PrintObj, SPrint, CPrint, ColorToHex, DicSize, CopyTable

function Lib:OnLoad()
end

function Lib:OnDependencyError(strDep, strError)
  return false
end

t2s =  function (tbl, depth, indent)
  if not depth then depth = 1 end
	if not indent then indent = 0 end
	local formatting = strrep("  ", indent)
	local result = ""
  for k, v in pairs(tbl) do
    result = result..formatting..k .. ": "..o2s(v, depth-1, indent+1).."\n"
  end
	return result
end

mt2s =  function (tbl, depth, indent)
  if not depth then depth = 1 end
	if not indent then indent = 0 end
	local formatting = strrep("  ", indent)
	local result = ""
  for k, v in pairs(getmetatable(tbl)) do
    result = result..formatting..k .. ": "..o2s(v, depth-1, indent+1).."\n"
  end
	return result
end
 
o2s = function (obj, depth, indent)
	if not depth then depth = 1 end
	if not indent then indent = 0 end
	local result = ""
	if obj then
		if type(obj) == 'userdata' then
			result = result..tostring(obj)
			if depth > 0 then
				result = result.."\n"..mt2s(obj, depth-1, indent+1)
			end
		elseif type(obj) == 'table' then
			result = result..tostring(obj)
			if depth > 0 then
				result = result.."\n"..t2s(obj, depth-1, indent+1)
			end
		else
			local s = tostring(obj)
			if strlen(s) > 20 then
				result = result..strsub(s, 1, 50).."..."
			else
				result = result..s
			end
		end
	else
		result = result.."nil"
	end
	return result
end

explode = function(str, sep, limit)
	if not sep or sep == "" then return false end
	if not str then return false end
	limit = limit or 2048
	if limit == 0 or limit == 1 then return {str},1 end

	local r = {}
	local n, init = 0, 1

	while true do
		local s,e = strfind(str, sep, init, true)
		if not s then break end
		r[#r+1] = strsub(str, init, s - 1)
		init = e + 1
		n = n + 1
		if n == limit - 1 then break end
	end

	if init <= strlen(str) then
		r[#r+1] = strsub(str, init)
	else
		r[#r+1] = ""
	end
	n = n + 1

	if limit < 0 then
		for i=n, n + limit + 1, -1 do r[i] = nil end
		n = n + limit
	end

	return r, n
end

SPrint = function(...)
	Print(strformat(select(1, ...)))
end

PrintObj = function(obj, depth)
	Print(o2s(obj, depth))
end

CPrint = function(strMessage)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, strMessage, "")
end

ColorToHex = function(objColor, nDefault)
	local r, g, b
	if objColor then
		if type(objColor)=="userdata" then
			local tColor = objColor:ToTable()
			r, g, b =  tColor.r, tColor.g , tColor.b
		elseif type(objColor)=="table" then
			r, g, b =  objColor.r, objColor.g , objColor.b
		end
		r = r or 0;
		g = g or 0;
		b = b or 0;
		return tonumber(strformat("0x%02x%02x%02x", r * 255, g * 255, b * 255),16)
	end
	return nDefault or 0xffffff
end

DicSize = function(dic)
	local i = 0
	for _,_ in pairs(dic) do
		i = i + 1
	end
	return i
end

CopyTable = function (t)
  local t2 = {}
  if type(t) ~= "table" then
    return t
  end
  for k,v in pairs(t) do
    t2[k] = CopyTable(v)
  end
  return t2
end

Lib.t2s = t2s
Lib.o2s = o2s
Lib.mt2s = mt2s
Lib.explode = explode
Lib.PrintObj = PrintObj
Lib.SPrint = SPrint
Lib.CPrint = CPrint
Lib.ColorToHex = ColorToHex
Lib.DicSize = DicSize
Lib.CopyTable = CopyTable

Apollo.RegisterPackage(Lib, MAJOR, MINOR, {})
