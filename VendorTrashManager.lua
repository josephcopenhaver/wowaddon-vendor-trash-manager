-- standard lua function imports
local select = select
local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local print = print
local format = format


-- standard lua module imports
local math = math
local table = table


-- wow lua function imports
local CreateFrame = CreateFrame
local GetItemInfo = GetItemInfo
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemLink = GetContainerItemLink
local UseContainerItem = UseContainerItem
local GetContainerItemInfo = GetContainerItemInfo


-- wow lua constant imports
local GOLD_AMOUNT_TEXTURE = GOLD_AMOUNT_TEXTURE
local SILVER_AMOUNT_TEXTURE = SILVER_AMOUNT_TEXTURE
local COPPER_AMOUNT_TEXTURE = COPPER_AMOUNT_TEXTURE


-- constants
local FMT_MONEY = GOLD_AMOUNT_TEXTURE.." "..SILVER_AMOUNT_TEXTURE.." "..COPPER_AMOUNT_TEXTURE


local newClass = function(className)
	if not className then
		className ="unknown"
	end
	
	local class = {

		__class_name = className,

		new = function(self, obj)
			if not obj then
				obj = {}
			end
		
			setmetatable(obj, self)
		
			return obj
		end,
	}

	class.__index = class

	return class
end


local VTM = newClass("VendorTrashManager")

function VTM:init()
	local frame = CreateFrame("Frame")

	self.addonName = "VendorTrashManager"
	self.addonSlashCommand = "/vtm"
	self.version = "1"
	self.frame = frame
	self.eventHandlers = {}

	self:registerEventHandler("ADDON_LOADED", self.onAddonLoaded)

	frame:SetScript("OnEvent", function(_, ...) self:onEvent(...) end)

	return self
end

function VTM:registerSlash()
	local addonSlashName = "VENDOR_TRASH_MANAGER"

	_G["SLASH_"..addonSlashName.."1"] = self.addonSlashCommand
	_G["SlashCmdList"][addonSlashName] = function(...) self:onSlash(...) end
end

function VTM:isGrey(item)
	return (select(3, GetItemInfo(item)) == 0)
end

function VTM:getItemId(item)
	local link = select(2, GetItemInfo(item))
	if not link then
		return nil
	end

	local id = link:match("item:(%d+):")
	if not id then
		return nil
	end

	return tonumber(id)
end

function VTM:registerEventHandler(name, handler)
	local eventHandlers = self.eventHandlers
	local handlers = eventHandlers[name]
	if handlers == nil then
		handlers = {}
		eventHandlers[name] = handlers
	end

	table.insert(handlers, handler)
	self.frame:RegisterEvent(name)
end

function VTM:onEvent(event, ...)
	local handlers = self.eventHandlers[event]
	if handlers == nil then
		return
	end

	for _, handler in ipairs(handlers) do
		handler(self, ...)
	end
end

function VTM:onAddonLoaded(name)
	if name ~= self.addonName then
		return
	end

	local savedVariablePerCharacter = "VendorTrashManager_PlayerState"

	local state = _G[savedVariablePerCharacter]

	if not state or state.version ~= self.version then
		state = {}
		_G[savedVariablePerCharacter] = state
		state.version = self.version
	end

	if not state.keep then
		state.keep = {}
	end

	if not state.sell then
		state.sell = {}
	end

	self.state = state

	self:registerSlash()
	self:registerEventHandler("MERCHANT_SHOW", self.onMerchantShow)
end

function VTM:showSlashUsage()
	print("commands should be formatted:")
	print(self.addonSlashCommand.." <sell | keep | debug> <itemlink>")
end

function VTM:onSlash(msg)
	local cmd, item = msg:match("(%w+)(.+)")

	-- trim whitespace
	item = (item:gsub("^%s*(.-)%s*$", "%1"))
	local id = self:getItemId(item)

	if cmd == "sell" or cmd == "keep" then
		if not id then
			print("not an item-link: "..item)
			self:showSlashUsage()
			return
		end
		if self:getItemValue(item) <= 0 then
			print("item cannot be sold")
			return
		end
	end

	local state = self.state

	if cmd == "sell" then
		if self:isGrey(item) then
			state.keep[id] = nil
		else
			state.sell[id] = true
		end
	elseif cmd == "keep" then
		if self:isGrey(item) then
			state.keep[id] = true
		else
			state.sell[id] = nil
		end
	elseif cmd == "debug" then
		print("ItemID: "..self:getItemId(item))
		print("IsGrey: "..tostring(self:isGrey(item)))
		print("ItemValue: "..self:formatMoney(self:getItemValue(item)))
		print("AutoSell: "..tostring(self:isVendorTrashItem(item)))
	else
		print("NOT handled: "..msg)
		self:showSlashUsage()
		return
	end

	print("handled: "..msg)
end

function VTM:onMerchantShow()
	-- sell the trash items and print expected earnings

	local total = 0
	for bag = 0, 4 do
		total = total + self:sellTrashInBag(bag)
	end

	if total > 0 then
		print("Sold trash items for : "..self:formatMoney(total))
	end
end
	
function VTM:sellTrashInBag(bag)
	local total = 0
	local numSlots = GetContainerNumSlots(bag)

	if numSlots <= 0 then
		return total
	end
	
	for slot = 1, numSlots do
		local item = GetContainerItemLink(bag, slot)
		if self:isVendorTrashItem(item) then
			total = total + (self:getItemValue(item) * self:getItemStackCount(bag, slot))
			UseContainerItem(bag, slot)
		end
	end

	return total
end
	
function VTM:isVendorTrashItem(item)
	if not item then
		return false
	end

	local id = self:getItemId(item)

	if not id then
		return false
	end

	if self:getItemValue(item) <= 0 then
		return false
	end

	local state = self.state

	if self:isGrey(item) then
		return (state.keep[id] == nil)
	end
	
	return (state.sell[id] ~= nil)
end
	
function VTM:getItemValue(item)
	return select(11, GetItemInfo(item))
end
	
function VTM:getItemStackCount(bag, slot)
	return select(2, GetContainerItemInfo(bag, slot))
end
	
function VTM:formatMoney(copper)
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	copper = (copper % 10000) % 100
	
	return format(FMT_MONEY, gold, 0, 0, silver, 0, 0, copper, 0, 0)
end

VTM:new():init()
