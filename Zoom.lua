-- Vivo X300 Pro Camera | Delta Ultra Zoom
-- UI ใหม่, โหมด NORMAL / ULTRA, ซูม 1000x-5000x แยกชัดเจน

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- ล้างตัวเก่าจากรอบก่อน
if shared.VivoX300Cleanup then
    pcall(shared.VivoX300Cleanup)
end

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("VivoX300ProDelta")
if oldGui then
    oldGui:Destroy()
end

for _, v in ipairs(camera:GetChildren()) do
    if v.Name == "VivoX300Blur" or v.Name == "VivoX300Color" then
        v:Destroy()
    end
end

-- GUI หลัก
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VivoX300ProDelta"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ระบบ Cleanup
local cleanup = {}
local function connect(signal, fn)
    local conn = signal:Connect(fn)
    table.insert(cleanup, conn)
    return conn
end

-- ธีมสี
local theme = {
    bg = Color3.fromRGB(10, 10, 14),
    card = Color3.fromRGB(20, 20, 28),
    card2 = Color3.fromRGB(32, 32, 44),
    accent = Color3.fromRGB(255, 196, 0),
    accent2 = Color3.fromRGB(255, 110, 70),
    text = Color3.fromRGB(240, 240, 245),
    sub = Color3.fromRGB(150, 155, 170),
    stroke = Color3.fromRGB(58, 60, 76),
    danger = Color3.fromRGB(235, 70, 80),
}

-- ตัวแปรระบบซูม
local minZoom = 0.6
local normalMaxZoom = 100
local ultraMinZoom = 1000
local maxZoom = 5000

local targetZoom = 1
local currentZoom = 1
local targetLog = math.log(1)
local currentLog = math.log(1)

local zoomMode = "NORMAL" -- NORMAL / ULTRA
local isAFMode = true
local isProMode = false

local manualFocus = 0
local manualWB = 0
local manualShutter = 0.5
local manualEV = 0

local lastOpticalZoom = 1
local isLensSwitching = false
local lensKick = 0
local originalFOV = 70

-- Presets
local normalPresets = {0.6, 1, 3, 5, 10, 50, 100}
local ultraPresets = {1000, 1500, 2000, 3000, 4000, 5000}

-- Forward declarations
local setTargetZoom
local updateZoomSliderVisual
local updatePresetHighlights
local switchMode
local updateTabButtons
local updatePresetVisibility
local updateSliderRange
local fullCleanup

-- Helper สร้าง Instance
local function make(className, props, children)
    local inst = Instance.new(className)
    props = props or {}

    for k, v in pairs(props) do
        if k ~= "Parent" and k ~= "Children" then
            inst[k] = v
        end
    end

    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end

    if props.Parent then
        inst.Parent = props.Parent
    end

    return inst
end

