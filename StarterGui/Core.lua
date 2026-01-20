local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIPlantController = require(
	ReplicatedStorage:WaitForChild("Modules")
		:WaitForChild("Plants")
		:WaitForChild("UIPlantController")
)

local screenGui = script.Parent :: ScreenGui
local main = screenGui:WaitForChild("Main") :: Frame

UIPlantController.Start(main) -- inicialização do sistema de conexão da GUI

-- disable coregui
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)

-- ^ desativando alguns recursos nativos de GUI que n~~ao são nnecessários
