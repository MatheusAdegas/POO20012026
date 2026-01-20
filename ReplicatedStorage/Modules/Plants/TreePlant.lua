local Plant = require(script.Parent.Plant)

local TreePlant = {}
TreePlant.__index = TreePlant
setmetatable(TreePlant, Plant)

function TreePlant.new(data)
	local base = Plant._newBase(data)
	return setmetatable(base, TreePlant)
end

function TreePlant:GetType(): string
	return "Árvore"
end

return TreePlant