local function corner(radius, parent)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function stroke(color, thickness, parent, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

local function gradient(colors, rotation, parent)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(colors)
    g.Rotation = rotation or 90
    g.Parent = parent
    return g
end

local function card(parent, order, height)
    local f = make("Frame", {
        Size = UDim2.new(1, 0, 0, height or 40),
        BackgroundColor3 = theme.card,
        BorderSizePixel = 0,
        LayoutOrder = order,
        Parent = parent,
    })
    corner(12, f)
    stroke(theme.stroke, 1, f)
    gradient({
        Color3.fromRGB(30, 30, 42),
        Color3.fromRGB(19, 19, 27),
    }, 90, f)
    return f
end

-- Effects
local blurEffect = Instance.new("BlurEffect")
blurEffect.Name = "VivoX300Blur"
blurEffect.Size = 0
blurEffect.Parent = camera

local colorEffect = Instance.new("ColorCorrectionEffect")
colorEffect.Name = "VivoX300Color"
colorEffect.Contrast = 0
colorEffect.Saturation = 0
colorEffect.Brightness = 0
colorEffect.TintColor = Color3.fromRGB(255, 255, 255)
colorEffect.Parent = camera

local flashFrame = make("Frame", {
    Name = "FlashFrame",
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 50,
    Parent = screenGui,
})

-- Slider system
local activeSlider = nil

connect(UserInputService.InputChanged, function(input)
    if activeSlider and (
        input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch
    ) then
        activeSlider:HandleInput(input.Position.X)
    end
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if activeSlider then
            activeSlider:EndDrag()
        end
    end
end)

local function createSlider(opts)
    local parent = opts.Parent
    local height = opts.Height or 16

    local container = make("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = parent,
    })

    local track = make("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0.5, -3),
        BackgroundColor3 = Color3.fromRGB(48, 50, 66),
        BorderSizePixel = 0,
        Parent = container,
    })
    corner(3, track)

    local fill = make("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = opts.Accent or theme.accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(3, fill)

    local knob = make("Frame", {
        Size = UDim2.new(0, 15, 0, 15),
        Position = UDim2.new(0, -7, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(8, knob)
    stroke(Color3.fromRGB(0, 0, 0), 1, knob, 0.35)

    local slider = {
        Frame = container,
        Track = track,
        Fill = fill,
        Knob = knob,
        Min = opts.Min or 0,
        Max = opts.Max or 1,
        Value = opts.Default or opts.Min or 0,
        Dragging = false,
        OnChanged = opts.OnChanged,
    }

    local logarithmic = opts.Logarithmic or false

    local function valueToProgress(v)
        v = math.clamp(v, slider.Min, slider.Max)
        if logarithmic and slider.Min > 0 and slider.Max > 0 then
            return (math.log(v) - math.log(slider.Min)) / (math.log(slider.Max) - math.log(slider.Min))
        end
        return (v - slider.Min) / math.max(slider.Max - slider.Min, 0.0001)
    end

    local function progressToValue(p)
        p = math.clamp(p, 0, 1)
        if logarithmic and slider.Min > 0 and slider.Max > 0 then
            local logMin = math.log(slider.Min)
            local logMax = math.log(slider.Max)
            return math.exp(logMin + p * (logMax - logMin))
        end
        return slider.Min + p * (slider.Max - slider.Min)
    end

    function slider:SetVisual(v)
        v = math.clamp(v, self.Min, self.Max)
        self.Value = v
        local p = valueToProgress(v)
        self.Fill.Size = UDim2.new(p, 0, 1, 0)
        self.Knob.Position = UDim2.new(p, -7, 0.5, -7)
    end

    local function updateFromX(x)
        local rel = x - track.AbsolutePosition.X
        local p = math.clamp(rel / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = progressToValue(p)
        slider:SetVisual(v)
        if slider.OnChanged then
            slider.OnChanged(v)
        end
    end

    function slider:HandleInput(x)
        if self.Dragging then
            updateFromX(x)
        end
    end

    function slider:EndDrag()
        self.Dragging = false
        if activeSlider == self then
            activeSlider = nil
        end
    end

    connect(track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeSlider = slider
            slider.Dragging = true
            updateFromX(input.Position.X)
        end
    end)

    slider:SetVisual(slider.Value)
    return slider
end

-- Drag system
local function makeDraggable(frame, handle, options)
    options = options or {}
    local dragging = false
    local moved = false
    local dragStart, startPos

    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = frame.Position

            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then
                        conn:Disconnect()
                    end
                    if options.OnDragEnd then
                        options.OnDragEnd(moved)
                    end
                end
            end)
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 3 then
                moved = true
            end
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Main Window
local mainFrame = make("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, 340, 0, 0),
    Position = UDim2.new(0.5, -170, 0, 110),
    BackgroundColor3 = theme.bg,
    BorderSizePixel = 0,
    AutomaticSize = Enum.AutomaticSize.Y,
    Active = true,
    Parent = screenGui,
})
corner(16, mainFrame)
stroke(theme.stroke, 1, mainFrame)
gradient({
    Color3.fromRGB(18, 18, 26),
    Color3.fromRGB(8, 8, 12),
}, 90, mainFrame)

make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 0),
    Parent = mainFrame,
})

