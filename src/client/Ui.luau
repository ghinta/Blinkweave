--!strict
-- Tiny helpers for building UI from code.

local Theme = require(script.Parent.Theme)

local Ui = {}

-- Creates an instance, applies properties and parents children.
function Ui.new(className: string, props: { [string]: any }, children: { any }?): any
	local instance: any = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	local list: { any } = children or {}
	for _, child in list do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.corner(radius: UDim?): Instance
	return Ui.new("UICorner", { CornerRadius = radius or Theme.corner })
end

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?): Instance
	return Ui.new("UIStroke", {
		Color = color or Theme.colors.panelStroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(pixels: number): Instance
	local amount = UDim.new(0, pixels)
	return Ui.new("UIPadding", {
		PaddingTop = amount,
		PaddingBottom = amount,
		PaddingLeft = amount,
		PaddingRight = amount,
	})
end

function Ui.list(direction: Enum.FillDirection, spacing: number, alignment: Enum.HorizontalAlignment?): Instance
	return Ui.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	})
end

function Ui.panel(props: { [string]: any }, children: { any }?): Frame
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.colors.panel,
		BackgroundTransparency = Theme.panelTransparency,
		BorderSizePixel = 0,
	}
	for key, value in props do
		merged[key] = value
	end
	local frame: Frame = Ui.new("Frame", merged, children)
	Ui.corner().Parent = frame
	Ui.stroke().Parent = frame
	return frame
end

function Ui.label(props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Theme.font,
		TextColor3 = Theme.colors.text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for key, value in props do
		merged[key] = value
	end
	return Ui.new("TextLabel", merged)
end

-- A button with a text label and an optional keyboard key cap.
function Ui.button(props: { [string]: any }, keyCap: string?): TextButton
	local merged: { [string]: any } = {
		BackgroundColor3 = Theme.colors.button,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Font = Theme.fontBold,
		TextColor3 = Theme.colors.text,
		TextSize = 18,
	}
	for key, value in props do
		merged[key] = value
	end
	local button: TextButton = Ui.new("TextButton", merged)
	Ui.corner(UDim.new(0, 10)).Parent = button
	Ui.stroke(nil, 1, 0.6).Parent = button
	if keyCap then
		Ui.new("TextLabel", {
			Name = "KeyCap",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Theme.colors.panel,
			BackgroundTransparency = 0.2,
			Font = Theme.fontBold,
			Text = keyCap,
			TextColor3 = Theme.colors.muted,
			TextSize = 14,
			Parent = button,
		}, { Ui.corner(UDim.new(0, 6)) })
	end
	return button
end

return Ui
