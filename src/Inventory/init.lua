-- Inventory Module for Roblox
-- Provides a grid-based inventory system with stacks and weight limits
-- Usage: local Inventory = require(game.ReplicatedStorage.Modules.Inventory)

local Inventory = {}
Inventory.__index = Inventory

-- Create a new Inventory instance
-- @param player: Player instance
-- @param config: { maxSlots: number, maxWeight: number }
function Inventory.new(player, config)
	local self = setmetatable({}, Inventory)
	self.player = player
	self.maxSlots = config.maxSlots or 20
	self.maxWeight = config.maxWeight or 100
	self.items = {}
	self.totalWeight = 0
	return self
end

-- Add an item to the inventory
-- @param itemName: string
-- @param quantity: number
-- @param weight: number (weight per unit, default 1)
-- @return success: boolean, message: string
function Inventory:addItem(itemName, quantity, weight)
	quantity = quantity or 1
	weight = weight or 1

	local totalNewWeight = weight * quantity
	if self.totalWeight + totalNewWeight > self.maxWeight then
		return false, "Inventory is too heavy"
	end

	-- Check if item already exists (stack)
	for _, item in ipairs(self.items) do
		if item.name == itemName then
			item.quantity = item.quantity + quantity
			self.totalWeight = self.totalWeight + totalNewWeight
			return true, "Stacked"
		end
	end

	-- Check slot limit
	if #self.items >= self.maxSlots then
		return false, "Inventory is full"
	end

	-- Add new item
	table.insert(self.items, {
		name = itemName,
		quantity = quantity,
		weight = weight
	})
	self.totalWeight = self.totalWeight + totalNewWeight
	return true, "Added"
end

-- Remove an item from the inventory
-- @param itemName: string
-- @param quantity: number
-- @return success: boolean, message: string
function Inventory:removeItem(itemName, quantity)
	quantity = quantity or 1
	for i, item in ipairs(self.items) do
		if item.name == itemName then
			if item.quantity < quantity then
				return false, "Not enough items"
			end
			item.quantity = item.quantity - quantity
			self.totalWeight = self.totalWeight - (item.weight * quantity)
			if item.quantity <= 0 then
				table.remove(self.items, i)
			end
			return true, "Removed"
		end
	end
	return false, "Item not found"
end

-- Get all items
-- @return table of items
function Inventory:getItems()
	return self.items
end

-- Check if inventory has an item
-- @param itemName: string
-- @param quantity: number
-- @return boolean
function Inventory:hasItem(itemName, quantity)
	quantity = quantity or 1
	for _, item in ipairs(self.items) do
		if item.name == itemName and item.quantity >= quantity then
			return true
		end
	end
	return false
end

-- Get current weight and max weight
-- @return currentWeight, maxWeight
function Inventory:getWeight()
	return self.totalWeight, self.maxWeight
end

-- Clear all items
function Inventory:clear()
	self.items = {}
	self.totalWeight = 0
end

return Inventory