make("UIPadding", {
    PaddingTop = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    Parent = mainFrame,
})

-- Header
local header = make("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundTransparency = 1,
    LayoutOrder = 0,
    Active = true,
    Parent = mainFrame,
})

local headerBg = make("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = theme.card,
    BorderSizePixel = 0,
    Parent = header,
})
corner(12, headerBg)
stroke(theme.stroke, 1, headerBg)
gradient({
    Color3.fromRGB(38, 38, 54),
    Color3.fromRGB(21, 21, 30),
}, 90, headerBg)

make("TextLabel", {
    Size = UDim2.new(1, -95, 0, 18),
    Position = UDim2.new(0, 12, 0, 4),
    BackgroundTransparency = 1,
    Text = "VIVO X300 PRO",
    TextColor3 = theme.text,
    TextSize = 15,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = header,
})

make("TextLabel", {
    Size = UDim2.new(1, -95, 0, 12),
    Position = UDim2.new(0, 12, 0, 23),
    BackgroundTransparency = 1,
    Text = "Delta • Ultra Zoom 1000x-5000x",
    TextColor3 = theme.sub,
    TextSize = 9,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = header,
})

local minimizeBtn = make("TextButton", {
    Size = UDim2.new(0, 26, 0, 26),
    Position = UDim2.new(1, -66, 0.5, -13),
    BackgroundColor3 = theme.card2,
    Text = "—",
    TextColor3 = theme.text,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = header,
})
corner(8, minimizeBtn)

local closeBtn = make("TextButton", {
    Size = UDim2.new(0, 26, 0, 26),
    Position = UDim2.new(1, -34, 0.5, -13),
    BackgroundColor3 = theme.danger,
    Text = "X",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = header,
})
corner(8, closeBtn)

-- Content
local content = make("Frame", {
    Name = "Content",
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder = 1,
    Parent = mainFrame,
})

make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 8),
    Parent = content,
})

-- Zoom Display
local zoomCard = card(content, 1, 66)

local zoomLabel = make("TextLabel", {
    Size = UDim2.new(1, -120, 0, 30),
    Position = UDim2.new(0, 12, 0, 8),
    BackgroundTransparency = 1,
    Text = "1.0x",
    TextColor3 = theme.accent,
    TextSize = 26,
    Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = zoomCard,
})

local zoomBadge = make("TextLabel", {
    Size = UDim2.new(0, 74, 0, 18),
    Position = UDim2.new(1, -88, 0, 11),
    BackgroundColor3 = theme.card2,
    Text = "NORMAL",
    TextColor3 = theme.text,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = zoomCard,
})
corner(9, zoomBadge)

local statusLabel = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 14),
    Position = UDim2.new(0, 12, 0, 43),
    BackgroundTransparency = 1,
    Text = "Optical ready",
    TextColor3 = theme.sub,
    TextSize = 10,
    Font = Enum.Font.GothamMedium,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = zoomCard,
})

-- Mode Tabs
local tabCard = card(content, 2, 40)

local normalTabBtn = make("TextButton", {
    Size = UDim2.new(0.5, -6, 1, -8),
    Position = UDim2.new(0, 4, 0, 4),
    BackgroundColor3 = theme.accent,
    Text = "NORMAL",
    TextColor3 = Color3.fromRGB(10, 10, 10),
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = tabCard,
})
corner(9, normalTabBtn)

local ultraTabBtn = make("TextButton", {
    Size = UDim2.new(0.5, -6, 1, -8),
    Position = UDim2.new(0.5, 2, 0, 4),
    BackgroundColor3 = theme.card2,
    Text = "ULTRA 1000-5000",
    TextColor3 = theme.text,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = tabCard,
})
corner(9, ultraTabBtn)

-- Slider Card
local sliderCard = card(content, 3, 54)

