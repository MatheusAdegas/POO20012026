local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local PlantLibrary = require(script.Parent.PlantLibrary)

type TriState = "Qualquer" | "Sim" | "Nao"
type ClassFilter = "Qualquer" | "Briofitas" | "Pteridofitas" | "Gimnospermas" | "Angiospermas"

type FilterState = {
	biomas: {[string]: boolean},
	regioes: {[string]: boolean},
	flores: TriState,
	frutos: TriState,
	classificacao: ClassFilter,
}

type MapMode = "Nenhum" | "Regioes" | "Biomas"

type ControllerState = {
	main: Frame,
	searchBar: TextBox,
	lista: ScrollingFrame,
	template: TextButton,
	mostrando: TextLabel?,
	trocarMapa: TextButton?,
	lib: any,
	activeClones: {GuiObject},
	pendingToken: number,
	filters: FilterState,
	clickableModels: {[string]: {kind: "bioma"|"regiao", keyNorm: string, label: string}},
	mapMode: MapMode,

	cameraStart: BasePart?,
	cameraBasePos: Vector3?,
	cameraConn: RBXScriptConnection?,
}

local UIPlantController = {}

-- =========================
-- Normalização (sem acento)
-- =========================
local function stripAccents(s: string): string
	s = s:gsub("[ÁÀÂÃÄ]", "a")
	s = s:gsub("[áàâãä]", "a")
	s = s:gsub("[ÉÈÊË]", "e")
	s = s:gsub("[éèêë]", "e")
	s = s:gsub("[ÍÌÎÏ]", "i")
	s = s:gsub("[íìîï]", "i")
	s = s:gsub("[ÓÒÔÕÖ]", "o")
	s = s:gsub("[óòôõö]", "o")
	s = s:gsub("[ÚÙÛÜ]", "u")
	s = s:gsub("[úùûü]", "u")
	s = s:gsub("[Ç]", "c")
	s = s:gsub("[ç]", "c")
	return s
end

local function normalize(s: string): string
	s = string.lower(s or "")
	s = stripAccents(s)
	s = s:gsub("_", " ")
	s = s:gsub("%s+", " ")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

-- =========================
-- UI list helpers
-- =========================
local function clearList(state: ControllerState)
	for _, obj in ipairs(state.activeClones) do
		if obj and obj.Parent then obj:Destroy() end
	end
	table.clear(state.activeClones)
end

local function ensureUIListLayout(lista: ScrollingFrame)
	local existing = lista:FindFirstChildOfClass("UIListLayout")
	if existing then return existing end
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = lista
	return layout
end

local function render(state: ControllerState, plants: {any})
	clearList(state)

	for _, plant in ipairs(plants) do
		local card = plant:ToCardModel()

		local btn = state.template:Clone()
		btn.Name = "Planta_" .. card.id
		btn.Visible = true
		btn.Parent = state.lista

		btn:WaitForChild("Regi").Text = card.regioes
		btn:WaitForChild("Nome").Text = card.nomePopular
		btn:WaitForChild("NomeSci").Text = card.nomeCientifico
		btn:WaitForChild("Bioma").Text = card.bioma
		btn:WaitForChild("Class").Text = card.classificacao

		local flores = btn:WaitForChild("Flores") :: TextLabel
		local frutos = btn:WaitForChild("Frutos") :: TextLabel
		flores.Text = card.temFlores and "Sim" or "Não"
		frutos.Text = card.temFrutos and "Sim" or "Não"

		btn.MouseButton1Click:Connect(function()
			state.searchBar.Text = card.nomeCientifico
		end)

		table.insert(state.activeClones, btn)
	end
end

