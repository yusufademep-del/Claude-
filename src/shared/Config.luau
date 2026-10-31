-- Pump & Fly – gemeinsame Einstellungen (Server + Client)
-- Hier kannst du das komplette Balancing anpassen, ohne Code anzufassen.

local Config = {}

Config.GameName = "Pump & Fly"
Config.DataStoreName = "PumpFly_v1"

-- Flug & Belohnung
Config.LiftPerAir = 2 -- Studs Höhe pro Luft-Einheit
Config.CoinsPerStud = 0.5 -- Münzen pro Stud Höhe (vor Multiplikatoren)
Config.MaxHeight = 30000
Config.FlightSpeed = 400 -- Studs pro Sekunde (Flugdauer wird auf 1,5–9 s begrenzt)
Config.LaunchMinAir = 5

-- Pumpen
Config.PumpCooldown = 0.08 -- Sekunden zwischen zwei Pumpstößen (Anti-Spam)
Config.PumpRandomMin = 0.6 -- Pumpstoß = Power * Zufall(Min..Max) → Risiko!
Config.PumpRandomMax = 1.6
Config.MaxGainPerPump = 0.35 -- max. Anteil der Kapazität pro Pumpstoß

-- Boosts
Config.RebirthBonus = 0.5 -- +50 % Münzen pro Rebirth (dauerhaft)
Config.FriendBoostPerFriend = 0.1 -- +10 % pro Freund im Server
Config.FriendBoostMax = 0.5

function Config.RebirthCost(rebirths)
	return 25000 * (rebirths + 1) ^ 2
end

-- Gratis-Geschenk (hält Spieler im Spiel)
Config.GiftCooldown = 15 * 60
function Config.GiftCoins(rebirths)
	return 300 * (rebirths + 1)
end

-- Codes: Poste die in deiner Spielbeschreibung / auf TikTok!
Config.Codes = {
	START = 250,
	POP = 500,
	HALLOWEEN = 1000,
}

-- Game Pass IDs (0 = deaktiviert). ID nach dem Erstellen im Creator Hub eintragen.
Config.GamePasses = {
	DoubleCoins = 0,
}

Config.Balloons = {
	{ Name = "Kaugummi-Blase", Capacity = 20, Price = 0, Color = Color3.fromRGB(255, 140, 200) },
	{ Name = "Party-Ballon", Capacity = 50, Price = 150, Color = Color3.fromRGB(255, 70, 70) },
	{ Name = "Riesen-Ballon", Capacity = 120, Price = 800, Color = Color3.fromRGB(255, 170, 40) },
	{ Name = "Wetter-Ballon", Capacity = 300, Price = 3500, Color = Color3.fromRGB(240, 240, 240) },
	{ Name = "Zeppelin", Capacity = 750, Price = 15000, Color = Color3.fromRGB(150, 150, 170) },
	{ Name = "Raketen-Ballon", Capacity = 2000, Price = 60000, Color = Color3.fromRGB(60, 200, 255) },
	{ Name = "Galaxie-Ballon", Capacity = 5000, Price = 250000, Color = Color3.fromRGB(140, 80, 255) },
	{ Name = "Schwarzes Loch", Capacity = 15000, Price = 1000000, Color = Color3.fromRGB(25, 15, 40) },
}

Config.Pumps = {
	{ Name = "Puste-Lunge", Power = 1, Price = 0 },
	{ Name = "Fahrradpumpe", Power = 2, Price = 100 },
	{ Name = "Fußpumpe", Power = 5, Price = 600 },
	{ Name = "Kompressor", Power = 12, Price = 3000 },
	{ Name = "Laubbläser", Power = 30, Price = 14000 },
	{ Name = "Düsentriebwerk", Power = 80, Price = 55000 },
	{ Name = "Tornado in der Dose", Power = 200, Price = 220000 },
	{ Name = "Urknall-Pumpe", Power = 600, Price = 900000 },
}

-- Höhen-Zonen: je höher, desto größer der Münz-Multiplikator
Config.Zones = {
	{ Name = "Wiese", Icon = "🌱", Height = 0, Multiplier = 1, Color = Color3.fromRGB(120, 220, 120), Decor = "none" },
	{ Name = "Wolken", Icon = "☁️", Height = 400, Multiplier = 1.5, Color = Color3.fromRGB(255, 255, 255), Decor = "clouds" },
	{ Name = "Gewitter", Icon = "⚡", Height = 1200, Multiplier = 2, Color = Color3.fromRGB(255, 220, 60), Decor = "storm" },
	{ Name = "Weltall", Icon = "🚀", Height = 3500, Multiplier = 3, Color = Color3.fromRGB(120, 160, 255), Decor = "stars" },
	{ Name = "Mond", Icon = "🌙", Height = 9000, Multiplier = 5, Color = Color3.fromRGB(230, 230, 200), Decor = "moon" },
	{ Name = "Die Leere", Icon = "🕳️", Height = 22000, Multiplier = 10, Color = Color3.fromRGB(170, 60, 255), Decor = "void" },
}

function Config.GetZone(height)
	local current = Config.Zones[1]
	for _, zone in ipairs(Config.Zones) do
		if height >= zone.Height then
			current = zone
		end
	end
	return current
end

-- 1234 → "1.2K", 2500000 → "2.5M"
function Config.Format(n)
	n = math.floor(n or 0)
	local suffixes = { "", "K", "M", "B", "T", "Qa" }
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

-- 1.5 → "1.5", 2 → "2"
function Config.FormatMult(m)
	local s = string.format("%.2f", m)
	s = (s:gsub("0+$", ""))
	s = (s:gsub("%.$", ""))
	return s
end

return Config