make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 14),
    Position = UDim2.new(0, 12, 0, 7),
    BackgroundTransparency = 1,
    Text = "ZOOM SLIDER",
    TextColor3 = theme.sub,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = sliderCard,
})

local zoomSlider = createSlider({
    Parent = sliderCard,
    Min = minZoom,
    Max = normalMaxZoom,
    Default = 1,
    Logarithmic = true,
    Height = 16,
    Accent = theme.accent,
    OnChanged = function(v)
        setTargetZoom(v, { fromSlider = true })
    end,
})
zoomSlider.Frame.Size = UDim2.new(1, -24, 0, 16)
zoomSlider.Frame.Position = UDim2.new(0, 12, 0, 27)

-- Preset Card
local presetCard = card(content, 4, 62)

make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 14),
    Position = UDim2.new(0, 12, 0, 6),
    BackgroundTransparency = 1,
    Text = "PRESETS",
    TextColor3 = theme.sub,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = presetCard,
})

local normalPresetFrame = make("Frame", {
    Size = UDim2.new(1, -20, 0, 28),
    Position = UDim2.new(0, 10, 0, 25),
    BackgroundTransparency = 1,
    Parent = presetCard,
})

make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
    Parent = normalPresetFrame,
})

local ultraPresetFrame = make("Frame", {
    Size = UDim2.new(1, -20, 0, 28),
    Position = UDim2.new(0, 10, 0, 25),
    BackgroundTransparency = 1,
    Visible = false,
    Parent = presetCard,
})

make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 4),
    Parent = ultraPresetFrame,
})

local normalPresetButtons = {}
local ultraPresetButtons = {}

local function createPresetButton(parent, order, text, width)
    local btn = make("TextButton", {
        Size = UDim2.new(0, width or 38, 0, 24),
        BackgroundColor3 = theme.card2,
        Text = text,
        TextColor3 = theme.text,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        LayoutOrder = order,
        Parent = parent,
    })
    corner(7, btn)
    stroke(theme.stroke, 1, btn)
    return btn
end

for i, v in ipairs(normalPresets) do
    local text = tostring(v)
    if v == math.floor(v) then
        text = tostring(math.floor(v))
    end

    local btn = createPresetButton(normalPresetFrame, i, text, 38)
    normalPresetButtons[v] = btn

    connect(btn.MouseButton1Click, function()
        setTargetZoom(v, { mode = "NORMAL", effect = true, snap = true })
    end)
end

local function ultraText(v)
    local k = v / 1000
    if k == math.floor(k) then
        return string.format("%dK", k)
    end
    return string.format("%.1fK", k)
end

for i, v in ipairs(ultraPresets) do
    local btn = createPresetButton(ultraPresetFrame, i, ultraText(v), 46)
    ultraPresetButtons[v] = btn

    connect(btn.MouseButton1Click, function()
        setTargetZoom(v, { mode = "ULTRA", effect = true, snap = true })
    end)
end

-- AF / MF
local focusCard = card(content, 5, 40)

local afBtn = make("TextButton", {
    Size = UDim2.new(0.5, -6, 1, -8),
    Position = UDim2.new(0, 4, 0, 4),
    BackgroundColor3 = theme.accent,
    Text = "AF",
    TextColor3 = Color3.fromRGB(10, 10, 10),
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = focusCard,
})
corner(9, afBtn)

local mfBtn = make("TextButton", {
    Size = UDim2.new(0.5, -6, 1, -8),
    Position = UDim2.new(0.5, 2, 0, 4),
    BackgroundColor3 = theme.card2,
    Text = "MF",
    TextColor3 = theme.text,
    TextSize = 13,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = focusCard,
})
corner(9, mfBtn)

-- Pro Toggle
local proCard = card(content, 6, 38)

local proToggle = make("TextButton", {
    Size = UDim2.new(1, -8, 1, -8),
    Position = UDim2.new(0, 4, 0, 4),
    BackgroundColor3 = theme.card2,
    Text = "PRO MODE : OFF",
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    Parent = proCard,
})
corner(9, proToggle)

