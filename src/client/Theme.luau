--!strict
-- Shared look of the HUD and board effects.

local Theme = {}

Theme.colors = table.freeze({
	panel = Color3.fromRGB(10, 18, 36),
	panelStroke = Color3.fromRGB(79, 227, 255),
	text = Color3.fromRGB(232, 242, 255),
	muted = Color3.fromRGB(150, 172, 204),
	accent = Color3.fromRGB(79, 227, 255),
	accentText = Color3.fromRGB(6, 20, 32),
	gold = Color3.fromRGB(255, 201, 74),
	button = Color3.fromRGB(22, 36, 64),
	buttonDisabled = Color3.fromRGB(30, 36, 48),
	tileLit = Color3.fromRGB(79, 227, 255),
	tileOff = Color3.fromRGB(58, 64, 80),
	iconOff = Color3.fromRGB(110, 120, 140),
	danger = Color3.fromRGB(255, 128, 104),
})

Theme.font = Enum.Font.GothamMedium
Theme.fontBold = Enum.Font.GothamBold
Theme.fontTitle = Enum.Font.GothamBlack

Theme.panelTransparency = 0.12
Theme.corner = UDim.new(0, 12)
-- Minimum touch target in reference pixels (before UIScale).
Theme.touchTarget = 52

return Theme
