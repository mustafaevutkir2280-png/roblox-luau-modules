local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataStore = {}
DataStore.__index = DataStore

function DataStore.new(storeName, config)
	local self = setmetatable({}, DataStore)
	self.store = DataStoreService:GetDataStore(storeName)
	self.storeName = storeName
	self.retries = (config and config.retries) or 3
	self.retryDelay = (config and config.retryDelay) or 1
	self.cache = {}
	return self
end

function DataStore:retry(fn)
	local attempts = 0
	local success, result
	repeat
		attempts += 1
		success, result = pcall(fn)
		if not success then
			task.wait(self.retryDelay)
		end
	until success or attempts >= self.retries
	return success, result
end

function DataStore:load(userId)
	local key = tostring(userId)
	if self.cache[key] then
		return self.cache[key]
	end
	local success, data = self:retry(function()
		return self.store:GetAsync(key)
	end)
	if success then
		self.cache[key] = data
		return data
	end
	return nil
end

function DataStore:save(userId, data)
	local key = tostring(userId)
	self.cache[key] = data
	local success, err = self:retry(function()
		self.store:SetAsync(key, data)
	end)
	return success, err
end

function DataStore:update(userId, fn)
	local key = tostring(userId)
	local success, result = self:retry(function()
		return self.store:UpdateAsync(key, fn)
	end)
	if success then
		self.cache[key] = result
	end
	return success, result
end

function DataStore:getCached(userId)
	return self.cache[tostring(userId)]
end

function DataStore:delete(userId)
	local key = tostring(userId)
	self.cache[key] = nil
	local success, err = self:retry(function()
		self.store:RemoveAsync(key)
	end)
	return success, err
end

function DataStore:autoSaveOnLeave(userId, dataFn)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		player.AncestryChanged:Connect(function()
			if not player:IsDescendantOf(game) then
				local data = dataFn(userId)
				if data then
					self:save(userId, data)
				end
			end
		end)
	end
end

function DataStore:setupAutoSave(interval, dataFn)
	interval = interval or 60
	task.spawn(function()
		while true do
			task.wait(interval)
			for _, player in Players:GetPlayers() do
				local data = dataFn(player.UserId)
				if data then
					self:save(player.UserId, data)
				end
			end
		end
	end)
end

return DataStore