-- Pro Panel
local proPanel = make("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = theme.card,
    BorderSizePixel = 0,
    LayoutOrder = 7,
    Visible = false,
    Parent = content,
})
corner(12, proPanel)
stroke(theme.stroke, 1, proPanel)
gradient({
    Color3.fromRGB(30, 30, 42),
    Color3.fromRGB(19, 19, 27),
}, 90, proPanel)

make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 6),
    Parent = proPanel,
})

make("UIPadding", {
    PaddingTop = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
    Parent = proPanel,
})

make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "PRO CONTROLS",
    TextColor3 = theme.sub,
    TextSize = 10,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 0,
    Parent = proPanel,
})

local proSliderObjects = {}

local proDefs = {
    {
        label = "FOCUS",
        default = 0,
        onChange = function(v)
            manualFocus = v
        end,
        format = function(v)
            return string.format("%.2f", v)
        end,
    },
    {
        label = "WB",
        default = 0.5,
        onChange = function(v)
            manualWB = v - 0.5
        end,
        format = function(v)
            return string.format("%+.2f", v - 0.5)
        end,
    },
    {
        label = "SHUTTER",
        default = 0.5,
        onChange = function(v)
            manualShutter = v
        end,
        format = function(v)
            return string.format("%.2f", v)
        end,
    },
    {
        label = "EV",
        default = 0.5,
        onChange = function(v)
            manualEV = v - 0.5
        end,
        format = function(v)
            return string.format("%+.2f", v - 0.5)
        end,
    },
}

for i, def in ipairs(proDefs) do
    local row = make("Frame", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder = i,
        Parent = proPanel,
    })

    make("TextLabel", {
        Size = UDim2.new(0, 68, 1, 0),
        BackgroundTransparency = 1,
        Text = def.label,
        TextColor3 = theme.sub,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })

    local valueLabel = make("TextLabel", {
        Size = UDim2.new(0, 42, 1, 0),
        Position = UDim2.new(1, -42, 0, 0),
        BackgroundTransparency = 1,
        Text = def.format(def.default),
        TextColor3 = theme.text,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = row,
    })

    local s = createSlider({
        Parent = row,
        Min = 0,
        Max = 1,
        Default = def.default,
        Height = 12,
        Accent = theme.accent2,
        OnChanged = function(v)
            def.onChange(v)
            valueLabel.Text = def.format(v)
        end,
    })

    s.Frame.Size = UDim2.new(1, -122, 0, 12)
    s.Frame.Position = UDim2.new(0, 72, 0.5, -6)

    table.insert(proSliderObjects, {
        slider = s,
        default = def.default,
        onChange = def.onChange,
        valueLabel = valueLabel,
        format = def.format,
    })
end

local resetProBtn = make("TextButton", {
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundColor3 = theme.card2,
    Text = "RESET PRO",
    TextColor3 = theme.text,
    TextSize = 11,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
    LayoutOrder = 5,
    Parent = proPanel,
})
corner(8, resetProBtn)

connect(resetProBtn.MouseButton1Click, function()
    for _, obj in ipairs(proSliderObjects) do
        obj.slider:SetVisual(obj.default)
        obj.onChange(obj.default)
        obj.valueLabel.Text = obj.format(obj.default)
    end
end)

