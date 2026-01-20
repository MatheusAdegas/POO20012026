local TreePlant = require(script.Parent.TreePlant)
local FlowerPlant = require(script.Parent.FlowerPlant)

local PlantLibrary = {}
PlantLibrary.__index = PlantLibrary

export type PlantLike = {
	GetId: (any) -> string,
	Matches: (any, string) -> boolean,
	MatchesFilters: (any, any) -> boolean,
	ToCardModel: (any) -> any,
}

export type PlantRow = {
	id: string,
	kind: "tree" | "flower",
	nomePopular: {string},
	nomeCientifico: string,
	biomas: {string},
	regioes: {string},
	estados: {string}?,
	tags: {string}?,
	temFlores: boolean?,
	temFrutos: boolean?,
	classificacao: string?,
}

-- Banco de dados de plantas
local DEFAULT_PLANTS: {PlantRow} = {
	{
		id = "001", kind = "tree",
		nomePopular = {"Ipê-amarelo", "Ipê"},
		nomeCientifico = "Handroanthus albus",
		biomas = {"Cerrado", "Mata Atlântica"},
		regioes = {"CO", "SE", "S"},
		estados = {"GO", "MG", "SP", "PR"},
		tags = {"ornamental"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "002", kind = "flower",
		nomePopular = {"Selaginela-da-caatinga", "Selaginela"},
		nomeCientifico = "Selaginella convoluta",
		biomas = {"Caatinga"},
		regioes = {"NE"},
		estados = {"CE", "RN", "PB", "PE", "BA"},
		tags = {"pteridofita", "resistente-seca"},
		temFlores = false, temFrutos = false,
		classificacao = "Pteridofitas",
	},
	{
		id = "003", kind = "flower",
		nomePopular = {"Mandacaru (flor)"},
		nomeCientifico = "Cereus jamacaru",
		biomas = {"Caatinga"},
		regioes = {"NE"},
		estados = {"CE", "RN", "PB", "PE", "BA"},
		tags = {"cacto"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "004", kind = "tree",
		nomePopular = {"Pau-brasil"},
		nomeCientifico = "Paubrasilia echinata",
		biomas = {"Mata Atlântica"},
		regioes = {"NE", "SE"},
		estados = {"BA", "ES", "RJ"},
		tags = {"história"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "005", kind = "flower",
		nomePopular = {"Vitória-régia"},
		nomeCientifico = "Victoria amazonica",
		biomas = {"Amazônia"},
		regioes = {"N"},
		estados = {"AM", "PA"},
		tags = {"aquática"},
		temFlores = true, temFrutos = false,
		classificacao = "Angiospermas",
	},

	{
		id = "006", kind = "tree",
		nomePopular = {"Pequi"},
		nomeCientifico = "Caryocar brasiliense",
		biomas = {"Cerrado"},
		regioes = {"CO", "SE", "NE"},
		estados = {"GO", "MG", "TO", "BA"},
		tags = {"culinária"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "007", kind = "tree",
		nomePopular = {"Umbuzeiro", "Imbuzeiro"},
		nomeCientifico = "Spondias tuberosa",
		biomas = {"Caatinga"},
		regioes = {"NE"},
		estados = {"BA", "PE", "PB", "CE", "RN"},
		tags = {"semiárido"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "008", kind = "tree",
		nomePopular = {"Carnaúba"},
		nomeCientifico = "Copernicia prunifera",
		biomas = {"Caatinga"},
		regioes = {"NE"},
		estados = {"CE", "PI", "RN"},
		tags = {"palmeira"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "009", kind = "tree",
		nomePopular = {"Açaí", "Açaizeiro"},
		nomeCientifico = "Euterpe oleracea",
		biomas = {"Amazônia"},
		regioes = {"N"},
		estados = {"PA", "AP", "AM"},
		tags = {"palmeira"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "010", kind = "tree",
		nomePopular = {"Castanheira-do-pará", "Castanha-do-brasil"},
		nomeCientifico = "Bertholletia excelsa",
		biomas = {"Amazônia"},
		regioes = {"N"},
		estados = {"PA", "AM", "AC", "RO"},
		tags = {"econômica"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "011", kind = "tree",
		nomePopular = {"Buriti"},
		nomeCientifico = "Mauritia flexuosa",
		biomas = {"Amazônia", "Cerrado", "Pantanal"},
		regioes = {"N", "CO"},
		estados = {"AM", "PA", "MT", "TO"},
		tags = {"veredas"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "012", kind = "tree",
		nomePopular = {"Jatobá"},
		nomeCientifico = "Hymenaea courbaril",
		biomas = {"Amazônia", "Cerrado", "Mata Atlântica"},
		regioes = {"N", "CO", "SE"},
		estados = {"PA", "MT", "MG", "BA"},
		tags = {"madeira"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "013", kind = "tree",
		nomePopular = {"Cajueiro", "Caju"},
		nomeCientifico = "Anacardium occidentale",
		biomas = {"Caatinga", "Cerrado", "Amazônia"},
		regioes = {"NE", "N"},
		estados = {"CE", "PI", "RN", "PA"},
		tags = {"castanha"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "014", kind = "tree",
		nomePopular = {"Pinheiro-bravo", "Podocarpo"},
		nomeCientifico = "Podocarpus lambertii",
		biomas = {"Mata Atlântica"},
		regioes = {"SE", "S"},
		estados = {"SP", "RJ", "PR", "SC", "RS"},
		tags = {"gimnosperma", "conifera"},
		temFlores = false, temFrutos = false,
		classificacao = "Gimnospermas",
	},
	{
		id = "015", kind = "tree",
		nomePopular = {"Guaraná"},
		nomeCientifico = "Paullinia cupana",
		biomas = {"Amazônia"},
		regioes = {"N"},
		estados = {"AM", "PA"},
		tags = {"estimulante"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "016", kind = "tree",
		nomePopular = {"Erva-mate", "Mate"},
		nomeCientifico = "Ilex paraguariensis",
		biomas = {"Mata Atlântica"},
		regioes = {"S"},
		estados = {"PR", "SC", "RS"},
		tags = {"chimarrão"},
		temFlores = true, temFrutos = true,
		classificacao = "Angiospermas",
	},
	{
		id = "017", kind = "tree",
		nomePopular = {"Araucária", "Pinheiro-do-paraná"},
		nomeCientifico = "Araucaria angustifolia",
		biomas = {"Mata Atlântica"},
		regioes = {"S"},
		estados = {"PR", "SC", "RS"},
		tags = {"conífera"},
		temFlores = false, temFrutos = false,
		classificacao = "Gimnospermas",
	},
	{
		id = "018", kind = "tree",
		nomePopular = {"Xaxim", "Samambaiaçu"},
		nomeCientifico = "Dicksonia sellowiana",
		biomas = {"Mata Atlântica"},
		regioes = {"SE", "S"},
		estados = {"MG", "RJ", "SP", "PR", "SC", "RS"},
		tags = {"pteridofita", "samambaia-arborescente"},
		temFlores = false, temFrutos = false,
		classificacao = "Pteridofitas",
	},
	{
		id = "019", kind = "flower",
		nomePopular = {"Musgo de turfa", "Esfagno"},
		nomeCientifico = "Sphagnum magellanicum",
		biomas = {"Mata Atlântica"},
		regioes = {"SE", "S"},
		estados = {"RJ", "PR", "SC", "RS"},
		tags = {"briofita", "turfeira", "campos-altitude"},
		temFlores = false, temFrutos = false,
		classificacao = "Briofitas",
	},
}


local function makePlant(row: PlantRow): any
	local ctor = (row.kind == "flower") and FlowerPlant.new or TreePlant.new
	return ctor({
		id = row.id,
		nomePopular = row.nomePopular,
		nomeCientifico = row.nomeCientifico,
		biomas = row.biomas,
		regioes = row.regioes,
		estados = row.estados,
		tags = row.tags,
		temFlores = row.temFlores,
		temFrutos = row.temFrutos,
		classificacao = row.classificacao,
	})
end

function PlantLibrary.new(plants: {PlantLike}?)
	local self = setmetatable({}, PlantLibrary)
	self._plants = plants or {}
	return self
end

function PlantLibrary:Add(plant: PlantLike)
	table.insert(self._plants, plant)
end

function PlantLibrary:GetAll(): {PlantLike}
	local copy = table.create(#self._plants)
	for i, p in ipairs(self._plants) do copy[i] = p end
	return copy
end

function PlantLibrary:Search(query: string): {PlantLike}
	local results = {}
	for _, p in ipairs(self._plants) do
		if p:Matches(query) then table.insert(results, p) end
	end
	table.sort(results, function(a, b) return a:GetId() < b:GetId() end)
	return results
end

-- cria a lib já populada com os dados default
function PlantLibrary.CreateDefault()
	local lib = PlantLibrary.new()
	for _, row in ipairs(DEFAULT_PLANTS) do
		lib:Add(makePlant(row))
	end
	return lib
end

return PlantLibrary