-- NPC Module for Roblox
-- Dialogue trees, waypoint pathing, and aggro/detection system
-- Usage: local NPC = require(game.ReplicatedStorage.Modules.NPC)

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local NPC = {}
NPC.__index = NPC

-- Create a new NPC controller
-- @param model: Model (the NPC model with a Humanoid and HumanoidRootPart)
-- @param config: { walkSpeed, aggroRange, loseRange, dialogues }
function NPC.new(model, config)
	local self = setmetatable({}, NPC)
	self.model = model
	self.humanoid = model:FindFirstChildOfClass("Humanoid")
	self.rootPart = model:FindFirstChild("HumanoidRootPart")
	self.config = config or {}
	self.walkSpeed = self.config.walkSpeed or 14
	self.aggroRange = self.config.aggroRange or 20
	self.loseRange = self.config.loseRange or 40
	self.dialogues = self.config.dialogues or {}
	self.waypoints = {}
	self.target = nil
	self.patrolIndex = 1
	self.isAggroed = false
	self._connections = {}

	if self.humanoid then
		self.humanoid.WalkSpeed = self.walkSpeed
	end

	return self
end

-- Set patrol waypoints (array of Vector3 or BasePart)
function NPC:setWaypoints(waypoints)
	self.waypoints = waypoints
end

-- Walk to a position using pathfinding
function NPC:walkTo(destination)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
	})

	local ok, err = pcall(function()
		path:ComputeAsync(self.rootPart.Position, destination)
	end)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		-- Fallback: walk directly
		self.humanoid:MoveTo(destination)
		return
	end

	for _, waypoint in ipairs(path:GetWaypoints()) do
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			self.humanoid.Jump = true
		end
		self.humanoid:MoveTo(waypoint.Position)
		local reached = self.humanoid.MoveToFinished:Wait(3)
		if not reached then break end
	end
end

-- Start patrol loop
function NPC:startPatrol()
	if #self.waypoints == 0 then return end

	task.spawn(function()
		while self.model.Parent do
			if not self.isAggroed then
				local wp = self.waypoints[self.patrolIndex]
				local dest = typeof(wp) == "Vector3" and wp or wp.Position
				self:walkTo(dest)
				self.patrolIndex = (self.patrolIndex % #self.waypoints) + 1
				task.wait(0.5)
			else
				task.wait(0.1)
			end
		end
	end)
end

-- Start aggro detection loop
-- @param getPlayers: optional function() -> {Player}
function NPC:startAggro(getPlayers)
	task.spawn(function()
		while self.model.Parent do
			local players = getPlayers and getPlayers() or game:GetService("Players"):GetPlayers()
			local closest, closestDist = nil, math.huge

			for _, player in ipairs(players) do
				local char = player.Character
				if char then
					local root = char:FindFirstChild("HumanoidRootPart")
					if root then
						local dist = (root.Position - self.rootPart.Position).Magnitude
						if dist < closestDist then
							closestDist = dist
							closest = { player = player, root = root, dist = dist }
						end
					end
				end
			end

			if closest then
				if closestDist <= self.aggroRange then
					self.isAggroed = true
					self.target = closest
					self:walkTo(closest.root.Position)
				elseif self.isAggroed and closestDist > self.loseRange then
					self.isAggroed = false
					self.target = nil
				end
			end

			task.wait(0.5)
		end
	end)
end

-- Trigger dialogue for a player
-- @param player: Player
-- @param dialogueId: string
-- @param showUI: function(player, lines) (your UI handler)
function NPC:triggerDialogue(player, dialogueId, showUI)
	local dialogue = self.dialogues[dialogueId]
	if not dialogue then return end
	if showUI then
		showUI(player, dialogue)
	end
end

-- Destroy NPC and clean up
function NPC:destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
	if self.model and self.model.Parent then
		self.model:Destroy()
	end
end

return NPC