-- Floating minimize button
local floatingCircle = make("TextButton", {
    Name = "FloatingCircle",
    Size = UDim2.new(0, 54, 0, 54),
    Position = UDim2.new(1, -72, 0.5, -27),
    BackgroundColor3 = theme.card,
    Text = "📷",
    TextSize = 24,
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
corner(27, floatingCircle)
stroke(theme.accent, 2, floatingCircle)
gradient({
    Color3.fromRGB(35, 35, 48),
    Color3.fromRGB(18, 18, 25),
}, 90, floatingCircle)

makeDraggable(mainFrame, headerBg)

local floatSuppressClick = false
connect(floatingCircle.InputBegan, function()
    floatSuppressClick = false
end)

makeDraggable(floatingCircle, floatingCircle, {
    OnDragEnd = function(moved)
        if moved then
            floatSuppressClick = true
        end
    end,
})

-- Optical helper
local opticalLevels = {}
for _, v in ipairs(normalPresets) do
    table.insert(opticalLevels, v)
end
for _, v in ipairs(ultraPresets) do
    table.insert(opticalLevels, v)
end

local function getOpticalState(z)
    for _, v in ipairs(opticalLevels) do
        local tolerance = math.max(0.03, v * 0.006)
        if math.abs(z - v) <= tolerance then
            return true, v
        end
    end
    return false, z
end

local function formatZoom(z)
    if z >= 1000 then
        local s = tostring(math.floor(z + 0.5))
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return s .. "x"
    elseif z >= 100 then
        return string.format("%.0fx", z)
    else
        return string.format("%.1fx", z)
    end
end

-- Lens switch effect
local function playLensSwitchEffect()
    if isLensSwitching then return end
    isLensSwitching = true
    lensKick = 1

    task.spawn(function()
        for i = 10, 0, -1 do
            lensKick = i / 10
            task.wait(0.015)
        end
        isLensSwitching = false
    end)

    TweenService:Create(
        flashFrame,
        TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 0.72 }
    ):Play()

    task.delay(0.09, function()
        TweenService:Create(
            flashFrame,
            TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { BackgroundTransparency = 1 }
        ):Play()
    end)
end

-- UI update functions
updateSliderRange = function()
    if not zoomSlider then return end
    if zoomMode == "ULTRA" then
        zoomSlider.Min = ultraMinZoom
        zoomSlider.Max = maxZoom
    else
        zoomSlider.Min = minZoom
        zoomSlider.Max = normalMaxZoom
    end
end

updateZoomSliderVisual = function()
    if not zoomSlider then return end
    updateSliderRange()
    zoomSlider:SetVisual(math.clamp(targetZoom, zoomSlider.Min, zoomSlider.Max))
end

updateTabButtons = function()
    if not normalTabBtn or not ultraTabBtn or not zoomBadge then return end

    if zoomMode == "ULTRA" then
        normalTabBtn.BackgroundColor3 = theme.card2
        normalTabBtn.TextColor3 = theme.text

        ultraTabBtn.BackgroundColor3 = theme.accent2
        ultraTabBtn.TextColor3 = Color3.fromRGB(20, 8, 0)

        zoomBadge.Text = "ULTRA"
        zoomBadge.BackgroundColor3 = theme.accent2
        zoomBadge.TextColor3 = Color3.fromRGB(20, 8, 0)
    else
        normalTabBtn.BackgroundColor3 = theme.accent
        normalTabBtn.TextColor3 = Color3.fromRGB(10, 10, 10)

        ultraTabBtn.BackgroundColor3 = theme.card2
        ultraTabBtn.TextColor3 = theme.text

        zoomBadge.Text = "NORMAL"
        zoomBadge.BackgroundColor3 = theme.card2
        zoomBadge.TextColor3 = theme.text
    end
end

updatePresetVisibility = function()
    if not normalPresetFrame or not ultraPresetFrame then return end
    normalPresetFrame.Visible = zoomMode ~= "ULTRA"
    ultraPresetFrame.Visible = zoomMode == "ULTRA"
end

updatePresetHighlights = function()
    for val, btn in pairs(normalPresetButtons) do
        local active = math.abs(targetZoom - val) <= math.max(0.03, val * 0.006)
        if active then
            btn.BackgroundColor3 = theme.accent
            btn.TextColor3 = Color3.fromRGB(10, 10, 10)
        else
            btn.BackgroundColor3 = theme.card2
            btn.TextColor3 = theme.text
        end
    end

    for val, btn in pairs(ultraPresetButtons) do
        local active = math.abs(targetZoom - val) <= math.max(0.03, val * 0.006)
        if active then
            btn.BackgroundColor3 = theme.accent2
            btn.TextColor3 = Color3.fromRGB(20, 8, 0)
        else
            btn.BackgroundColor3 = theme.card2
            btn.TextColor3 = theme.text
        end
    end
end

local function updateHUD()
    zoomLabel.Text = formatZoom(currentZoom)

    local isOptical, opt = getOpticalState(currentZoom)

    if isProMode then
        statusLabel.Text = "PRO • Manual processing"
    elseif isOptical then
        if opt >= ultraMinZoom then
            statusLabel.Text = "Ultra Periscope Optical • " .. formatZoom(opt)
        else
            statusLabel.Text = "Optical Lens • " .. formatZoom(opt)
        end
    else
        if currentZoom >= ultraMinZoom then
            statusLabel.Text = "Ultra Digital Zoom"
        elseif currentZoom > normalMaxZoom then
            statusLabel.Text = "Hybrid Digital Zoom"
        else
            statusLabel.Text = "Digital Zoom"
        end
    end

    if currentZoom >= ultraMinZoom then
        zoomLabel.TextColor3 = theme.accent2
    elseif isOptical then
        zoomLabel.TextColor3 = theme.accent
    else
        zoomLabel.TextColor3 = theme.text
    end
end

local function updateEffects()
    local isOptical = getOpticalState(currentZoom)

    local log10Zoom = math.log(currentZoom) / math.log(10)
    local digitalStress = 0

    if currentZoom > 10 then
        digitalStress = math.clamp(log10Zoom * 1.35, 0, 8)
    end

    if isOptical then
        digitalStress = digitalStress * 0.22
    end

    if currentZoom >= ultraMinZoom then
        digitalStress = math.clamp(digitalStress + 1.2, 0, 10)
    end

    if isProMode then
        blurEffect.Size = math.clamp(manualFocus * 18, 0, 24)

        local wb = math.clamp(manualWB, -0.5, 0.5)
        local r = math.clamp(255 - wb * 120, 0, 255)
        local g = math.clamp(255 + wb * 20, 0, 255)
        local b = math.clamp(255 + wb * 120, 0, 255)

        colorEffect.TintColor = Color3.fromRGB(r, g, b)
        colorEffect.Brightness = math.clamp(manualEV, -0.5, 0.5) * 0.9
        colorEffect.Contrast = math.clamp((manualShutter - 0.5) * 0.55, -0.35, 0.35)
        colorEffect.Saturation = math.clamp(wb * 0.35, -0.25, 0.25)
    else
        if isAFMode then
            blurEffect.Size = math.clamp(digitalStress * 0.55, 0, 6)
            colorEffect.TintColor = Color3.fromRGB(255, 255, 255)
            colorEffect.Brightness = 0
            colorEffect.Contrast = math.clamp(digitalStress * 0.012, 0, 0.12)
            colorEffect.Saturation = math.clamp(-digitalStress * 0.018, -0.16, 0)
        else
            blurEffect.Size = math.clamp(manualFocus * 18 + digitalStress * 0.35, 0, 24)
            colorEffect.TintColor = Color3.fromRGB(255, 255, 255)
            colorEffect.Brightness = 0
            colorEffect.Contrast = 0.03
            colorEffect.Saturation = 0
        end
    end
end

-- ตั้งค่าซูม
setTargetZoom = function(z, opts)
    opts = opts or {}
    z = math.clamp(z, minZoom, maxZoom)

    if opts.mode then
        zoomMode = opts.mode
    end

    if opts.snap then
        local isOptical, snap = getOpticalState(z)
        if isOptical then
            z = snap
        end
    end

    if opts.effect then
        local isOptical, snap = getOpticalState(z)
        if isOptical and snap ~= lastOpticalZoom then
            playLensSwitchEffect()
            lastOpticalZoom = snap
        end
    end

    targetZoom = z
    targetLog = math.log(z)

    updateTabButtons()
    updatePresetVisibility()
    updateSliderRange()

    if not opts.fromSlider then
        updateZoomSliderVisual()
    end

    updatePresetHighlights()
end

-- สลับโหมด
switchMode = function(mode)
    zoomMode = mode
    updateTabButtons()
    updatePresetVisibility()
    updateSliderRange()

    if mode == "ULTRA" then
        if targetZoom < ultraMinZoom then
            setTargetZoom(ultraMinZoom, { effect = true })
        else
            updateZoomSliderVisual()
            updatePresetHighlights()
        end
    else
        if targetZoom > normalMaxZoom then
            setTargetZoom(normalMaxZoom, { effect = true })
        else
            updateZoomSliderVisual()
            updatePresetHighlights()
        end
    end
end

-- ปุ่มโหมด
connect(normalTabBtn.MouseButton1Click, function()
    switchMode("NORMAL")
end)

connect(ultraTabBtn.MouseButton1Click, function()
    switchMode("ULTRA")
end)

-- AF / MF
local function updateFocusButtons()
    if isAFMode then
        afBtn.BackgroundColor3 = theme.accent
        afBtn.TextColor3 = Color3.fromRGB(10, 10, 10)
        mfBtn.BackgroundColor3 = theme.card2
        mfBtn.TextColor3 = theme.text
    else
        afBtn.BackgroundColor3 = theme.card2
        afBtn.TextColor3 = theme.text
        mfBtn.BackgroundColor3 = theme.accent
        mfBtn.TextColor3 = Color3.fromRGB(10, 10, 10)
    end
end

connect(afBtn.MouseButton1Click, function()
    isAFMode = true
    updateFocusButtons()
end)

connect(mfBtn.MouseButton1Click, function()
    isAFMode = false
    updateFocusButtons()
end)

-- Pro Mode
connect(proToggle.MouseButton1Click, function()
    isProMode = not isProMode
    proPanel.Visible = isProMode

    if isProMode then
        proToggle.Text = "PRO MODE : ON"
        proToggle.BackgroundColor3 = theme.accent
        proToggle.TextColor3 = Color3.fromRGB(10, 10, 10)
    else
        proToggle.Text = "PRO MODE : OFF"
        proToggle.BackgroundColor3 = theme.card2
        proToggle.TextColor3 = theme.text
    end
end)

-- Minimize / Restore
connect(minimizeBtn.MouseButton1Click, function()
    mainFrame.Visible = false
    floatingCircle.Visible = true
end)

connect(floatingCircle.MouseButton1Click, function()
    if floatSuppressClick then
        floatSuppressClick = false
        return
    end
    mainFrame.Visible = true
    floatingCircle.Visible = false
end)

-- Render loop
connect(RunService.RenderStepped, function(dt)
    local alpha = math.min(dt * 8, 1)
    currentLog = currentLog + (targetLog - currentLog) * alpha
    currentZoom = math.exp(currentLog)

    local fov = (70 / currentZoom) * (1 + lensKick * 0.06)
    pcall(function()
        camera.FieldOfView = math.clamp(fov, 1, 120)
    end)

    updateHUD()
    updateEffects()
end)

-- Cleanup
fullCleanup = function()
    for _, conn in ipairs(cleanup) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    for i = #cleanup, 1, -1 do
        cleanup[i] = nil
    end

    activeSlider = nil

    pcall(function()
        blurEffect:Destroy()
    end)

    pcall(function()
        colorEffect:Destroy()
    end)

    pcall(function()
        screenGui:Destroy()
    end)

    pcall(function()
        camera.FieldOfView = originalFOV
    end)
end

shared.VivoX300Cleanup = fullCleanup

connect(closeBtn.MouseButton1Click, function()
    fullCleanup()
end)

-- เริ่มต้น
updateTabButtons()
updatePresetVisibility()
updateSliderRange()
updateZoomSliderVisual()
updatePresetHighlights()
updateFocusButtons()
updateHUD()
updateEffects()

print("Vivo X300 Pro Camera | Delta Ultra Zoom Loaded")
print("NORMAL: 0.6x - 100x")
print("ULTRA: 1000x - 5000x")