-- =========================
-- Mostrando label
-- =========================
local function formatFilters(state: ControllerState): string
	-- FIX: mapMode é string
	local mapLabel = state.mapMode

	local biomes = {}
	for _, meta in pairs(state.clickableModels) do
		if meta.kind == "bioma" and state.filters.biomas[meta.keyNorm] then
			table.insert(biomes, meta.label)
		end
	end

	local regions = {}
	for _, meta in pairs(state.clickableModels) do
		if meta.kind == "regiao" and state.filters.regioes[meta.keyNorm] then
			table.insert(regions, meta.label)
		end
	end

	table.sort(biomes)
	table.sort(regions)

	local parts = {("Mapa: %s"):format(mapLabel)}
	if #biomes > 0 then table.insert(parts, "Biomas: " .. table.concat(biomes, ", ")) end
	if #regions > 0 then table.insert(parts, "Regiões: " .. table.concat(regions, ", ")) end

	-- Tri-state: mostrar somente se não for "Qualquer"
	if state.filters.flores ~= "Qualquer" then
		table.insert(parts, ("Flores: %s"):format(state.filters.flores == "Sim" and "Sim" or "Não"))
	end
	if state.filters.frutos ~= "Qualquer" then
		table.insert(parts, ("Frutos: %s"):format(state.filters.frutos == "Sim" and "Sim" or "Não"))
	end
	
	if state.filters.classificacao ~= "Qualquer" then
		local label = state.filters.classificacao
		table.insert(parts, "Classificação: " .. label)
	end

	if #biomes == 0 and #regions == 0 and state.filters.flores == "Qualquer" and state.filters.frutos == "Qualquer" and state.filters.classificacao == "Qualquer" then
		table.insert(parts, "sem filtros")
	end

	return "Mostrando: " .. table.concat(parts, " | ")
end

local function updateMostrando(state: ControllerState)
	if state.mostrando then
		state.mostrando.Text = formatFilters(state)
	end
end

-- =========================
-- Search + Filters
-- =========================
local function applySearchAndFilters(state: ControllerState)
	state.pendingToken += 1
	local token = state.pendingToken

	task.delay(0.12, function()
		if token ~= state.pendingToken then return end

		local q = state.searchBar.Text or ""
		local results = state.lib:Search(q)

		local filtered = {}
		for _, plant in ipairs(results) do
			if plant:MatchesFilters(state.filters) then
				table.insert(filtered, plant)
			end
		end

		render(state, filtered)
		updateMostrando(state)
	end)
end

-- =========================
-- Clickable map: MeshParts + ClickDetector
-- =========================
local function buildClickableMap(): {[string]: {kind: "bioma"|"regiao", keyNorm: string, label: string}}
	local regionNameToCode = {
		["centro-oeste"] = "co",
		["nordeste"] = "ne",
		["sudeste"] = "se",
		["sul"] = "s",
		["norte"] = "n",
	}

	return {
		-- Biomas
		[normalize("cerrado")] = { kind = "bioma", keyNorm = normalize("Cerrado"), label = "Cerrado" },
		[normalize("mata atlantica")] = { kind = "bioma", keyNorm = normalize("Mata Atlântica"), label = "Mata Atlântica" },
		[normalize("pantanal")] = { kind = "bioma", keyNorm = normalize("Pantanal"), label = "Pantanal" },
		[normalize("pampa")] = { kind = "bioma", keyNorm = normalize("Pampa"), label = "Pampa" },
		[normalize("caatinga")] = { kind = "bioma", keyNorm = normalize("Caatinga"), label = "Caatinga" },
		[normalize("amazonia")] = { kind = "bioma", keyNorm = normalize("Amazônia"), label = "Amazônia" },

		-- Regiões
		[normalize("centro-oeste")] = { kind = "regiao", keyNorm = normalize(regionNameToCode["centro-oeste"]), label = "CO" },
		[normalize("nordeste")] = { kind = "regiao", keyNorm = normalize(regionNameToCode["nordeste"]), label = "NE" },
		[normalize("sudeste")] = { kind = "regiao", keyNorm = normalize(regionNameToCode["sudeste"]), label = "SE" },
		[normalize("sul")] = { kind = "regiao", keyNorm = normalize(regionNameToCode["sul"]), label = "S" },
		[normalize("norte")] = { kind = "regiao", keyNorm = normalize(regionNameToCode["norte"]), label = "N" },
	}
end

local function toggleFilter(state: ControllerState, meta)
	-- Respeitar mapa atual
	if state.mapMode == "Nenhum" then return end
	if state.mapMode == "Regioes" and meta.kind ~= "regiao" then return end
	if state.mapMode == "Biomas" and meta.kind ~= "bioma" then return end

	if meta.kind == "bioma" then
		local v = not state.filters.biomas[meta.keyNorm]
		if v then state.filters.biomas[meta.keyNorm] = true else state.filters.biomas[meta.keyNorm] = nil end
	else
		local v = not state.filters.regioes[meta.keyNorm]
		if v then state.filters.regioes[meta.keyNorm] = true else state.filters.regioes[meta.keyNorm] = nil end
	end
