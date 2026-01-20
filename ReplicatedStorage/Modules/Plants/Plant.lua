local Plant = {}
Plant.__index = Plant

export type PlantData = {
	id: string,
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

local function stripAccents(s: string): string
	-- Mapeamento básico PT-BR
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

function Plant._newBase(data: PlantData)
	assert(type(data.id) == "string" and data.id ~= "", "Plant precisa de id")
	assert(type(data.nomeCientifico) == "string" and data.nomeCientifico ~= "", "Plant precisa de nomeCientifico")
	assert(type(data.nomePopular) == "table" and #data.nomePopular > 0, "Plant precisa de nomePopular[]")
	assert(type(data.biomas) == "table" and #data.biomas > 0, "Plant precisa de biomas[]")
	assert(type(data.regioes) == "table" and #data.regioes > 0, "Plant precisa de regioes[]")

	local self = setmetatable({}, Plant)

	self._id = data.id
	self._nomePopular = data.nomePopular
	self._nomeCientifico = data.nomeCientifico
	self._biomas = data.biomas
	self._regioes = data.regioes
	self._estados = data.estados or {}
	self._tags = data.tags or {}
	self._temFlores = data.temFlores == true
	self._temFrutos = data.temFrutos == true
	self._classificacao = data.classificacao or "Angiospermas"
	self._classificacaoNorm = normalize(self._classificacao)

	-- cache normalizado (para busca/filtros)
	self._nomeCientificoNorm = normalize(self._nomeCientifico)

	self._nomePopularNorm = table.create(#self._nomePopular)
	for i, n in ipairs(self._nomePopular) do
		self._nomePopularNorm[i] = normalize(n)
	end

	self._biomasNorm = table.create(#self._biomas)
	for i, b in ipairs(self._biomas) do
		self._biomasNorm[i] = normalize(b)
	end

	self._regioesNorm = table.create(#self._regioes)
	for i, r in ipairs(self._regioes) do
		self._regioesNorm[i] = normalize(r)
	end

	self._estadosNorm = table.create(#self._estados)
	for i, uf in ipairs(self._estados) do
		self._estadosNorm[i] = normalize(uf)
	end

	self._tagsNorm = table.create(#self._tags)
	for i, t in ipairs(self._tags) do
		self._tagsNorm[i] = normalize(t)
	end

	return self
end

function Plant:GetId(): string return self._id end
function Plant:GetNomePopular(): {string} return self._nomePopular end
function Plant:GetNomeCientifico(): string return self._nomeCientifico end
function Plant:GetBiomas(): {string} return self._biomas end
function Plant:GetRegioes(): {string} return self._regioes end
function Plant:GetEstados(): {string} return self._estados end
function Plant:GetTags(): {string} return self._tags end
function Plant:TemFlores(): boolean return self._temFlores end
function Plant:TemFrutos(): boolean return self._temFrutos end
function Plant:GetClassificacao(): string return self._classificacao end

function Plant:GetType(): string
	error("GetType() deve ser implementado em subclasses (Plant é abstrata).")
end

function Plant:Matches(query: string): boolean
	local q = normalize(query)
	if q == "" then
		return true
	end

	local function containsNorm(hayNorm: string): boolean
		return hayNorm:find(q, 1, true) ~= nil
	end

	if containsNorm(self._nomeCientificoNorm) then return true end
	for _, n in ipairs(self._nomePopularNorm) do
		if containsNorm(n) then return true end
	end
	for _, b in ipairs(self._biomasNorm) do
		if containsNorm(b) then return true end
	end
	for _, r in ipairs(self._regioesNorm) do
		if containsNorm(r) then return true end
	end
	for _, uf in ipairs(self._estadosNorm) do
		if containsNorm(uf) then return true end
	end
	for _, t in ipairs(self._tagsNorm) do
		if containsNorm(t) then return true end
	end
	if containsNorm(self._classificacaoNorm) then return true end
	if containsNorm(normalize(self:GetType())) then return true end
	return false
end

-- filtros por bioma/região (normalizados)
export type TriState = "Qualquer" | "Sim" | "Nao"
export type ClassFilter = "Qualquer" | "Briofitas" | "Pteridofitas" | "Gimnospermas" | "Angiospermas"

export type FilterState = {
	biomas: {[string]: boolean},
	regioes: {[string]: boolean},
	flores: TriState,
	frutos: TriState,
	classificacao: ClassFilter,
}

function Plant:MatchesFilters(filters: FilterState): boolean
	local hasBiomeFilter = next(filters.biomas) ~= nil
	local hasRegionFilter = next(filters.regioes) ~= nil
	local hasFloresFilter = filters.flores ~= "Qualquer"
	local hasFrutosFilter = filters.frutos ~= "Qualquer"
	local hasClassFilter = filters.classificacao ~= "Qualquer"
	
	-- se não tem nenhum filtro ativo, aceita tudo
	if not hasBiomeFilter and not hasRegionFilter and not hasFloresFilter and not hasFrutosFilter and not hasClassFilter then
		return true
	end

	-- Biomas
	if hasBiomeFilter then
		local ok = false
		for _, b in ipairs(self._biomasNorm) do
			if filters.biomas[b] then
				ok = true
				break
			end
		end
		if not ok then return false end
	end

	-- Regiões
	if hasRegionFilter then
		local ok = false
		for _, r in ipairs(self._regioesNorm) do
			if filters.regioes[r] then
				ok = true
				break
			end
		end
		if not ok then return false end
	end

	-- Flores (TriState)
	if filters.flores == "Sim" and not self._temFlores then
		return false
	end
	if filters.flores == "Nao" and self._temFlores then
		return false
	end

	-- Frutos (TriState)
	if filters.frutos == "Sim" and not self._temFrutos then
		return false
	end
	if filters.frutos == "Nao" and self._temFrutos then
		return false
	end

	-- Classificação
	if hasClassFilter then
		local wanted = normalize(filters.classificacao) -- ex: "Pteridofitas" -> "pteridofitas"
		if self._classificacaoNorm ~= wanted then
			return false
		end
	end

	return true
end

function Plant:ToCardModel()
	return {
		id = self._id,
		type = self:GetType(),
		regioes = table.concat(self._regioes, "/"),
		nomePopular = table.concat(self._nomePopular, ", "),
		nomeCientifico = self._nomeCientifico,
		bioma = table.concat(self._biomas, ", "),
		temFlores = self._temFlores,
		temFrutos = self._temFrutos,
		classificacao = self._classificacao,
	}
end

return Plant
