-- Lager-Imperium – Einstellungen & Balancing (Server + Client)
-- Hier änderst du Preise, Waren, Level usw. ohne den restlichen Code anzufassen.

local Config = {}

Config.GameName = "Lager-Imperium"
Config.DataStoreName = "LagerImperium_v1"
Config.StartCoins = 500

-- Raster: 1 Feld = 4 Studs. Ein Grundstück besteht aus 5 x 4 Flächen-Stücken à 8 x 8 Feldern.
Config.TileSize = 4
Config.ChunkTiles = 8
Config.ChunksX = 5 -- Breite (links ↔ rechts)
Config.ChunksZ = 4 -- Tiefe (von der Straße nach hinten)
Config.StartChunk = { 2, 0 } -- vorne in der Mitte
Config.MaxItems = 700

function Config.ChunkPrice(ownedCount)
	return math.floor(1000 * 1.5 ^ (ownedCount - 1))
end

function Config.TilesX()
	return Config.ChunksX * Config.ChunkTiles
end

function Config.TilesZ()
	return Config.ChunksZ * Config.ChunkTiles
end

-- Level: XP gibt's für jede bewegte Kiste und jeden fertigen Auftrag
function Config.XPForLevel(level)
	return math.floor(60 * level ^ 1.6)
end

-- Waren (werden mit höherem Level freigeschaltet und sind mehr wert)
Config.Goods = {
	{ Id = "Food", Name = "Lebensmittel", Icon = "🥫", Color = Color3.fromRGB(110, 200, 90), Level = 1, Value = 1 },
	{ Id = "Clothes", Name = "Kleidung", Icon = "👕", Color = Color3.fromRGB(80, 140, 255), Level = 1, Value = 1.1 },
	{ Id = "Tech", Name = "Elektronik", Icon = "📱", Color = Color3.fromRGB(255, 210, 60), Level = 3, Value = 1.5 },
	{ Id = "Furniture", Name = "Möbel", Icon = "🛋️", Color = Color3.fromRGB(170, 110, 60), Level = 5, Value = 2 },
	{ Id = "Toys", Name = "Spielzeug", Icon = "🧸", Color = Color3.fromRGB(255, 110, 180), Level = 7, Value = 2.5 },
	{ Id = "Medicine", Name = "Medizin", Icon = "💊", Color = Color3.fromRGB(240, 240, 240), Level = 10, Value = 3.5 },
}
Config.GoodsById = {}
for _, g in ipairs(Config.Goods) do
	Config.GoodsById[g.Id] = g
end

-- Aufträge
Config.OfferCount = 3 -- angebotene Aufträge (+1 pro Büro)
Config.OfferLifetime = 120 -- Sekunden, bis ein Angebot verschwindet
Config.InRewardPerBox = 8 -- Wareneingang: Gebühr pro Kiste
Config.OutRewardPerBox = 20 -- Warenausgang: Verkaufspreis pro Kiste
Config.XPPerBox = 1
Config.XPPerOrderBox = 2

function Config.OrderAmountRange(level)
	return 3, 6 + level * 2
end

function Config.OrderTime(amount)
	return 60 + amount * 10
end

Config.Clients = {
	"Paketblitz GmbH", "Müller Handel", "SuperMarkt24", "Kaufrausch AG", "Turbo-Versand",
	"Omas Laden", "MegaStore", "Blitzkauf", "Nordfracht", "Stadtmarkt", "Klick&Weg", "Hafenkontor",
}

-- Ausrüstung: wie viele Kisten du auf einmal tragen kannst
Config.Tools = {
	{ Name = "Hände", Carry = 1, Price = 0, Level = 1 },
	{ Name = "Sackkarre", Carry = 3, Price = 500, Level = 2 },
	{ Name = "Hubwagen", Carry = 6, Price = 3000, Level = 4 },
	{ Name = "Elektro-Ameise", Carry = 12, Price = 15000, Level = 7 },
	{ Name = "Mini-Stapler", Carry = 25, Price = 75000, Level = 11 },
}

-- Automatisierung
Config.ForkliftInterval = 6 -- Sekunden pro Kiste und Station
Config.ConveyorBonus = 0.1 -- +10 % Tempo pro Förderband
Config.ConveyorMax = 10
Config.PackBonus = 0.1 -- +10 % Ausgang-Belohnung pro Packstation
Config.PackMax = 10
Config.OfficeBonus = 0.05 -- +5 % auf alle Belohnungen pro Büro
Config.OfficeMax = 5
Config.CoffeeSpeed = 2 -- +2 Laufgeschwindigkeit pro Kaffeeautomat
Config.CoffeeMax = 5
Config.BaseWalkSpeed = 16

Config.RemoveRefund = 0.5 -- 50 % zurück beim Abreißen

-- Codes für TikTok / Beschreibung
Config.Codes = {
	START = 500,
	LAGER = 1000,
	LKW = 2000,
}

function Config.Format(n)
	n = math.floor(n or 0)
	local suffixes = { "", "K", "M", "B", "T" }
	local i, v = 1, n
	while math.abs(v) >= 1000 and i < #suffixes do
		v /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	return (string.format("%.1f%s", v, suffixes[i]):gsub("%.0(%a)", "%1"))
end

function Config.FormatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Config
