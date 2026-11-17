-- Shop Module for Roblox
-- In-game shop with MarketplaceService integration, product listing, and purchase handling
-- Usage: local Shop = require(game.ReplicatedStorage.Modules.Shop)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shop = {}
Shop.__index = Shop

-- Create a new Shop instance
-- @param config: { products: table, onPurchase: function }
function Shop.new(config)
	local self = setmetatable({}, Shop)
	self.products = {}
	self.onPurchase = config and config.onPurchase
	self.purchaseCallbacks = {}

	-- Register provided products
	if config and config.products then
		for _, product in ipairs(config.products) do
			self:addProduct(product)
		end
	end

	return self
end

-- Add a product to the shop
-- @param product: { id: string, name: string, price: number, assetId: number?, description: string? }
function Shop:addProduct(product)
	assert(product.id, "Product must have an id")
	assert(product.name, "Product must have a name")
	assert(product.price, "Product must have a price")
	self.products[product.id] = product
end

-- Remove a product from the shop
function Shop:removeProduct(id)
	self.products[id] = nil
end

-- Get all products as a list
-- @return table of products
function Shop:getProducts()
	local list = {}
	for _, product in pairs(self.products) do
		table.insert(list, product)
	end
	return list
end

-- Get a single product by id
function Shop:getProduct(id)
	return self.products[id]
end

-- Register a callback for when a product is purchased
-- @param productId: string
-- @param callback: function(player, product)
function Shop:onProductPurchased(productId, callback)
	self.purchaseCallbacks[productId] = callback
end

-- Prompt player to buy a Roblox Developer Product (uses real Robux)
-- @param player: Player
-- @param productId: number (Roblox Developer Product ID)
function Shop:promptDevProduct(player, productId)
	MarketplaceService:PromptProductPurchase(player, productId)
end

-- Prompt player to buy a Roblox Game Pass
-- @param player: Player
-- @param gamePassId: number
function Shop:promptGamePass(player, gamePassId)
	MarketplaceService:PromptGamePassPurchase(player, gamePassId)
end

-- Check if player owns a game pass
-- @param player: Player
-- @param gamePassId: number
-- @return boolean
function Shop:hasGamePass(player, gamePassId)
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)
	return ok and owns or false
end

-- Handle a virtual (in-game currency) purchase
-- @param player: Player
-- @param productId: string (your shop's product id)
-- @param getBalance: function(player) -> number
-- @param deductBalance: function(player, amount) -> boolean
-- @return success: boolean, message: string
function Shop:buyWithCurrency(player, productId, getBalance, deductBalance)
	local product = self.products[productId]
	if not product then
		return false, "Product not found"
	end

	local balance = getBalance(player)
	if balance < product.price then
		return false, "Not enough currency (need " .. product.price .. ", have " .. balance .. ")"
	end

	local ok = deductBalance(player, product.price)
	if not ok then
		return false, "Failed to deduct balance"
	end

	-- Fire purchase callback
	if self.purchaseCallbacks[productId] then
		self.purchaseCallbacks[productId](player, product)
	end
	if self.onPurchase then
		self.onPurchase(player, product)
	end

	return true, "Purchased " .. product.name
end

-- Setup server-side processing receipt handler for Developer Products
-- Call this ONCE on the server
-- @param handler: function(receiptInfo) -> Enum.ProductPurchaseDecision
function Shop.setupReceiptHandler(handler)
	MarketplaceService.ProcessReceipt = handler
end

return Shop
