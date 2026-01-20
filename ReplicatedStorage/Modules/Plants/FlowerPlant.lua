local Plant = require(script.Parent.Plant)

local FlowerPlant = {}
FlowerPlant.__index = FlowerPlant
setmetatable(FlowerPlant, Plant)

function FlowerPlant.new(data)
	local base = Plant._newBase(data)
	return setmetatable(base, FlowerPlant)
end

function FlowerPlant:GetType(): string
	return "Flor"
end

return FlowerPlant
