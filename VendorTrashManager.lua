-- standard lua function imports
local select = select
local tostring = tostring
local string = string
local tonumber = tonumber
local math = math
local ipairs = ipairs
local pairs = pairs
local table = table
local print = print
local format = format

-- wow lua function imports
local CreateFrame = CreateFrame
local GetItemInfo = GetItemInfo
local GetContainerNumSlots = GetContainerNumSlots
local GetContainerItemLink = GetContainerItemLink
local UseContainerItem = UseContainerItem
local GetContainerItemInfo = GetContainerItemInfo


local newClass = function(className)
	if not className then
		className ="unknown"
	end
	
	local class = {

		__class_name = className,

		new = function(self, obj, options)
			if not obj then
				obj = {}
			end
		
			setmetatable(obj, self)
		
			if (not options or not options.noinit) and type(obj.init) == "function" then
				obj:init()
			end
		
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
		state.version = self.version
	end

	if not state.keep then
		state.keep = {}
	end

	if not state.sell then
		state.sell = {}
	end

	self.state = state
	_G[savedVariablePerCharacter] = state

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
		if not (self:getItemValue(item) > 0) then
			print("item cannot be sold")
			self:showSlashUsage()
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
        local itemValue = self:getItemValue(item)
        local isGrey = self:isGrey(item)

        local autoSell = false
        if itemValue > 0 then
            if isGrey then
                autoSell = (state.keep[id] == nil)
            else
                autoSell = (state.sell[id] ~= nil)
            end
        end

        print("ItemID: "..self:getItemId(item))
		print("IsGrey: "..tostring(isGrey))
		print("ItemValue: "..itemValue)
		print("AutoSell: "..tostring(autoSell))
	else
		print("NOT handled: "..msg)
		self:showSlashUsage()
		return
	end

	print("handled: "..msg)
end

function VTM:SellTrash()
	local totalValue = 0
	for bag = 0, 4 do
		totalValue = totalValue + self:SellTrashInBag(bag)
	end

	if (totalValue > 0) then
		print("Sold trash items for : "..self:getFormattedTrashValue(totalValue))
	end
end

VTM.onMerchantShow = VTM.SellTrash
	
function VTM:SellTrashInBag(bag)
	if GetContainerNumSlots(bag) == 0 then
		return 0
	end
	
	local bagTrashValue = 0
	for slot = 1, GetContainerNumSlots(bag) do
		local itemLink = GetContainerItemLink(bag, slot)
		if self:isTrashItem(itemLink) then
			UseContainerItem(bag, slot)
			local itemValue = self:getItemValue(itemLink)
			local count = self:getItemStackCount(bag, slot)
			bagTrashValue = bagTrashValue + (itemValue * count)
		end
	end

	return bagTrashValue
end
	
function VTM:isTrashItem(item)
	if not item then
		return false
	end

	local id = self:getItemId(item)

	if not id then
		return false
	end

	local state = self.state

	if self:isGrey(item) then
		return (state.keep[id] == nil)
	else
		return (state.sell[id] ~= nil)
	end
end
	
function VTM:getItemValue(item)
	return select(11, GetItemInfo(item))
end
	
function VTM:getItemStackCount(bag, slot)
	return select(2, GetContainerItemInfo(bag, slot))
end
	
function VTM:getFormattedTrashValue(copper)
	local gold = math.floor(copper / 10000)
	local silver = math.floor((copper % 10000) / 100)
	copper = (copper % 10000) % 100
	
	return format(GOLD_AMOUNT_TEXTURE.." "..SILVER_AMOUNT_TEXTURE.." "..COPPER_AMOUNT_TEXTURE, gold, 0, 0, silver, 0, 0, copper, 0, 0)
end

VTM:new()