end

local function hookClickDetectors(state: ControllerState)
	local localPlayer = Players.LocalPlayer
	local connected: {[Instance]: boolean} = {}

	local function tryBind(cd: Instance)
		if connected[cd] then return end
		if not cd:IsA("ClickDetector") then return end

		local parent = cd.Parent
		if not parent or not parent:IsA("BasePart") then return end

		local key = normalize(parent.Name)
		local meta = state.clickableModels[key]
		if not meta then return end

		connected[cd] = true

		(cd :: ClickDetector).MouseClick:Connect(function(playerWhoClicked)
			if playerWhoClicked ~= localPlayer then return end

			toggleFilter(state, meta)
			applySearchAndFilters(state)
		end)
	end

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("ClickDetector") then
			tryBind(inst)
		end
	end

	Workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("ClickDetector") then
			tryBind(inst)
		end
	end)
end

-- =========================
-- Player movement lock
-- =========================
local function disablePlayerMovement()
	local player = Players.LocalPlayer

	local function applyToCharacter(char: Model)
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.AutoRotate = false
		end

		local ps = player:WaitForChild("PlayerScripts")
		local pm = ps:WaitForChild("PlayerModule")
		local controls = require(pm):GetControls()
		controls:Disable()
	end

	if player.Character then
		applyToCharacter(player.Character)
	end
	player.CharacterAdded:Connect(applyToCharacter)
end

-- =========================
-- Camera lock + map cycling
-- =========================
local MAP_Z_STEP = 50

local function mapIndex(mode: MapMode): number
	if mode == "Nenhum" then return 0 end
	if mode == "Regioes" then return 1 end
	return 2
end

local function setCameraForMap(state: ControllerState)
	local cam = Workspace.CurrentCamera
	if not cam then return end
	if not state.cameraBasePos then return end

	local idx = mapIndex(state.mapMode)
	local offset = Vector3.new(0, 0, MAP_Z_STEP * idx)
	local pos = state.cameraBasePos + offset

	local lookTarget = pos - Vector3.new(0, 1, 0)
	cam.CFrame = CFrame.lookAt(pos, lookTarget)
	cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(-90))
end

local function lockCamera(state: ControllerState)
	local camStart = Workspace:FindFirstChild("CameraStart")
	if not camStart or not camStart:IsA("BasePart") then
		warn("CameraStart não encontrado ou não é BasePart.")
		return
	end

	state.cameraStart = camStart
	state.cameraBasePos = camStart.Position

	local cam = Workspace.CurrentCamera
	if not cam then return end

	cam.CameraType = Enum.CameraType.Scriptable

	if state.cameraConn then state.cameraConn:Disconnect() end
	state.cameraConn = RunService.RenderStepped:Connect(function()
		setCameraForMap(state)
	end)

	setCameraForMap(state)
end

local function updateTrocarMapaButton(state: ControllerState)
	if not state.trocarMapa then return end
	state.trocarMapa.Text = ("TrocarMapa: %s"):format(state.mapMode)
end

local function hookTrocarMapa(state: ControllerState)
	if not state.trocarMapa then return end

	updateTrocarMapaButton(state)

	local function nextMapMode(mode: MapMode): MapMode
		if mode == "Nenhum" then return "Regioes" end
		if mode == "Regioes" then return "Biomas" end
		return "Nenhum"
	end

	state.trocarMapa.MouseButton1Click:Connect(function()
		state.mapMode = nextMapMode(state.mapMode)

		updateTrocarMapaButton(state)
		setCameraForMap(state)
		applySearchAndFilters(state)
	end)
end

