-- DataStore Module for Roblox
-- Wraps DataStoreService with auto-retry, versioning, and player data management
-- Usage: local DataStore = require(game.ReplicatedStorage.Modules.DataStore)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataStore = {}
DataStore.__index = DataStore

local DEFAULT_RETRIES = 3
local RETRY_DELAY = 1

-- Create a new DataStore instance
-- @param storeName: string (name of the DataStore)
-- @param config: { retries: number, retryDelay: number }
function DataStore.new(storeName, config)
	local self = setmetatable({}, DataStore)
	self.store = DataStoreService:GetDataStore(storeName)
	self.storeName = storeName
	self.retries = (config and config.retries) or DEFAULT_RETRIES
	self.retryDelay = (config and config.retryDelay) or RETRY_DELAY
	self.cache = {}
	return self
end

-- Internal: retry a function N times
local function retry(fn, retries, delay)
	for i = 1, retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if i < retries then
			task.wait(delay)
		end
	end
	return false, nil
end

-- Load player data
-- @param player: Player or userId: number
-- @param default: table (default data if none found)
-- @return success: boolean, data: table
function DataStore:load(player, default)
	local key = typeof(player) == "Instance" and tostring(player.UserId) or tostring(player)

	local ok, data = retry(function()
		return self.store:GetAsync(key)
	end, self.retries, self.retryDelay)

	if ok then
		local result = data or default or {}
		self.cache[key] = result
		return true, result
	end
	return false, default or {}
end

-- Save player data
-- @param player: Player or userId: number
-- @param data: table
-- @return success: boolean
function DataStore:save(player, data)
	local key = typeof(player) == "Instance" and tostring(player.UserId) or tostring(player)

	local ok = retry(function()
		self.store:SetAsync(key, data)
	end, self.retries, self.retryDelay)

	if ok then
		self.cache[key] = data
	end
	return ok
end

-- Update player data with a transform function
-- @param player: Player or userId: number
-- @param transform: function(oldData) -> newData
-- @return success: boolean
function DataStore:update(player, transform)
	local key = typeof(player) == "Instance" and tostring(player.UserId) or tostring(player)

	local ok = retry(function()
		self.store:UpdateAsync(key, function(old)
			return transform(old or {})
		end)
	end, self.retries, self.retryDelay)

	return ok
end

-- Get cached data (no DataStore call)
-- @param player: Player or userId: number
-- @return data: table or nil
function DataStore:getCached(player)
	local key = typeof(player) == "Instance" and tostring(player.UserId) or tostring(player)
	return self.cache[key]
end

-- Auto-save on player leaving
-- @param player: Player
function DataStore:autoSaveOnLeave(player)
	local data = self:getCached(player)
	if data then
		self:save(player, data)
	end
end

-- Setup auto-save for all players
-- Call this once on server script
function DataStore:setupAutoSave()
	Players.PlayerRemoving:Connect(function(player)
		self:autoSaveOnLeave(player)
	end)
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			self:autoSaveOnLeave(player)
		end
	end)
end

-- Delete player data
-- @param player: Player or userId: number
-- @return success: boolean
function DataStore:delete(player)
	local key = typeof(player) == "Instance" and tostring(player.UserId) or tostring(player)
	local ok = retry(function()
		self.store:RemoveAsync(key)
	end, self.retries, self.retryDelay)
	if ok then
		self.cache[key] = nil
	end
	return ok
end

return DataStore
