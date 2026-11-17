-- Physics Module for Roblox
-- Cart and vehicle physics helpers: speed control, steering, boost, and suspension
-- Usage: local Physics = require(game.ReplicatedStorage.Modules.Physics)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Physics = {}
Physics.__index = Physics

-- Create a vehicle/cart physics controller
-- @param vehicle: Model with a VehicleSeat and wheels (HingeConstraints or VehicleSeat)
-- @param config: { maxSpeed, acceleration, turnSpeed, boostMultiplier, boostDuration }
function Physics.new(vehicle, config)
	local self = setmetatable({}, Physics)
	self.vehicle = vehicle
	self.seat = vehicle:FindFirstChildOfClass("VehicleSeat")
	self.config = config or {}
	self.maxSpeed = self.config.maxSpeed or 50
	self.acceleration = self.config.acceleration or 20
	self.turnSpeed = self.config.turnSpeed or 1.5
	self.boostMultiplier = self.config.boostMultiplier or 2
	self.boostDuration = self.config.boostDuration or 3
	self.isBoosting = false
	self.currentSpeed = 0
	self._connections = {}

	if self.seat then
		self.seat.MaxSpeed = self.maxSpeed
		self.seat.Torque = self.acceleration
		self.seat.TurnSpeed = self.turnSpeed
	end

	return self
end

-- Apply boost to the vehicle
-- Temporarily doubles max speed and acceleration
function Physics:boost()
	if self.isBoosting then return end
	if not self.seat then return end

	self.isBoosting = true
	local origMax = self.seat.MaxSpeed
	local origTorque = self.seat.Torque

	self.seat.MaxSpeed = origMax * self.boostMultiplier
	self.seat.Torque = origTorque * self.boostMultiplier

	task.delay(self.boostDuration, function()
		if self.seat and self.seat.Parent then
			self.seat.MaxSpeed = origMax
			self.seat.Torque = origTorque
		end
		self.isBoosting = false
	end)
end

-- Get current occupant of the vehicle
-- @return Player or nil
function Physics:getDriver()
	if not self.seat then return nil end
	local humanoid = self.seat.Occupant
	if not humanoid then return nil end
	local char = humanoid.Parent
	return Players:GetPlayerFromCharacter(char)
end

-- Eject the current driver
function Physics:ejectDriver()
	if not self.seat then return end
	self.seat.Disabled = true
	task.wait(0.1)
	self.seat.Disabled = false
end

-- Apply a force impulse to the vehicle (e.g. jump ramp, explosion knockback)
-- @param direction: Vector3
-- @param power: number
function Physics:applyImpulse(direction, power)
	local root = self.vehicle:FindFirstChild("HumanoidRootPart")
		or self.vehicle.PrimaryPart
		or self.seat
	if not root then return end
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = direction.Unit * power
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.P = 1e4
	bodyVelocity.Parent = root
	game:GetService("Debris"):AddItem(bodyVelocity, 0.2)
end

-- Teleport vehicle to a CFrame (safe reset)
-- @param cf: CFrame
function Physics:teleportTo(cf)
	local root = self.vehicle.PrimaryPart
	if not root then return end
	-- Zero out velocity first
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	self.vehicle:PivotTo(cf)
end

-- Lock/unlock vehicle movement
-- @param locked: boolean
function Physics:setLocked(locked)
	if not self.seat then return end
	self.seat.Disabled = locked
end

-- Check if vehicle is flipped (upside down)
-- @return boolean
function Physics:isFlipped()
	local root = self.vehicle.PrimaryPart or self.seat
	if not root then return false end
	local up = root.CFrame.UpVector
	return up.Y < -0.5
end

-- Auto-flip vehicle if upside down
-- @param interval: number (seconds between checks, default 2)
function Physics:enableAutoFlip(interval)
	interval = interval or 2
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not self.vehicle.Parent then
			conn:Disconnect()
			return
		end
		if self:isFlipped() then
			local root = self.vehicle.PrimaryPart or self.seat
			if root then
				local pos = root.Position
				task.wait(interval)
				if self:isFlipped() then
					self:teleportTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
				end
			end
		end
	end)
	table.insert(self._connections, conn)
end

-- Destroy and clean up
function Physics:destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	self._connections = {}
end

return Physics