-- =========================
-- Start
-- =========================
function UIPlantController.Start(main: Frame)
	local searchBar = main:WaitForChild("SearchBar") :: TextBox
	local lista = main:WaitForChild("Lista") :: ScrollingFrame
	local template = lista:WaitForChild("Planta") :: TextButton
	template.Visible = false

	local layout = ensureUIListLayout(lista)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		lista.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
	end)

	local parentGui = main.Parent
	local mostrando: TextLabel? = nil
	local trocarMapa: TextButton? = nil
	local filtroFloresBtn: GuiButton? = nil
	local filtroFrutosBtn: GuiButton? = nil
	local filtroClassBtn: GuiButton? = nil

	if parentGui and parentGui:IsA("ScreenGui") then
		local m = parentGui:FindFirstChild("Mostrando")
		if m and m:IsA("TextLabel") then mostrando = m end

		local t = parentGui:FindFirstChild("TrocarMapa")
		if t and t:IsA("TextButton") then trocarMapa = t end

		local filtros = parentGui:FindFirstChild("Filtros")
		if filtros then
			local ff = filtros:FindFirstChild("FiltroFlores")
			if ff and ff:IsA("GuiButton") then filtroFloresBtn = ff end

			local fr = filtros:FindFirstChild("FiltroFrutos")
			if fr and fr:IsA("GuiButton") then filtroFrutosBtn = fr end
			
			local fc = filtros:FindFirstChild("FiltroClassificacao")
			if fc and fc:IsA("GuiButton") then filtroClassBtn = fc end
		end
	end

	local state: ControllerState = {
		main = main,
		searchBar = searchBar,
		lista = lista,
		template = template,
		mostrando = mostrando,
		trocarMapa = trocarMapa,
		lib = PlantLibrary.CreateDefault(),
		activeClones = {},
		pendingToken = 0,
		filters = { biomas = {}, regioes = {}, flores = "Qualquer", frutos = "Qualquer", classificacao = "Qualquer" },
		clickableModels = buildClickableMap(),
		mapMode = "Nenhum" :: MapMode,

		cameraStart = nil,
		cameraBasePos = nil,
		cameraConn = nil,
	}

	local function nextTriState(v: TriState): TriState
		if v == "Qualquer" then return "Sim" end
		if v == "Sim" then return "Nao" end
		return "Qualquer"
	end
	
	local function nextClass(v: ClassFilter): ClassFilter
		if v == "Qualquer" then return "Briofitas" end
		if v == "Briofitas" then return "Pteridofitas" end
		if v == "Pteridofitas" then return "Gimnospermas" end
		if v == "Gimnospermas" then return "Angiospermas" end
		return "Qualquer"
	end

	local function classLabel(v: ClassFilter): string
		if v == "Qualquer" then return "Qualquer" end
		if v == "Briofitas" then return "Briófitas" end
		if v == "Pteridofitas" then return "Pteridófitas" end
		return v
	end

	local function triLabel(v: TriState): string
		if v == "Qualquer" then return "Qualquer" end
		if v == "Sim" then return "Sim" end
		return "Não"
	end

	local function updateFiltroButtons()
		if filtroFloresBtn and filtroFloresBtn:IsA("TextButton") then
			filtroFloresBtn.Text = ("Flores: %s"):format(triLabel(state.filters.flores))
		end
		if filtroFrutosBtn and filtroFrutosBtn:IsA("TextButton") then
			filtroFrutosBtn.Text = ("Frutos: %s"):format(triLabel(state.filters.frutos))
		end
		if filtroClassBtn and filtroClassBtn:IsA("TextButton") then
			filtroClassBtn.Text = classLabel(state.filters.classificacao)
		end
	end

	if filtroFloresBtn then
		filtroFloresBtn.Activated:Connect(function()
			state.filters.flores = nextTriState(state.filters.flores)
			updateFiltroButtons()
			applySearchAndFilters(state)
		end)
	end

	if filtroFrutosBtn then
		filtroFrutosBtn.Activated:Connect(function()
			state.filters.frutos = nextTriState(state.filters.frutos)
			updateFiltroButtons()
			applySearchAndFilters(state)
		end)
	end
	
	if filtroClassBtn then
		filtroClassBtn.Activated:Connect(function()
			state.filters.classificacao = nextClass(state.filters.classificacao)
			updateFiltroButtons()
			applySearchAndFilters(state)
		end)
	end
	
	updateFiltroButtons()

	disablePlayerMovement()
	lockCamera(state)

	searchBar:GetPropertyChangedSignal("Text"):Connect(function()
		applySearchAndFilters(state)
	end)

	hookClickDetectors(state)
	hookTrocarMapa(state)

	updateMostrando(state)
	updateTrocarMapaButton(state)
	applySearchAndFilters(state)
end

return UIPlantController