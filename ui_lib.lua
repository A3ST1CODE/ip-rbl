local HttpService = game:GetService("HttpService")

if not isfolder("A3STICODEUI") then
    makefolder("A3STICODEUI")
end
if not isfolder("A3STICODEUI/Config") then
    makefolder("A3STICODEUI/Config")
end

local gameName = tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name)
gameName = gameName:gsub("[^%w_ ]", "")
gameName = gameName:gsub("%s+", "_")

local CONFIG_FILE = "A3STICODEUI/Config/" .. gameName .. ".json"
local POSITION_FILE = "A3STICODEUI/Config/last_position.json"

ConfigData = {}
Elements = {}
CURRENT_VERSION = nil

local ConfigSystem = {
    Version = nil,
    FilePath = CONFIG_FILE,
    AutoLoad = false,
    AutoSave = false,
    AutoLoadPosition = false,
    SettingsLoaded = false
}

function ConfigSystem:Save()
    if not writefile then
        return false
    end

    if not CURRENT_VERSION then
        return false
    end

    ConfigData._autoload = self.AutoLoad
    ConfigData._autosave = self.AutoSave
    ConfigData._version = CURRENT_VERSION

    local success, err = pcall(function()
        writefile(self.FilePath, HttpService:JSONEncode(ConfigData))
    end)

    if success then
        return true
    else
        return false
    end
end

function ConfigSystem:Load()
    if not CURRENT_VERSION then
        return false
    end

    if not isfile or not isfile(self.FilePath) then
        ConfigData = {_version = CURRENT_VERSION}
        return true
    end

    local success, result = pcall(function()
        return HttpService:JSONDecode(readfile(self.FilePath))
    end)

    if not success then
        ConfigData = {_version = CURRENT_VERSION}
        return false
    end

    if type(result) ~= "table" then
        ConfigData = {_version = CURRENT_VERSION}
        return false
    end

    if result._version ~= CURRENT_VERSION then
        ConfigData = {_version = CURRENT_VERSION}
        return false
    end

    if result._autoload ~= nil then
        self.AutoLoad = result._autoload
    end
    if result._autosave ~= nil then
        self.AutoSave = result._autosave
    end

    if self.AutoLoad then
        ConfigData = result
    else
        ConfigData = {
            _version = CURRENT_VERSION,
            _autoload = self.AutoLoad,
            _autosave = self.AutoSave
        }
    end
    
    self.SettingsLoaded = true
    return true
end

function ConfigSystem:Delete()
    if not delfile or not isfile(self.FilePath) then
        return false
    end

    local success, err = pcall(function()
        delfile(self.FilePath)
    end)

    if success then
        ConfigData = {_version = CURRENT_VERSION}
        return true
    else
        return false
    end
end

function ConfigSystem:LoadElements()
    if not CURRENT_VERSION then
        return
    end

    if not self.SettingsLoaded then
        self:Load()
    end

    if not self.AutoLoad then
        return
    end

    if not isfile(self.FilePath) then
        return
    end

    local success, fileData = pcall(function()
        return HttpService:JSONDecode(readfile(self.FilePath))
    end)

    if not success or type(fileData) ~= "table" then
        return
    end

    for key, value in pairs(fileData) do
        if not ConfigData[key] then
            ConfigData[key] = value
        end
    end

    for key, element in pairs(Elements) do
        if ConfigData[key] ~= nil and element.Set then
            element:Set(ConfigData[key], true)
        end
    end
end

function ConfigSystem:Clear()
    ConfigData = {_version = CURRENT_VERSION}
end

function ConfigSystem:SetAutoConfig(enabled)
    self.AutoLoad = enabled
    self.AutoSave = enabled
    ConfigData._autoload = enabled
    ConfigData._autosave = enabled
    
    self:Save()
    
    if enabled then
        self:LoadElements()
    end
end

function ConfigSystem:GetAutoConfig()
    return self.AutoLoad and self.AutoSave
end

function ConfigSystem:SaveLastPosition()
    if not self.AutoLoadPosition then return end
    
    local LocalPlayer = game:GetService("Players").LocalPlayer
    local char = LocalPlayer.Character
    
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local cframe = hrp.CFrame
        
        local positionData = {
            x = cframe.X,
            y = cframe.Y,
            z = cframe.Z,
            rx = select(1, cframe:ToEulerAnglesYXZ()),
            ry = select(2, cframe:ToEulerAnglesYXZ()),
            rz = select(3, cframe:ToEulerAnglesYXZ()),
            _enabled = true
        }
        
        if writefile then
            local success, err = pcall(function()
                writefile(POSITION_FILE, HttpService:JSONEncode(positionData))
            end)
            if not success then
                warn("[Config] ✗ Failed to save position: " .. tostring(err))
            end
        end
    end
end

function ConfigSystem:RestoreLastPosition()
    if not (self.AutoLoad and self.AutoLoadPosition) then return end
    
    if not isfile or not isfile(POSITION_FILE) then
        return
    end
    
    local LocalPlayer = game:GetService("Players").LocalPlayer
    
    task.spawn(function()
        local success, posData = pcall(function()
            return HttpService:JSONDecode(readfile(POSITION_FILE))
        end)
        
        if not success or not posData then
            return
        end
        
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        
        if hrp and posData.x and posData.y and posData.z then
            task.wait(1)
            local newCFrame = CFrame.new(posData.x, posData.y, posData.z) * CFrame.Angles(posData.rx or 0, posData.ry or 0, posData.rz or 0)
            hrp.CFrame = newCFrame
        end
    end)
end

function ConfigSystem:SetAutoLoadPosition(enabled)
    if enabled and not self:GetAutoConfig() then
        return false
    end
    
    self.AutoLoadPosition = enabled
    return true
end

function ConfigSystem:LoadPositionConfig()
    if not isfile or not isfile(POSITION_FILE) then
        self.AutoLoadPosition = false
        return
    end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(POSITION_FILE))
    end)
    
    if success and data and data._enabled then
        self.AutoLoadPosition = true
    end
end

function ConfigSystem:DeletePosition()
    if delfile and isfile(POSITION_FILE) then
        local success, err = pcall(function()
            delfile(POSITION_FILE)
        end)
        if success then
            self.AutoLoadPosition = false
            return true
        else
            warn("[Config] ✗ Failed to delete position: " .. tostring(err))
            return false
        end
    end
    return false
end

function ConfigSystem:GetConfigPath()
    return self.FilePath
end

function ConfigSystem:GetConfigData()
    return ConfigData
end

function ConfigSystem:SetConfigData(data)
    if type(data) == "table" then
        ConfigData = data
        ConfigData._version = CURRENT_VERSION
        return true
    else
        return false
    end
end

function ConfigSystem:LoadSettings()
    if not self.SettingsLoaded and self:Load() then
        if ConfigData._autoload ~= nil then
            self.AutoLoad = ConfigData._autoload
        end
        if ConfigData._autosave ~= nil then
            self.AutoSave = ConfigData._autosave
        end
        self.SettingsLoaded = true
    end
end

function SaveConfig()
    return ConfigSystem:Save()
end

function LoadConfigFromFile()
    return ConfigSystem:Load()
end

function LoadConfigElements()
    return ConfigSystem:LoadElements()
end

function SaveLastPosition()
    return ConfigSystem:SaveLastPosition()
end

function RestoreLastPosition()
    return ConfigSystem:RestoreLastPosition()
end

local Icons = {
    fish = "rbxassetid://124360663785796",
    star = "rbxassetid://136141469398409",
    globe = "rbxassetid://114238209622913",
    map = "rbxassetid://95107167260947",
	calendar = "rbxassetid://114792700814035",
	shopping = "rbxassetid://71885477293226",
	cloud = "rbxassetid://105547081967408",
	bell = "rbxassetid://97392696311902",
	loader = "rbxassetid://78408734580845",
	usercog = "rbxassetid://92795491530865",
    cog = "rbxassetid://116544501716299",
}

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local CoreGui = game:GetService("CoreGui")
local viewport = workspace.CurrentCamera.ViewportSize

local function isMobileDevice()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled
end

local isMobile = isMobileDevice()
local isMaximized = false
local normalSize = nil
local normalPosition = nil
local changeResizeObject = nil

local function safeSize(pxWidth, pxHeight)
    local scaleX = pxWidth / viewport.X
    local scaleY = pxHeight / viewport.Y

    if isMobile then
        if scaleX > 0.5 then
            scaleX = 0.5
        end
        if scaleY > 0.3 then
            scaleY = 0.3
        end
    end

    return UDim2.new(scaleX, 0, scaleY, 0)
end

local function MakeDraggable(topbarobject, object)
    local function CustomPos(topbarobject, object)
        local Dragging, DragInput, DragStart, StartPosition

        local function UpdatePos(input)
            local Delta = input.Position - DragStart
            local pos =
                UDim2.new(
                StartPosition.X.Scale,
                StartPosition.X.Offset + Delta.X,
                StartPosition.Y.Scale,
                StartPosition.Y.Offset + Delta.Y
            )
            local Tween = TweenService:Create(object, TweenInfo.new(0.2), {Position = pos})
            Tween:Play()
        end

        topbarobject.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                Dragging = true
                DragStart = input.Position
                StartPosition = object.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                    end
                end)
            end
        end)

        topbarobject.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                DragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == DragInput and Dragging then
                UpdatePos(input)
            end
        end)
    end

    local function CustomSize(object)
        local Dragging, DragInput, DragStart, StartSize

        local minSizeX, minSizeY
        local defSizeX, defSizeY

        if isMobile then
            minSizeX, minSizeY = 100, 100
            defSizeX, defSizeY = 600, 300
        else
            minSizeX, minSizeY = 100, 100
            defSizeX, defSizeY = 640, 400
        end

        object.Size = UDim2.new(0, defSizeX, 0, defSizeY)

        local changesizeobject = Instance.new("Frame")
        changesizeobject.AnchorPoint = Vector2.new(1, 1)
        changesizeobject.BackgroundTransparency = 1
        changesizeobject.Size = UDim2.new(0, 40, 0, 40)
        changesizeobject.Position = UDim2.new(1, 20, 1, 20)
        changesizeobject.Name = "changesizeobject"
        changesizeobject.Parent = object
        changeResizeObject = changesizeobject

        local function UpdateSize(input)
            if isMaximized then
                return
            end

            local Delta = input.Position - DragStart
            local newWidth = StartSize.X.Offset + Delta.X
            local newHeight = StartSize.Y.Offset + Delta.Y

            newWidth = math.max(newWidth, minSizeX)
            newHeight = math.max(newHeight, minSizeY)

            local Tween = TweenService:Create(object, TweenInfo.new(0.2), {Size = UDim2.new(0, newWidth, 0, newHeight)})
            Tween:Play()
        end

        changesizeobject.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                Dragging = true
                DragStart = input.Position
                StartSize = object.Size
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        Dragging = false
                    end
                end)
            end
        end)

        changesizeobject.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                DragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == DragInput and Dragging then
                UpdateSize(input)
            end
        end)
    end

    CustomSize(object)
    CustomPos(topbarobject, object)
end

function CircleClick(Button, X, Y)
    spawn(function()
        Button.ClipsDescendants = true
        local Circle = Instance.new("ImageLabel")
        Circle.Image = "rbxassetid://266543268"
        Circle.ImageColor3 = Color3.fromRGB(155, 155, 155)
        Circle.ImageTransparency = 0.8999999761581421
        Circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Circle.BackgroundTransparency = 1
        Circle.ZIndex = 10
        Circle.Name = "Circle"
        Circle.Parent = Button

        local NewX = X - Circle.AbsolutePosition.X
        local NewY = Y - Circle.AbsolutePosition.Y
        Circle.Position = UDim2.new(0, NewX, 0, NewY)
        local Size = 0
        if Button.AbsoluteSize.X > Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.X * 1.5
        elseif Button.AbsoluteSize.X < Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.Y * 1.5
        elseif Button.AbsoluteSize.X == Button.AbsoluteSize.Y then
            Size = Button.AbsoluteSize.X * 1.5
        end

        local Time = 0.5
        Circle:TweenSizeAndPosition(UDim2.new(0, Size, 0, Size), UDim2.new(0.5, -Size / 2, 0.5, -Size / 2), "Out", "Quad", Time, false, nil)
        for i = 1, 10 do
            Circle.ImageTransparency = Circle.ImageTransparency + 0.01
            wait(Time / 10)
        end
        Circle:Destroy()
    end)
end

local AesticUI = {}

function AesticUI:SetAutoConfig(enabled)
    ConfigSystem:SetAutoConfig(enabled)
end

function AesticUI:GetAutoConfig()
    return ConfigSystem.AutoLoad and ConfigSystem.AutoSave
end

function AesticUI:GetAutoLoad()
    return ConfigSystem.AutoLoad
end

function AesticUI:GetAutoSave()
    return ConfigSystem.AutoSave
end

function AesticUI:Save()
    return ConfigSystem:Save()
end

function AesticUI:Load()
    local success = ConfigSystem:Load()
    if success and ConfigSystem.AutoLoad then
        self:LoadElements()
    end
    return success
end

function AesticUI:Delete()
    return ConfigSystem:Delete()
end

function AesticUI:LoadElements()
    ConfigSystem:LoadElements()
end

function AesticUI:SetAutoLoadPosition(enabled)
    return ConfigSystem:SetAutoLoadPosition(enabled)
end

function AesticUI:AutoLoadPosition()
    return ConfigSystem.AutoLoadPosition
end

function AesticUI:SaveLastPosition()
    return ConfigSystem:SaveLastPosition()
end

function AesticUI:RestoreLastPosition()
    return ConfigSystem:RestoreLastPosition()
end

function AesticUI:Window(GuiConfig)
    GuiConfig = GuiConfig or {}
    GuiConfig.Title = GuiConfig.Title or "AesticUI"
    GuiConfig.Footer = GuiConfig.Footer or "AesticUI :3"
    GuiConfig.Color = GuiConfig.Color or Color3.fromRGB(155, 155, 155)
    GuiConfig["Tab Width"] = GuiConfig["Tab Width"] or 120
    GuiConfig.Version = GuiConfig.Version or 1
    GuiConfig.AutoConfig = GuiConfig.AutoConfig or false
    GuiConfig.ToggleIcon = GuiConfig.ToggleIcon or "rbxassetid://71242496908510"
    GuiConfig.TogglePosition = GuiConfig.TogglePosition or UDim2.new(0, 35, 0, 85)

    CURRENT_VERSION = GuiConfig.Version
    ConfigSystem.Version = GuiConfig.Version

    ConfigSystem:Load()
    ConfigSystem:LoadPositionConfig()

    local shouldUseFileSettings = ConfigSystem.SettingsLoaded and ConfigData._autoload ~= nil
    
    if shouldUseFileSettings then
        ConfigSystem:SetAutoConfig(ConfigSystem.AutoLoad)
    else
        ConfigSystem:SetAutoConfig(GuiConfig.AutoConfig)
    end

    if ConfigSystem.AutoLoad then
        ConfigSystem:LoadElements()
    end

    local GuiFunc = {}

    function GuiFunc:SaveConfig()
        return ConfigSystem:Save()
    end

    function GuiFunc:LoadConfig()
        ConfigSystem:Load()
        if ConfigSystem.AutoLoad then
            ConfigSystem:LoadElements()
        end
        return true
    end

    function GuiFunc:DeleteConfig()
        return ConfigSystem:Delete()
    end

    function GuiFunc:LoadElements()
        ConfigSystem:LoadElements()
    end

    function GuiFunc:SetAutoConfig(enabled)
        ConfigSystem:SetAutoConfig(enabled)
    end

    function GuiFunc:GetAutoConfig()
        return ConfigSystem.AutoLoad and ConfigSystem.AutoSave
    end

    function GuiFunc:GetAutoLoad()
        return ConfigSystem.AutoLoad
    end

    function GuiFunc:GetAutoSave()
        return ConfigSystem.AutoSave
    end

    function GuiFunc:AddAutoSave(key, element)
        if element and element.Set then
            Elements[key] = element
        end
    end
    
    local AesticUI = Instance.new("ScreenGui")
    local DropShadowHolder = Instance.new("Frame")
    local DropShadow = Instance.new("ImageLabel")
    local Main = Instance.new("Frame")
    local UICorner = Instance.new("UICorner")
    local Top = Instance.new("Frame")
    local TextLabel = Instance.new("TextLabel")
    local UICorner1 = Instance.new("UICorner")
    local TextLabel1 = Instance.new("TextLabel")
    local Close = Instance.new("TextButton")
    local ImageLabel1 = Instance.new("ImageLabel")
    local Min = Instance.new("TextButton")
    local ImageLabel2 = Instance.new("ImageLabel")
    local Max = Instance.new("TextButton")
    local ImageLabel3 = Instance.new("ImageLabel")
    local LayersTab = Instance.new("Frame")
    local UICorner2 = Instance.new("UICorner")
    local DecideFrame = Instance.new("Frame")
    local Layers = Instance.new("Frame")
    local UICorner6 = Instance.new("UICorner")
    local NameTab = Instance.new("TextLabel")
    local LayersReal = Instance.new("Frame")
    local LayersFolder = Instance.new("Folder")
    local LayersPageLayout = Instance.new("UIPageLayout")

    AesticUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    AesticUI.Name = "AesticUI"
    AesticUI.ResetOnSpawn = false
    AesticUI.Parent = game:GetService("CoreGui")

    DropShadowHolder.BackgroundTransparency = 1
    DropShadowHolder.BorderSizePixel = 0
    DropShadowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadowHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
    if isMobile then
        DropShadowHolder.Size = safeSize(600, 300)
    else
        DropShadowHolder.Size = safeSize(640, 400)
    end
    DropShadowHolder.ZIndex = 0
    DropShadowHolder.Name = "DropShadowHolder"
    DropShadowHolder.Parent = AesticUI

    DropShadowHolder.Position =
        UDim2.new(
        0,
        (AesticUI.AbsoluteSize.X // 2 - DropShadowHolder.Size.X.Offset // 2),
        0,
        (AesticUI.AbsoluteSize.Y // 2 - DropShadowHolder.Size.Y.Offset // 2)
    )
    DropShadow.Image = "rbxassetid://6015897843"
    DropShadow.ImageColor3 = Color3.fromRGB(15, 15, 15)
    DropShadow.ImageTransparency = 1
    DropShadow.ScaleType = Enum.ScaleType.Slice
    DropShadow.SliceCenter = Rect.new(49, 49, 450, 450)
    DropShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadow.BackgroundTransparency = 1
    DropShadow.BorderSizePixel = 0
    DropShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadow.Size = UDim2.new(1, 47, 1, 47)
    DropShadow.ZIndex = 0
    DropShadow.Name = "DropShadow"
    DropShadow.Parent = DropShadowHolder

    if GuiConfig.Theme then
        Main:Destroy()
        Main = Instance.new("ImageLabel")
        Main.Image = "rbxassetid://" .. GuiConfig.Theme
        Main.ScaleType = Enum.ScaleType.Crop
        Main.BackgroundTransparency = 1
        Main.ImageTransparency = GuiConfig.ThemeTransparency or 0.15
    else
        Main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        Main.BackgroundTransparency = 0.15
    end

    Main.AnchorPoint = Vector2.new(0.5, 0.5)
    Main.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Main.BorderSizePixel = 0
    Main.Position = UDim2.new(0.5, 0, 0.5, 0)
    Main.Size = UDim2.new(1, -47, 1, -47)
    Main.Name = "Main"
    Main.Parent = DropShadow

    UICorner.Parent = Main

    Top.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Top.BackgroundTransparency = 0.9990000128746033
    Top.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Top.BorderSizePixel = 0
    Top.Size = UDim2.new(1, 0, 0, 38)
    Top.Name = "Top"
    Top.Parent = Main

    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.Text = GuiConfig.Title
    TextLabel.TextColor3 = GuiConfig.Color
    TextLabel.TextSize = 14
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.BackgroundTransparency = 0.9990000128746033
    TextLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
    TextLabel.BorderSizePixel = 0
    TextLabel.Size = UDim2.new(1, -100, 1, 0)
    TextLabel.Position = UDim2.new(0, 10, 0, 0)
    TextLabel.Parent = Top

    UICorner1.Parent = Top

    TextLabel1.Font = Enum.Font.GothamBold
    TextLabel1.Text = GuiConfig.Footer
    TextLabel1.TextColor3 = GuiConfig.Color
    TextLabel1.TextSize = 14
    TextLabel1.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel1.BackgroundTransparency = 0.9990000128746033
    TextLabel1.BorderColor3 = Color3.fromRGB(0, 0, 0)
    TextLabel1.BorderSizePixel = 0
    TextLabel1.Size = UDim2.new(1, -(TextLabel.TextBounds.X + 104), 1, 0)
    TextLabel1.Position = UDim2.new(0, TextLabel.TextBounds.X + 15, 0, 0)
    TextLabel1.Parent = Top

    Close.Font = Enum.Font.SourceSans
    Close.Text = ""
    Close.TextColor3 = Color3.fromRGB(0, 0, 0)
    Close.TextSize = 14
    Close.AnchorPoint = Vector2.new(1, 0.5)
    Close.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Close.BackgroundTransparency = 0.9990000128746033
    Close.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Close.BorderSizePixel = 0
    Close.Position = UDim2.new(1, -8, 0.5, 0)
    Close.Size = UDim2.new(0, 25, 0, 25)
    Close.Name = "Close"
    Close.Parent = Top

    ImageLabel1.Image = "rbxassetid://130833076800948"
    ImageLabel1.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel1.BackgroundTransparency = 0.9990000128746033
    ImageLabel1.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ImageLabel1.BorderSizePixel = 0
    ImageLabel1.Position = UDim2.new(0.49, 0, 0.5, 0)
    ImageLabel1.Size = UDim2.new(1, -8, 1, -8)
    ImageLabel1.Parent = Close

    Min.Font = Enum.Font.SourceSans
    Min.Text = ""
    Min.TextColor3 = Color3.fromRGB(0, 0, 0)
    Min.TextSize = 14
    Min.AnchorPoint = Vector2.new(1, 0.5)
    Min.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Min.BackgroundTransparency = 0.9990000128746033
    Min.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Min.BorderSizePixel = 0
    Min.Position = UDim2.new(1, -68, 0.5, 0)
    Min.Size = UDim2.new(0, 25, 0, 25)
    Min.Name = "Min"
    Min.Parent = Top

    ImageLabel2.Image = "rbxassetid://86228338265375"
    ImageLabel2.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel2.BackgroundTransparency = 0.9990000128746033
    ImageLabel2.ImageTransparency = 0.2
    ImageLabel2.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ImageLabel2.BorderSizePixel = 0
    ImageLabel2.Position = UDim2.new(0.5, 0, 0.5, 0)
    ImageLabel2.Size = UDim2.new(1, -9, 1, -9)
    ImageLabel2.Parent = Min

    Max.Font = Enum.Font.SourceSans
    Max.Text = ""
    Max.TextColor3 = Color3.fromRGB(0, 0, 0)
    Max.TextSize = 14
    Max.AnchorPoint = Vector2.new(1, 0.5)
    Max.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Max.BackgroundTransparency = 0.9990000128746033
    Max.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Max.BorderSizePixel = 0
    Max.Position = UDim2.new(1, -38, 0.5, 0)
    Max.Size = UDim2.new(0, 25, 0, 25)
    Max.Name = "Max"
    Max.Parent = Top

    ImageLabel3.Image = "rbxassetid://105398742901426"
    ImageLabel3.AnchorPoint = Vector2.new(0.5, 0.5)
    ImageLabel3.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel3.BackgroundTransparency = 0.9990000128746033
    ImageLabel3.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ImageLabel3.BorderSizePixel = 0
    ImageLabel3.Position = UDim2.new(0.5, 0, 0.5, 0)
    ImageLabel3.Size = UDim2.new(1, -8, 1, -8)
    ImageLabel3.Parent = Max

    LayersTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LayersTab.BackgroundTransparency = 0.9990000128746033
    LayersTab.BorderColor3 = Color3.fromRGB(0, 0, 0)
    LayersTab.BorderSizePixel = 0
    LayersTab.Position = UDim2.new(0, 9, 0, 50)
    LayersTab.Size = UDim2.new(0, GuiConfig["Tab Width"], 1, -59)
    LayersTab.Name = "LayersTab"
    LayersTab.Parent = Main

    UICorner2.CornerRadius = UDim.new(0, 2)
    UICorner2.Parent = LayersTab

    DecideFrame.AnchorPoint = Vector2.new(0.5, 0)
    DecideFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    DecideFrame.BackgroundTransparency = 0.85
    DecideFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
    DecideFrame.BorderSizePixel = 0
    DecideFrame.Position = UDim2.new(0.5, 0, 0, 38)
    DecideFrame.Size = UDim2.new(1, 0, 0, 1)
    DecideFrame.Name = "DecideFrame"
    DecideFrame.Parent = Main

    Layers.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Layers.BackgroundTransparency = 0.9990000128746033
    Layers.BorderColor3 = Color3.fromRGB(0, 0, 0)
    Layers.BorderSizePixel = 0
    Layers.Position = UDim2.new(0, GuiConfig["Tab Width"] + 18, 0, 50)
    Layers.Size = UDim2.new(1, -(GuiConfig["Tab Width"] + 9 + 18), 1, -59)
    Layers.Name = "Layers"
    Layers.Parent = Main

    UICorner6.CornerRadius = UDim.new(0, 2)
    UICorner6.Parent = Layers

    NameTab.Font = Enum.Font.GothamBold
    NameTab.Text = ""
    NameTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    NameTab.TextSize = 24
    NameTab.TextWrapped = true
    NameTab.TextXAlignment = Enum.TextXAlignment.Left
    NameTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    NameTab.BackgroundTransparency = 0.9990000128746033
    NameTab.BorderColor3 = Color3.fromRGB(0, 0, 0)
    NameTab.BorderSizePixel = 0
    NameTab.Size = UDim2.new(1, 0, 0, 30)
    NameTab.Name = "NameTab"
    NameTab.Parent = Layers

    LayersReal.AnchorPoint = Vector2.new(0, 1)
    LayersReal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LayersReal.BackgroundTransparency = 0.9990000128746033
    LayersReal.BorderColor3 = Color3.fromRGB(0, 0, 0)
    LayersReal.BorderSizePixel = 0
    LayersReal.ClipsDescendants = true
    LayersReal.Position = UDim2.new(0, 0, 1, 0)
    LayersReal.Size = UDim2.new(1, 0, 1, -33)
    LayersReal.Name = "LayersReal"
    LayersReal.Parent = Layers

    LayersFolder.Name = "LayersFolder"
    LayersFolder.Parent = LayersReal

    LayersPageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    LayersPageLayout.Name = "LayersPageLayout"
    LayersPageLayout.Parent = LayersFolder
    LayersPageLayout.TweenTime = 0.5
    LayersPageLayout.EasingDirection = Enum.EasingDirection.InOut
    LayersPageLayout.EasingStyle = Enum.EasingStyle.Quad

    local ScrollTab = Instance.new("ScrollingFrame")
    local UIListLayout = Instance.new("UIListLayout")

    ScrollTab.CanvasSize = UDim2.new(0, 0, 1.10000002, 0)
    ScrollTab.ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0)
    ScrollTab.ScrollBarThickness = 0
    ScrollTab.Active = true
    ScrollTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ScrollTab.BackgroundTransparency = 0.9990000128746033
    ScrollTab.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ScrollTab.BorderSizePixel = 0
    ScrollTab.Size = UDim2.new(1, 0, 1, 0)
    ScrollTab.Name = "ScrollTab"
    ScrollTab.Parent = LayersTab

    UIListLayout.Padding = UDim.new(0, 3)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Parent = ScrollTab

    local function UpdateSize1()
        local OffsetY = 0
        for _, child in ScrollTab:GetChildren() do
            if child.Name ~= "UIListLayout" then
                OffsetY = OffsetY + 3 + child.Size.Y.Offset
            end
        end
        ScrollTab.CanvasSize = UDim2.new(0, 0, 0, OffsetY)
    end
    ScrollTab.ChildAdded:Connect(UpdateSize1)
    ScrollTab.ChildRemoved:Connect(UpdateSize1)

    function GuiFunc:DestroyGui()
        if CoreGui:FindFirstChild("AesticUI") then
            AesticUI:Destroy()
        end
    end

    local function UpdateToggleUIVisibility()
        if game.CoreGui:FindFirstChild("ToggleUIButton") then
            local toggleButton = game.CoreGui.ToggleUIButton
            toggleButton.Enabled = not DropShadowHolder.Visible
        end
    end

    local originalVisible = DropShadowHolder.Visible
    DropShadowHolder:GetPropertyChangedSignal("Visible"):Connect(
        function()
            UpdateToggleUIVisibility()
        end
    )

    Min.Activated:Connect(
        function()
            CircleClick(Min, Mouse.X, Mouse.Y)
            DropShadowHolder.Visible = false
            UpdateToggleUIVisibility()
        end
    )

    local function UpdateMaxButtonAppearance()
        if isMaximized then
            ImageLabel3.Rotation = 90
        else
            ImageLabel3.Rotation = 0
        end
    end

    local function ToggleMaximize()
        CircleClick(Max, Mouse.X, Mouse.Y)

        if not isMaximized then
            normalSize = DropShadowHolder.Size
            normalPosition = DropShadowHolder.Position

            TweenService:Create(
                DropShadowHolder,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                {
                    Size = UDim2.new(1, -10, 1, -10),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5)
                }
            ):Play()

            isMaximized = true

            if changeResizeObject then
                changeResizeObject.Visible = false
            end
        else
            if normalSize and normalPosition then
                TweenService:Create(
                    DropShadowHolder,
                    TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                    {
                        Size = normalSize,
                        Position = normalPosition,
                        AnchorPoint = Vector2.new(0.5, 0.5)
                    }
                ):Play()
            end

            isMaximized = false

            if changeResizeObject then
                changeResizeObject.Visible = true
            end
        end

        UpdateMaxButtonAppearance()
    end
    Max.Activated:Connect(ToggleMaximize)

    Close.Activated:Connect(
        function()
            CircleClick(Close, Mouse.X, Mouse.Y)

            local Overlay = Instance.new("Frame")
            Overlay.Size = UDim2.new(1, 0, 1, 0)
            Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            Overlay.BackgroundTransparency = 0.3
            Overlay.ZIndex = 50
            Overlay.Parent = DropShadowHolder

            local Dialog = Instance.new("Frame")
            Dialog.Size = UDim2.new(0, 300, 0, 150)
            Dialog.Position = UDim2.new(0.5, -150, 0.5, -75)
            Dialog.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            Dialog.BackgroundTransparency = 0.1
            Dialog.BorderSizePixel = 0
            Dialog.ZIndex = 51
            Dialog.Parent = Overlay

            local UICorner = Instance.new("UICorner", Dialog)
            UICorner.CornerRadius = UDim.new(0, 8)

            local Shadow = Instance.new("Frame")
            Shadow.Size = UDim2.new(1, 8, 1, 8)
            Shadow.Position = UDim2.new(0, -4, 0, -4)
            Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            Shadow.BackgroundTransparency = 0.8
            Shadow.BorderSizePixel = 0
            Shadow.ZIndex = 50
            Shadow.Parent = Dialog
            
            local ShadowCorner = Instance.new("UICorner", Shadow)
            ShadowCorner.CornerRadius = UDim.new(0, 12)

            local Title = Instance.new("TextLabel")
            Title.Size = UDim2.new(1, 0, 0, 40)
            Title.Position = UDim2.new(0, 0, 0, 4)
            Title.BackgroundTransparency = 1
            Title.Font = Enum.Font.GothamBold
            Title.Text = "Close Window"
            Title.TextSize = 22
            Title.TextColor3 = Color3.fromRGB(255, 255, 255)
            Title.ZIndex = 52
            Title.Parent = Dialog

            local Message = Instance.new("TextLabel")
            Message.Size = UDim2.new(1, -20, 0, 60)
            Message.Position = UDim2.new(0, 10, 0, 30)
            Message.BackgroundTransparency = 1
            Message.Font = Enum.Font.Gotham
            Message.Text = "Do you want to close this window?\nYou will not be able to open it again"
            Message.TextSize = 14
            Message.TextColor3 = Color3.fromRGB(200, 200, 200)
            Message.TextWrapped = true
            Message.ZIndex = 52
            Message.Parent = Dialog

            local Yes = Instance.new("TextButton")
            Yes.Size = UDim2.new(0.45, -10, 0, 35)
            Yes.Position = UDim2.new(0.05, 0, 1, -55)
            Yes.BackgroundColor3 = GuiConfig.Color
            Yes.BackgroundTransparency = 0.7
            Yes.Text = "Yes"
            Yes.Font = Enum.Font.GothamBold
            Yes.TextSize = 15
            Yes.TextColor3 = Color3.fromRGB(255, 255, 255)
            Yes.TextTransparency = 0.1
            Yes.ZIndex = 52
            Yes.Name = "Yes"
            Yes.Parent = Dialog
            local YesCorner = Instance.new("UICorner", Yes)
            YesCorner.CornerRadius = UDim.new(0, 6)

            Yes.MouseEnter:Connect(
                function()
                    TweenService:Create(Yes, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
                end
            )
            Yes.MouseLeave:Connect(
                function()
                    TweenService:Create(Yes, TweenInfo.new(0.2), {BackgroundTransparency = 0.7}):Play()
                end
            )

            local Cancel = Instance.new("TextButton")
            Cancel.Size = UDim2.new(0.45, -10, 0, 35)
            Cancel.Position = UDim2.new(0.5, 10, 1, -55)
            Cancel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            Cancel.BackgroundTransparency = 0.7
            Cancel.Text = "Cancel"
            Cancel.Font = Enum.Font.GothamBold
            Cancel.TextSize = 15
            Cancel.TextColor3 = Color3.fromRGB(255, 255, 255)
            Cancel.TextTransparency = 0.1
            Cancel.ZIndex = 52
            Cancel.Name = "Cancel"
            Cancel.Parent = Dialog
            local CancelCorner = Instance.new("UICorner", Cancel)
            CancelCorner.CornerRadius = UDim.new(0, 6)

            Cancel.MouseEnter:Connect(
                function()
                    TweenService:Create(Cancel, TweenInfo.new(0.2), {BackgroundTransparency = 0.5}):Play()
                end
            )
            Cancel.MouseLeave:Connect(
                function()
                    TweenService:Create(Cancel, TweenInfo.new(0.2), {BackgroundTransparency = 0.7}):Play()
                end
            )

            Yes.MouseButton1Click:Connect(
                function()
                    if AesticUI then
                        AesticUI:Destroy()
                    end
                    if game.CoreGui:FindFirstChild("ToggleUIButton") then
                        game.CoreGui.ToggleUIButton:Destroy()
                    end
                    Overlay:Destroy()
                end
            )

            Cancel.MouseButton1Click:Connect(
                function()
                    Overlay:Destroy()
                end
            )
        end
    )

    local ToggleKey = Enum.KeyCode.X
    local CloseKey = Enum.KeyCode.F4
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then
            return
        end
        if input.KeyCode == ToggleKey then
            if DropShadowHolder then
                DropShadowHolder.Visible = not DropShadowHolder.Visible
            end
        elseif input.KeyCode == CloseKey then
            if AesticUI then
                AesticUI:Destroy()
                if game.CoreGui:FindFirstChild("ToggleUIButton") then
                    game.CoreGui.ToggleUIButton:Destroy()
                end
            end
        end
    end)

    function GuiFunc:ToggleUI()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Parent = game:GetService("CoreGui")
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.Name = "ToggleUIButton"
        ScreenGui.Enabled = false
        
        getgenv()._AesticDragBtnPos = getgenv()._AesticDragBtnPos or GuiConfig.TogglePosition or UDim2.new(0, 150, 0, 100)
        
        local MainButton = Instance.new("ImageButton")
        MainButton.Parent = ScreenGui
        MainButton.Size = UDim2.new(0, 45, 0, 45)
        MainButton.Position = getgenv()._AesticDragBtnPos
        MainButton.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
        MainButton.AutoButtonColor = false
        MainButton.ImageColor3 = Color3.fromRGB(255, 255, 255)
        
        if GuiConfig.ToggleIcon then
            MainButton.Image = GuiConfig.ToggleIcon
        else
            MainButton.Image = "rbxassetid://91527058618782"
        end
        
        MainButton.ScaleType = Enum.ScaleType.Fit

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 8)
        UICorner.Parent = MainButton

        local UIStroke = Instance.new("UIStroke")
        UIStroke.Color = Color3.fromRGB(255, 255, 255)
        UIStroke.Thickness = 2
        UIStroke.Parent = MainButton

        local hoverFrame = Instance.new("Frame")
        hoverFrame.Name = "HoverEffect"
        hoverFrame.Size = UDim2.new(1, 0, 1, 0)
        hoverFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hoverFrame.BackgroundTransparency = 0.9
        hoverFrame.BorderSizePixel = 0
        hoverFrame.ZIndex = 0
        hoverFrame.Visible = false
        hoverFrame.Parent = MainButton
        
        local hoverCorner = Instance.new("UICorner")
        hoverCorner.CornerRadius = UDim.new(0, 8)
        hoverCorner.Parent = hoverFrame

        local function setHoverState(isHovering)
            if isHovering then
                TweenService:Create(MainButton, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Color3.fromRGB(45, 45, 45)
                }):Play()
                
                TweenService:Create(MainButton, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    ImageTransparency = 0
                }):Play()
                
                hoverFrame.Visible = true
                TweenService:Create(hoverFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 0.85
                }):Play()
            else
                TweenService:Create(MainButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = Color3.fromRGB(31, 31, 31)
                }):Play()

                TweenService:Create(MainButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    ImageTransparency = 0.1
                }):Play()
                
                TweenService:Create(hoverFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundTransparency = 0.95
                }):Play()
                
                task.wait(0.2)
                hoverFrame.Visible = false
            end
        end

        MainButton.MouseEnter:Connect(function()
            setHoverState(true)
        end)
        
        MainButton.MouseLeave:Connect(function()
            setHoverState(false)
        end)
        
        MainButton.MouseButton1Down:Connect(function()
            TweenService:Create(MainButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(55, 55, 55)
            }):Play()
            
            TweenService:Create(hoverFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 0.8
            }):Play()
        end)
        
        MainButton.MouseButton1Up:Connect(function()
            TweenService:Create(MainButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            }):Play()
            
            TweenService:Create(hoverFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                BackgroundTransparency = 0.85
            }):Play()
        end)

        local dragging = false
        local dragStart, startPos

        local function update(input)
            local delta = input.Position - dragStart
            MainButton.Position = UDim2.new(
                startPos.X.Scale, 
                startPos.X.Offset + delta.X, 
                startPos.Y.Scale, 
                startPos.Y.Offset + delta.Y
            )
            getgenv()._AesticDragBtnPos = MainButton.Position
        end

        MainButton.InputBegan:Connect(
            function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    dragStart = input.Position
                    startPos = MainButton.Position
                    input.Changed:Connect(
                        function()
                            if input.UserInputState == Enum.UserInputState.End then
                                dragging = false
                                setHoverState(true)
                            end
                        end
                    )
                end
            end
        )

        MainButton.InputChanged:Connect(
            function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input)
                end
            end
        )

        UserInputService.InputChanged:Connect(
            function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    update(input)
                end
            end
        )

        MainButton.MouseButton1Click:Connect(function()
            if DropShadowHolder then
                DropShadowHolder.Visible = not DropShadowHolder.Visible
            end
        end)

        local function updateToggleVisibility()
            if DropShadowHolder then
                ScreenGui.Enabled = not DropShadowHolder.Visible
            else
                ScreenGui.Enabled = true
            end
        end

        if DropShadowHolder then
            DropShadowHolder:GetPropertyChangedSignal("Visible"):Connect(updateToggleVisibility)
        end

        MainButton.ImageTransparency = 0.1
        UIStroke.Transparency = 0.5

        updateToggleVisibility()

        local function onWindowDestroyed()
            if ScreenGui and ScreenGui.Parent then
                ScreenGui:Destroy()
            end
        end

        if AesticUI then
            AesticUI.Destroying:Connect(onWindowDestroyed)
        end

        GuiFunc.ToggleButton = MainButton
        GuiFunc.ToggleGui = ScreenGui

        function GuiFunc:ShowToggleButton(show)
            if ScreenGui then
                ScreenGui.Enabled = show
            end
        end

        function GuiFunc:SetTogglePosition(position)
            if MainButton then
                MainButton.Position = position
                getgenv()._AesticDragBtnPos = position
            end
        end

        function GuiFunc:SetToggleIcon(iconId)
            if MainButton then
                MainButton.Image = iconId
            end
        end

        function GuiFunc:SetHoverColor(color)
            if hoverFrame then
                hoverFrame.BackgroundColor3 = color
            end
        end

        return ScreenGui
    end

    GuiFunc:ToggleUI()

    DropShadowHolder.Size = UDim2.new(0, 115 + TextLabel.TextBounds.X + 1 + TextLabel1.TextBounds.X, 0, 350)
    MakeDraggable(Top, DropShadowHolder)

    local MoreBlur = Instance.new("Frame")
    local DropShadowHolder1 = Instance.new("Frame")
    local DropShadow1 = Instance.new("ImageLabel")
    local UICorner28 = Instance.new("UICorner")
    local ConnectButton = Instance.new("TextButton")

    MoreBlur.AnchorPoint = Vector2.new(1, 1)
    MoreBlur.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    MoreBlur.BackgroundTransparency = 0.999
    MoreBlur.BorderColor3 = Color3.fromRGB(0, 0, 0)
    MoreBlur.BorderSizePixel = 0
    MoreBlur.ClipsDescendants = true
    MoreBlur.Position = UDim2.new(1, 8, 1, 8)
    MoreBlur.Size = UDim2.new(1, 154, 1, 54)
    MoreBlur.Visible = false
    MoreBlur.Name = "MoreBlur"
    MoreBlur.Parent = Layers

    DropShadowHolder1.BackgroundTransparency = 1
    DropShadowHolder1.BorderSizePixel = 0
    DropShadowHolder1.Size = UDim2.new(1, 0, 1, 0)
    DropShadowHolder1.ZIndex = 0
    DropShadowHolder1.Name = "DropShadowHolder"
    DropShadowHolder1.Parent = MoreBlur

    DropShadow1.Image = "rbxassetid://6015897843"
    DropShadow1.ImageColor3 = Color3.fromRGB(0, 0, 0)
    DropShadow1.ImageTransparency = 1
    DropShadow1.ScaleType = Enum.ScaleType.Slice
    DropShadow1.SliceCenter = Rect.new(49, 49, 450, 450)
    DropShadow1.AnchorPoint = Vector2.new(0.5, 0.5)
    DropShadow1.BackgroundTransparency = 1
    DropShadow1.BorderSizePixel = 0
    DropShadow1.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropShadow1.Size = UDim2.new(1, 35, 1, 35)
    DropShadow1.ZIndex = 0
    DropShadow1.Name = "DropShadow"
    DropShadow1.Parent = DropShadowHolder1

    UICorner28.Parent = MoreBlur

    ConnectButton.Font = Enum.Font.SourceSans
    ConnectButton.Text = ""
    ConnectButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    ConnectButton.TextSize = 14
    ConnectButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ConnectButton.BackgroundTransparency = 0.999
    ConnectButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
    ConnectButton.BorderSizePixel = 0
    ConnectButton.Size = UDim2.new(1, 0, 1, 0)
    ConnectButton.Name = "ConnectButton"
    ConnectButton.Parent = MoreBlur

    local DropdownSelect = Instance.new("Frame")
    local UICorner36 = Instance.new("UICorner")
    local UIStroke14 = Instance.new("UIStroke")
    local DropdownSelectReal = Instance.new("Frame")
    local DropdownFolder = Instance.new("Folder")
    local DropPageLayout = Instance.new("UIPageLayout")

    DropdownSelect.AnchorPoint = Vector2.new(1, 0.5)
    DropdownSelect.BackgroundColor3 = Color3.fromRGB(30.00000011175871, 30.00000011175871, 30.00000011175871)
    DropdownSelect.BorderColor3 = Color3.fromRGB(0, 0, 0)
    DropdownSelect.BorderSizePixel = 0
    DropdownSelect.LayoutOrder = 1
    DropdownSelect.Position = UDim2.new(1, 172, 0.5, 0)
    DropdownSelect.Size = UDim2.new(0, 160, 1, -16)
    DropdownSelect.Name = "DropdownSelect"
    DropdownSelect.ClipsDescendants = true
    DropdownSelect.Parent = MoreBlur

    ConnectButton.Activated:Connect(
        function()
            if MoreBlur.Visible then
                TweenService:Create(MoreBlur, TweenInfo.new(0.3), {BackgroundTransparency = 0.999}):Play()
                TweenService:Create(DropdownSelect, TweenInfo.new(0.3), {Position = UDim2.new(1, 172, 0.5, 0)}):Play()
                task.wait(0.3)
                MoreBlur.Visible = false
            end
        end
    )
    UICorner36.CornerRadius = UDim.new(0, 3)
    UICorner36.Parent = DropdownSelect

    UIStroke14.Color = Color3.fromRGB(80, 80, 80)
    UIStroke14.Thickness = 2.5
    UIStroke14.Transparency = 0.8
    UIStroke14.Parent = DropdownSelect

    DropdownSelectReal.AnchorPoint = Vector2.new(0.5, 0.5)
    DropdownSelectReal.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    DropdownSelectReal.BackgroundTransparency = 0.5
    DropdownSelectReal.BorderColor3 = Color3.fromRGB(0, 0, 0)
    DropdownSelectReal.BorderSizePixel = 0
    DropdownSelectReal.LayoutOrder = 1
    DropdownSelectReal.Position = UDim2.new(0.5, 0, 0.5, 0)
    DropdownSelectReal.Size = UDim2.new(1, 1, 1, 1)
    DropdownSelectReal.Name = "DropdownSelectReal"
    DropdownSelectReal.Parent = DropdownSelect

    DropdownFolder.Name = "DropdownFolder"
    DropdownFolder.Parent = DropdownSelectReal

    DropPageLayout.EasingDirection = Enum.EasingDirection.InOut
    DropPageLayout.EasingStyle = Enum.EasingStyle.Quad
    DropPageLayout.TweenTime = 0.009999999776482582
    DropPageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    DropPageLayout.FillDirection = Enum.FillDirection.Vertical
    DropPageLayout.Archivable = false
    DropPageLayout.Name = "DropPageLayout"
    DropPageLayout.Parent = DropdownFolder

    local Tabs = {}
    local CountTab = 0
    local CountDropdown = 0
    function Tabs:AddTab(TabConfig)
        local TabConfig = TabConfig or {}
        TabConfig.Name = TabConfig.Name or "Tab"
        TabConfig.Icon = TabConfig.Icon or ""

        local ScrolLayers = Instance.new("ScrollingFrame")
        local UIListLayout1 = Instance.new("UIListLayout")

        ScrolLayers.ScrollBarImageColor3 = Color3.fromRGB(80.00000283122063, 80.00000283122063, 80.00000283122063)
        ScrolLayers.ScrollBarThickness = 0
        ScrolLayers.Active = true
        ScrolLayers.LayoutOrder = CountTab
        ScrolLayers.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ScrolLayers.BackgroundTransparency = 0.9990000128746033
        ScrolLayers.BorderColor3 = Color3.fromRGB(0, 0, 0)
        ScrolLayers.BorderSizePixel = 0
        ScrolLayers.Size = UDim2.new(1, 0, 1, 0)
        ScrolLayers.Name = "ScrolLayers"
        ScrolLayers.Parent = LayersFolder

        UIListLayout1.Padding = UDim.new(0, 3)
        UIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout1.Parent = ScrolLayers

        local Tab = Instance.new("Frame")
        local UICorner3 = Instance.new("UICorner")
        local TabButton = Instance.new("TextButton")
        local TabName = Instance.new("TextLabel")
        local FeatureImg = Instance.new("ImageLabel")
        local UIStroke2 = Instance.new("UIStroke")
        local UICorner4 = Instance.new("UICorner")

        Tab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        if CountTab == 0 then
            Tab.BackgroundTransparency = 0.9200000166893005
        else
            Tab.BackgroundTransparency = 0.9990000128746033
        end
        Tab.BorderColor3 = Color3.fromRGB(0, 0, 0)
        Tab.BorderSizePixel = 0
        Tab.LayoutOrder = CountTab
        Tab.Size = UDim2.new(1, 0, 0, 30)
        Tab.Name = "Tab"
        Tab.Parent = ScrollTab

        UICorner3.CornerRadius = UDim.new(0, 4)
        UICorner3.Parent = Tab

        TabButton.Font = Enum.Font.GothamBold
        TabButton.Text = ""
        TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabButton.TextSize = 13
        TabButton.TextXAlignment = Enum.TextXAlignment.Left
        TabButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TabButton.BackgroundTransparency = 0.9990000128746033
        TabButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TabButton.BorderSizePixel = 0
        TabButton.Size = UDim2.new(1, 0, 1, 0)
        TabButton.Name = "TabButton"
        TabButton.Parent = Tab

        TabName.Font = Enum.Font.GothamBold
        TabName.Text = "| " .. tostring(TabConfig.Name)
        TabName.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabName.TextSize = 13
        TabName.TextXAlignment = Enum.TextXAlignment.Left
        TabName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        TabName.BackgroundTransparency = 0.9990000128746033
        TabName.BorderColor3 = Color3.fromRGB(0, 0, 0)
        TabName.BorderSizePixel = 0
        TabName.Size = UDim2.new(1, 0, 1, 0)
        TabName.Position = UDim2.new(0, 30, 0, 0)
        TabName.Name = "TabName"
        TabName.Parent = Tab

        FeatureImg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        FeatureImg.BackgroundTransparency = 0.9990000128746033
        FeatureImg.BorderColor3 = Color3.fromRGB(0, 0, 0)
        FeatureImg.BorderSizePixel = 0
        FeatureImg.Position = UDim2.new(0, 9, 0, 7)
        FeatureImg.Size = UDim2.new(0, 16, 0, 16)
        FeatureImg.Name = "FeatureImg"
        FeatureImg.Parent = Tab
        if CountTab == 0 then
            LayersPageLayout:JumpToIndex(0)
            NameTab.Text = TabConfig.Name
            local ChooseFrame = Instance.new("Frame")
            ChooseFrame.BackgroundColor3 = GuiConfig.Color
            ChooseFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            ChooseFrame.BorderSizePixel = 0
            ChooseFrame.Position = UDim2.new(0, 2, 0, 9)
            ChooseFrame.Size = UDim2.new(0, 1, 0, 12)
            ChooseFrame.Name = "ChooseFrame"
            ChooseFrame.Parent = Tab

            UIStroke2.Color = GuiConfig.Color
            UIStroke2.Thickness = 1.600000023841858
            UIStroke2.Parent = ChooseFrame

            UICorner4.Parent = ChooseFrame
        end

        if TabConfig.Icon ~= "" then
            if Icons[TabConfig.Icon] then
                FeatureImg.Image = Icons[TabConfig.Icon]
            else
                FeatureImg.Image = TabConfig.Icon
            end
        end

        TabButton.Activated:Connect(
            function()
                CircleClick(TabButton, Mouse.X, Mouse.Y)
                local FrameChoose
                for a, s in ScrollTab:GetChildren() do
                    for i, v in s:GetChildren() do
                        if v.Name == "ChooseFrame" then
                            FrameChoose = v
                            break
                        end
                    end
                end
                if FrameChoose ~= nil and Tab.LayoutOrder ~= LayersPageLayout.CurrentPage.LayoutOrder then
                    for _, TabFrame in ScrollTab:GetChildren() do
                        if TabFrame.Name == "Tab" then
                            TweenService:Create(
                                TabFrame,
                                TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
                                {BackgroundTransparency = 0.9990000128746033}
                            ):Play()
                        end
                    end
                    TweenService:Create(
                        Tab,
                        TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.InOut),
                        {BackgroundTransparency = 0.9200000166893005}
                    ):Play()
                    TweenService:Create(
                        FrameChoose,
                        TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        {Position = UDim2.new(0, 2, 0, 9 + (33 * Tab.LayoutOrder))}
                    ):Play()
                    LayersPageLayout:JumpToIndex(Tab.LayoutOrder)
                    task.wait(0.05)
                    NameTab.Text = TabConfig.Name
                    TweenService:Create(
                        FrameChoose,
                        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        {Size = UDim2.new(0, 1, 0, 20)}
                    ):Play()
                    task.wait(0.2)
                    TweenService:Create(
                        FrameChoose,
                        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                        {Size = UDim2.new(0, 1, 0, 12)}
                    ):Play()
                end
            end
        )

        local Sections = {}
        local CountSection = 0
        function Sections:AddSection(Title, AlwaysOpen)
            local Title = Title or "Title"
            local Section = Instance.new("Frame")
            local SectionDecideFrame = Instance.new("Frame")
            local UICorner1 = Instance.new("UICorner")
            local UIGradient = Instance.new("UIGradient")

            Section.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Section.BackgroundTransparency = 0.9990000128746033
            Section.BorderColor3 = Color3.fromRGB(0, 0, 0)
            Section.BorderSizePixel = 0
            Section.LayoutOrder = CountSection
            Section.ClipsDescendants = true
            Section.LayoutOrder = 1
            Section.Size = UDim2.new(1, 0, 0, 30)
            Section.Name = "Section"
            Section.Parent = ScrolLayers

            local SectionReal = Instance.new("Frame")
            local UICorner = Instance.new("UICorner")
            local UIStroke = Instance.new("UIStroke")
            local SectionButton = Instance.new("TextButton")
            local FeatureFrame = Instance.new("Frame")
            local FeatureImg = Instance.new("ImageLabel")
            local SectionTitle = Instance.new("TextLabel")

            SectionReal.AnchorPoint = Vector2.new(0.5, 0)
            SectionReal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionReal.BackgroundTransparency = 0.9350000023841858
            SectionReal.BorderColor3 = Color3.fromRGB(0, 0, 0)
            SectionReal.BorderSizePixel = 0
            SectionReal.LayoutOrder = 1
            SectionReal.Position = UDim2.new(0.5, 0, 0, 0)
            SectionReal.Size = UDim2.new(1, 1, 0, 30)
            SectionReal.Name = "SectionReal"
            SectionReal.Parent = Section

            UICorner.CornerRadius = UDim.new(0, 4)
            UICorner.Parent = SectionReal

            SectionButton.Font = Enum.Font.SourceSans
            SectionButton.Text = ""
            SectionButton.TextColor3 = Color3.fromRGB(0, 0, 0)
            SectionButton.TextSize = 14
            SectionButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionButton.BackgroundTransparency = 0.9990000128746033
            SectionButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
            SectionButton.BorderSizePixel = 0
            SectionButton.Size = UDim2.new(1, 0, 1, 0)
            SectionButton.Name = "SectionButton"
            SectionButton.Parent = SectionReal

            FeatureFrame.AnchorPoint = Vector2.new(1, 0.5)
            FeatureFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            FeatureFrame.BackgroundTransparency = 0.9990000128746033
            FeatureFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            FeatureFrame.BorderSizePixel = 0
            FeatureFrame.Position = UDim2.new(1, -5, 0.5, 0)
            FeatureFrame.Size = UDim2.new(0, 20, 0, 20)
            FeatureFrame.Name = "FeatureFrame"
            FeatureFrame.Parent = SectionReal

            FeatureImg.Image = "rbxassetid://16851841101"
            FeatureImg.AnchorPoint = Vector2.new(0.5, 0.5)
            FeatureImg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            FeatureImg.BackgroundTransparency = 0.9990000128746033
            FeatureImg.BorderColor3 = Color3.fromRGB(0, 0, 0)
            FeatureImg.BorderSizePixel = 0
            FeatureImg.Position = UDim2.new(0.5, 0, 0.5, 0)
            FeatureImg.Rotation = -90
            FeatureImg.Size = UDim2.new(1, 6, 1, 6)
            FeatureImg.Name = "FeatureImg"
            FeatureImg.Parent = FeatureFrame

            SectionTitle.Font = Enum.Font.GothamBold
            SectionTitle.Text = Title
            SectionTitle.TextColor3 = Color3.fromRGB(230.77499270439148, 230.77499270439148, 230.77499270439148)
            SectionTitle.TextSize = 13
            SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
            SectionTitle.TextYAlignment = Enum.TextYAlignment.Top
            SectionTitle.AnchorPoint = Vector2.new(0, 0.5)
            SectionTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionTitle.BackgroundTransparency = 0.9990000128746033
            SectionTitle.BorderColor3 = Color3.fromRGB(0, 0, 0)
            SectionTitle.BorderSizePixel = 0
            SectionTitle.Position = UDim2.new(0, 10, 0.5, 0)
            SectionTitle.Size = UDim2.new(1, -50, 0, 13)
            SectionTitle.Name = "SectionTitle"
            SectionTitle.Parent = SectionReal

            SectionDecideFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionDecideFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
            SectionDecideFrame.AnchorPoint = Vector2.new(0.5, 0)
            SectionDecideFrame.BorderSizePixel = 0
            SectionDecideFrame.Position = UDim2.new(0.5, 0, 0, 33)
            SectionDecideFrame.Size = UDim2.new(0, 0, 0, 2)
            SectionDecideFrame.Name = "SectionDecideFrame"
            SectionDecideFrame.Parent = Section

            UICorner1.Parent = SectionDecideFrame

            UIGradient.Color =
                ColorSequence.new {
                ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 20)),
                ColorSequenceKeypoint.new(0.5, GuiConfig.Color),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20))
            }
            UIGradient.Parent = SectionDecideFrame

            local SectionAdd = Instance.new("Frame")
            local UICorner8 = Instance.new("UICorner")
            local UIListLayout2 = Instance.new("UIListLayout")

            SectionAdd.AnchorPoint = Vector2.new(0.5, 0)
            SectionAdd.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SectionAdd.BackgroundTransparency = 0.9990000128746033
            SectionAdd.BorderColor3 = Color3.fromRGB(0, 0, 0)
            SectionAdd.BorderSizePixel = 0
            SectionAdd.ClipsDescendants = true
            SectionAdd.LayoutOrder = 1
            SectionAdd.Position = UDim2.new(0.5, 0, 0, 38)
            SectionAdd.Size = UDim2.new(1, 0, 0, 100)
            SectionAdd.Name = "SectionAdd"
            SectionAdd.Parent = Section

            UICorner8.CornerRadius = UDim.new(0, 2)
            UICorner8.Parent = SectionAdd

            UIListLayout2.Padding = UDim.new(0, 3)
            UIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
            UIListLayout2.Parent = SectionAdd

            local OpenSection = false

            local function UpdateSizeScroll()
                local OffsetY = 0
                for _, child in ScrolLayers:GetChildren() do
                    if child.Name ~= "UIListLayout" then
                        OffsetY = OffsetY + 3 + child.Size.Y.Offset
                    end
                end
                ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, OffsetY)
            end

            local function UpdateSizeSection()
                if OpenSection then
                    local SectionSizeYWitdh = 38
                    for _, v in SectionAdd:GetChildren() do
                        if v.Name ~= "UIListLayout" and v.Name ~= "UICorner" then
                            SectionSizeYWitdh = SectionSizeYWitdh + v.Size.Y.Offset + 3
                        end
                    end
                    if AlwaysOpen ~= nil then
                        TweenService:Create(FeatureFrame, TweenInfo.new(0.5), {Rotation = 90}):Play()
                        TweenService:Create(Section, TweenInfo.new(0.5), {Size = UDim2.new(1, 1, 0, SectionSizeYWitdh)}):Play()
                        TweenService:Create(SectionAdd, TweenInfo.new(0.5), {Size = UDim2.new(1, 0, 0, SectionSizeYWitdh - 38)}):Play()
                        TweenService:Create(SectionDecideFrame, TweenInfo.new(0.5), {Size = UDim2.new(1, 0, 0, 2)}):Play()
                        task.wait(0.5)
                    else
                        FeatureFrame.Rotation = 90
                        Section.Size = UDim2.new(1, 1, 0, SectionSizeYWitdh)
                        SectionAdd.Size = UDim2.new(1, 0, 0, SectionSizeYWitdh - 38)
                        SectionDecideFrame.Size = UDim2.new(1, 0, 0, 2)
                    end
                    
                    UpdateSizeScroll()
                end
            end

            -- !! CONDITIONS NIL = OPEN WITHOUT ARROW, TRUE = OPEN WITH ARROW, FALSE = CLOSED WITH ARROW !!
            if AlwaysOpen == nil then
                OpenSection = true
                SectionButton:Destroy()
                FeatureFrame:Destroy()
                UpdateSizeSection()
            elseif AlwaysOpen == true then
                OpenSection = true
                FeatureFrame.Rotation = 90
                UpdateSizeSection()
                SectionButton.Activated:Connect(function()
                    CircleClick(SectionButton, Mouse.X, Mouse.Y)
                    if OpenSection then
                        TweenService:Create(FeatureFrame, TweenInfo.new(0.5), {Rotation = 0}):Play()
                        TweenService:Create(Section, TweenInfo.new(0.5), {Size = UDim2.new(1, 1, 0, 30)}):Play()
                        TweenService:Create(SectionDecideFrame, TweenInfo.new(0.5), {Size = UDim2.new(0, 0, 0, 2)}):Play()
                        OpenSection = false
                        task.wait(0.5)
                        UpdateSizeScroll()
                    else
                        OpenSection = true
                        UpdateSizeSection()
                    end
                end)
            elseif AlwaysOpen == false then
                OpenSection = false
                FeatureFrame.Rotation = 0
                SectionButton.Activated:Connect(function()
                    CircleClick(SectionButton, Mouse.X, Mouse.Y)
                    if OpenSection then
                        TweenService:Create(FeatureFrame, TweenInfo.new(0.5), {Rotation = 0}):Play()
                        TweenService:Create(Section, TweenInfo.new(0.5), {Size = UDim2.new(1, 1, 0, 30)}):Play()
                        TweenService:Create(SectionDecideFrame, TweenInfo.new(0.5), {Size = UDim2.new(0, 0, 0, 2)}):Play()
                        OpenSection = false
                        task.wait(0.5)
                        UpdateSizeScroll()
                    else
                        OpenSection = true
                        UpdateSizeSection()
                    end
                end)
            end

            SectionAdd.ChildAdded:Connect(UpdateSizeSection)
            SectionAdd.ChildRemoved:Connect(UpdateSizeSection)

            local layout = ScrolLayers:FindFirstChildOfClass("UIListLayout")
            if layout then
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    ScrolLayers.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
                end)
            end

            local Items = {}
            local CountItem = 0
            
            function Items:AddParagraph(ParagraphConfig)
                local ParagraphConfig = ParagraphConfig or {}
                ParagraphConfig.Title = ParagraphConfig.Title or "Title"
                ParagraphConfig.Content = ParagraphConfig.Content or "Content"
                local ParagraphFunc = {}

                local Paragraph = Instance.new("Frame")
                local UICorner14 = Instance.new("UICorner")
                local ParagraphTitle = Instance.new("TextLabel")
                local ParagraphContent = Instance.new("TextLabel")

                Paragraph.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Paragraph.BackgroundTransparency = 0.935
                Paragraph.BorderSizePixel = 0
                Paragraph.LayoutOrder = CountItem
                Paragraph.Size = UDim2.new(1, 0, 0, 46)
                Paragraph.Name = "Paragraph"
                Paragraph.Parent = SectionAdd

                UICorner14.CornerRadius = UDim.new(0, 4)
                UICorner14.Parent = Paragraph

                local iconOffset = 10
                local IconImg = nil

                if ParagraphConfig.Icon then
                    IconImg = Instance.new("ImageLabel")
                    IconImg.Size = UDim2.new(0, 20, 0, 20)
                    IconImg.Position = UDim2.new(0, 8, 0, 12)
                    IconImg.BackgroundTransparency = 1
                    IconImg.Name = "ParagraphIcon"
                    IconImg.Parent = Paragraph

                    if Icons and Icons[ParagraphConfig.Icon] then
                        IconImg.Image = Icons[ParagraphConfig.Icon]
                    else
                        IconImg.Image = ParagraphConfig.Icon
                    end

                    iconOffset = 30
                end

                ParagraphTitle.Font = Enum.Font.GothamBold
                ParagraphTitle.Text = ParagraphConfig.Title
                ParagraphTitle.TextColor3 = Color3.fromRGB(231, 231, 231)
                ParagraphTitle.TextSize = 13
                ParagraphTitle.TextXAlignment = Enum.TextXAlignment.Left
                ParagraphTitle.TextYAlignment = Enum.TextYAlignment.Top
                ParagraphTitle.BackgroundTransparency = 1
                ParagraphTitle.Position = UDim2.new(0, iconOffset, 0, 10)
                ParagraphTitle.Size = UDim2.new(1, -16, 0, 13)
                ParagraphTitle.Name = "ParagraphTitle"
                ParagraphTitle.Parent = Paragraph

                ParagraphContent.Font = Enum.Font.Gotham
                ParagraphContent.Text = ParagraphConfig.Content
                ParagraphContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                ParagraphContent.TextSize = 12
                ParagraphContent.TextXAlignment = Enum.TextXAlignment.Left
                ParagraphContent.TextYAlignment = Enum.TextYAlignment.Top
                ParagraphContent.BackgroundTransparency = 1
                ParagraphContent.Position = UDim2.new(0, iconOffset, 0, 25)
                ParagraphContent.Name = "ParagraphContent"
                ParagraphContent.TextWrapped = true
                ParagraphContent.RichText = true
                ParagraphContent.TextTruncate = Enum.TextTruncate.None
                ParagraphContent.Parent = Paragraph

                ParagraphContent.Size = UDim2.new(1, -16, 0, 0)
                ParagraphContent.AutomaticSize = Enum.AutomaticSize.Y

                local ParagraphButton = nil

                if ParagraphConfig.ButtonText then
                    ParagraphButton = Instance.new("TextButton")
                    ParagraphButton.Size = UDim2.new(1, -22, 0, 28)
                    ParagraphButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    ParagraphButton.BackgroundTransparency = 0.935
                    ParagraphButton.Font = Enum.Font.GothamBold
                    ParagraphButton.TextSize = 12
                    ParagraphButton.TextTransparency = 0.3
                    ParagraphButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                    ParagraphButton.Text = ParagraphConfig.ButtonText
                    ParagraphButton.Name = "ParagraphButton"
                    ParagraphButton.Parent = Paragraph

                    local btnCorner = Instance.new("UICorner")
                    btnCorner.CornerRadius = UDim.new(0, 6)
                    btnCorner.Parent = ParagraphButton

                    if ParagraphConfig.ButtonCallback then
                        ParagraphButton.MouseButton1Click:Connect(ParagraphConfig.ButtonCallback)
                    end
                end

                local function UpdateSize()
                    task.wait()
                    local contentWidth = math.max(Paragraph.AbsoluteSize.X - (iconOffset + 8), 50)
                    ParagraphContent.Size = UDim2.new(0, contentWidth, 0, 0)
                    ParagraphContent.AutomaticSize = Enum.AutomaticSize.Y
                    task.wait()
                    local contentHeight = ParagraphContent.AbsoluteSize.Y
                    if ParagraphButton then
                        ParagraphButton.Position = UDim2.new(0, 10, 0, ParagraphContent.Position.Y.Offset + contentHeight + 8)
                        ParagraphButton.Size = UDim2.new(1, -22, 0, 28)
                    end
                    local totalHeight = 10 + 13 + 12 + contentHeight + 8
                    if ParagraphButton then
                        totalHeight = totalHeight + ParagraphButton.Size.Y.Offset + 8
                    end

                    Paragraph.Size = UDim2.new(1, 0, 0, totalHeight)
                    UpdateSizeSection()
                end

                UpdateSize()

                ParagraphContent:GetPropertyChangedSignal("TextBounds"):Connect(UpdateSize)
                ParagraphContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateSize)

                if SectionAdd then
                    SectionAdd:GetPropertyChangedSignal("AbsoluteSize"):Connect(
                        function()
                            task.wait()
                            UpdateSize()
                        end
                    )
                end

                function ParagraphFunc:SetContent(content)
                    content = content or "Content"
                    ParagraphContent.Text = content
                    task.spawn(function()
                        task.wait()
                        UpdateSize()
                    end)
                end

                function ParagraphFunc:SetTitle(title)
                    title = title or "Title"
                    ParagraphTitle.Text = title
                    task.spawn(function()
                        task.wait()
                        UpdateSize()
                    end)
                end

                function ParagraphFunc:SetButtonText(text)
                    if ParagraphButton then
                        ParagraphButton.Text = text or ""
                    end
                end

                function ParagraphFunc:SetIcon(icon)
                    if icon and IconImg then
                        if Icons and Icons[icon] then
                            IconImg.Image = Icons[icon]
                        else
                            IconImg.Image = icon
                        end
                    elseif IconImg then
                        IconImg:Destroy()
                        IconImg = nil
                        ParagraphTitle.Position = UDim2.new(0, 10, 0, 10)
                        ParagraphContent.Position = UDim2.new(0, 10, 0, 25)
                        task.spawn(function()
                            task.wait()
                            UpdateSize()
                        end)
                    end
                end

                CountItem = CountItem + 1
                return ParagraphFunc
            end

            function Items:AddPanel(PanelConfig)
                PanelConfig = PanelConfig or {}
                PanelConfig.Title = PanelConfig.Title or "Title"
                PanelConfig.Content = PanelConfig.Content or ""
                PanelConfig.Placeholder = PanelConfig.Placeholder or nil
                PanelConfig.Default = PanelConfig.Default or ""
                PanelConfig.ButtonText = PanelConfig.Button or PanelConfig.ButtonText or "Confirm"
                PanelConfig.ButtonCallback = PanelConfig.Callback or PanelConfig.ButtonCallback or function()
                    end
                PanelConfig.SubButtonText = PanelConfig.SubButton or PanelConfig.SubButtonText or nil
                PanelConfig.SubButtonCallback = PanelConfig.SubCallback or PanelConfig.SubButtonCallback or function()
                    end

                local configKey = "Panel_" .. PanelConfig.Title
                if ConfigData[configKey] ~= nil then
                    PanelConfig.Default = ConfigData[configKey]
                end

                local PanelFunc = {Value = PanelConfig.Default}

                local baseHeight = 50

                if PanelConfig.Placeholder then
                    baseHeight = baseHeight + 40
                end

                if PanelConfig.SubButtonText then
                    baseHeight = baseHeight + 40
                else
                    baseHeight = baseHeight + 36
                end

                local Panel = Instance.new("Frame")
                Panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Panel.BackgroundTransparency = 0.935
                Panel.Size = UDim2.new(1, 0, 0, baseHeight)
                Panel.LayoutOrder = CountItem
                Panel.Parent = SectionAdd

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Panel

                local Title = Instance.new("TextLabel")
                Title.Font = Enum.Font.GothamBold
                Title.Text = PanelConfig.Title
                Title.TextSize = 13
                Title.TextColor3 = Color3.fromRGB(255, 255, 255)
                Title.TextXAlignment = Enum.TextXAlignment.Left
                Title.BackgroundTransparency = 1
                Title.Position = UDim2.new(0, 10, 0, 10)
                Title.Size = UDim2.new(1, -20, 0, 13)
                Title.Parent = Panel

                local Content = Instance.new("TextLabel")
                Content.Font = Enum.Font.Gotham
                Content.Text = PanelConfig.Content
                Content.TextSize = 12
                Content.TextColor3 = Color3.fromRGB(255, 255, 255)
                Content.TextTransparency = 0
                Content.TextXAlignment = Enum.TextXAlignment.Left
                Content.BackgroundTransparency = 1
                Content.RichText = true
                Content.Position = UDim2.new(0, 10, 0, 28)
                Content.Size = UDim2.new(1, -20, 0, 14)
                Content.Parent = Panel

                local InputBox
                if PanelConfig.Placeholder then
                    local InputFrame = Instance.new("Frame")
                    InputFrame.AnchorPoint = Vector2.new(0.5, 0)
                    InputFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    InputFrame.BackgroundTransparency = 0.95
                    InputFrame.Position = UDim2.new(0.5, 0, 0, 48)
                    InputFrame.Size = UDim2.new(1, -20, 0, 30)
                    InputFrame.Parent = Panel

                    local inputCorner = Instance.new("UICorner")
                    inputCorner.CornerRadius = UDim.new(0, 4)
                    inputCorner.Parent = InputFrame

                    InputBox = Instance.new("TextBox")
                    InputBox.Font = Enum.Font.GothamBold
                    InputBox.PlaceholderText = PanelConfig.Placeholder
                    InputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
                    InputBox.Text = PanelConfig.Default
                    InputBox.TextSize = 11
                    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                    InputBox.BackgroundTransparency = 1
                    InputBox.TextXAlignment = Enum.TextXAlignment.Left
                    InputBox.Size = UDim2.new(1, -10, 1, -6)
                    InputBox.Position = UDim2.new(0, 5, 0, 3)
                    InputBox.Parent = InputFrame
                end

                local yBtn = 0
                if PanelConfig.Placeholder then
                    yBtn = 88
                else
                    yBtn = 48
                end

                local function CreatePanelButton(text, callback, position, size)
                    local button = Instance.new("TextButton")
                    button.Font = Enum.Font.GothamBold
                    button.Text = text
                    button.TextColor3 = Color3.fromRGB(255, 255, 255)
                    button.TextSize = 12
                    button.TextTransparency = 0.3
                    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    button.BackgroundTransparency = 0.935
                    button.Size = size
                    button.Position = position
                    button.AutoButtonColor = false
                    button.Parent = Panel

                    local btnCorner = Instance.new("UICorner")
                    btnCorner.CornerRadius = UDim.new(0, 6)
                    btnCorner.Parent = button

                    local originalTransparency = 0.935
                    local isPressed = false
                    local hasTriggered = false

                    button.MouseButton1Down:Connect(
                        function()
                            isPressed = true
                            hasTriggered = false
                            button.BackgroundTransparency = 0.85
                        end
                    )

                    button.MouseLeave:Connect(
                        function()
                            if isPressed then
                                button.BackgroundTransparency = originalTransparency
                            end
                        end
                    )

                    button.MouseEnter:Connect(
                        function()
                            if isPressed then
                                button.BackgroundTransparency = 0.85
                            end
                        end
                    )

                    button.MouseButton1Up:Connect(
                        function()
                            if isPressed and not hasTriggered then
                                hasTriggered = true
                                button.BackgroundTransparency = originalTransparency
                                if callback then
                                    callback(InputBox and InputBox.Text or "")
                                end
                            end
                            isPressed = false
                        end
                    )

                    button.MouseButton1Click:Connect(
                        function()
                            if not hasTriggered then
                                hasTriggered = true
                                if callback then
                                    callback(InputBox and InputBox.Text or "")
                                end
                            end
                        end
                    )

                    return button
                end

                local mainButtonSize = PanelConfig.SubButtonText and UDim2.new(0.5, -12, 0, 30) or UDim2.new(1, -20, 0, 30)
                local mainButton =
                    CreatePanelButton(
                    PanelConfig.ButtonText,
                    PanelConfig.ButtonCallback,
                    UDim2.new(0, 10, 0, yBtn),
                    mainButtonSize
                )

                if PanelConfig.SubButtonText then
                    local subButton =
                        CreatePanelButton(
                        PanelConfig.SubButtonText,
                        PanelConfig.SubButtonCallback,
                        UDim2.new(0.5, 2, 0, yBtn),
                        UDim2.new(0.5, -12, 0, 30)
                    )
                end

                if InputBox then
                    InputBox.FocusLost:Connect(
                        function()
                            PanelFunc.Value = InputBox.Text
                            ConfigData[configKey] = InputBox.Text
                            if ConfigSystem.AutoSave then SaveConfig() end
                        end
                    )
                end

                function PanelFunc:GetInput()
                    return InputBox and InputBox.Text or ""
                end

                function PanelFunc:SetInput(text)
                    if InputBox then
                        InputBox.Text = text
                        PanelFunc.Value = text
                        ConfigData[configKey] = text
                        if ConfigSystem.AutoSave then SaveConfig() end
                    end
                end

                CountItem = CountItem + 1
                return PanelFunc
            end

            function Items:AddButton(ButtonConfig)
                ButtonConfig = ButtonConfig or {}
                ButtonConfig.Title = ButtonConfig.Title or "Confirm"
                ButtonConfig.Callback = ButtonConfig.Callback or function()
                    end
                ButtonConfig.SubTitle = ButtonConfig.SubTitle or nil
                ButtonConfig.SubCallback = ButtonConfig.SubCallback or function()
                    end

                local Button = Instance.new("Frame")
                Button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Button.BackgroundTransparency = 0.935
                Button.Size = UDim2.new(1, 0, 0, 40)
                Button.LayoutOrder = CountItem
                Button.Parent = SectionAdd

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 4)
                UICorner.Parent = Button

                local function CreateButton(text, callback, position, size)
                    local button = Instance.new("TextButton")
                    button.Font = Enum.Font.GothamBold
                    button.Text = text
                    button.TextSize = 12
                    button.TextColor3 = Color3.fromRGB(255, 255, 255)
                    button.TextTransparency = 0.3
                    button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    button.BackgroundTransparency = 0.935
                    button.Size = size
                    button.Position = position
                    button.AutoButtonColor = false
                    button.Parent = Button

                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, 4)
                    corner.Parent = button

                    local originalBackgroundTransparency = 0.935
                    local isPressed = false
                    local hasTriggered = false

                    button.MouseButton1Down:Connect(
                        function()
                            isPressed = true
                            hasTriggered = false
                            button.BackgroundTransparency = 0.85
                        end
                    )

                    button.MouseLeave:Connect(
                        function()
                            if isPressed then
                                button.BackgroundTransparency = originalBackgroundTransparency
                            end
                        end
                    )

                    button.MouseEnter:Connect(
                        function()
                            if isPressed then
                                button.BackgroundTransparency = 0.85
                            end
                        end
                    )

                    button.MouseButton1Up:Connect(
                        function()
                            if isPressed and not hasTriggered then
                                hasTriggered = true
                                button.BackgroundTransparency = originalBackgroundTransparency

                                if callback then
                                    callback()
                                end
                            end
                            isPressed = false
                        end
                    )

                    button.MouseButton1Click:Connect(
                        function()
                            if not hasTriggered then
                                hasTriggered = true
                                if callback then
                                    callback()
                                end
                            end
                        end
                    )

                    return button
                end

                local mainButtonSize = ButtonConfig.SubTitle and UDim2.new(0.5, -8, 1, -10) or UDim2.new(1, -12, 1, -10)
                local mainButton = CreateButton(ButtonConfig.Title, ButtonConfig.Callback, UDim2.new(0, 6, 0, 5), mainButtonSize)

                if ButtonConfig.SubTitle then
                    local subButton =
                        CreateButton(
                        ButtonConfig.SubTitle,
                        ButtonConfig.SubCallback,
                        UDim2.new(0.5, 2, 0, 5),
                        UDim2.new(0.5, -8, 1, -10)
                    )
                end

                CountItem = CountItem + 1
            end

            function Items:AddToggle(ToggleConfig)
                local ToggleConfig = ToggleConfig or {}
                ToggleConfig.Title = ToggleConfig.Title or "Title"
                ToggleConfig.Title2 = ToggleConfig.Title2 or ""
                ToggleConfig.Content = ToggleConfig.Content or ""
                ToggleConfig.Default = ToggleConfig.Default or false
                ToggleConfig.Callback = ToggleConfig.Callback or function() end

                local configKey = "Toggle_" .. ToggleConfig.Title
                if ConfigData[configKey] ~= nil then
                    ToggleConfig.Default = ConfigData[configKey]
                end

                local ToggleFunc = {Value = ToggleConfig.Default}
                local isAnimating = false
                local callbackDebounce = 0

                local Toggle = Instance.new("Frame")
                local UICorner20 = Instance.new("UICorner")
                local ToggleTitle = Instance.new("TextLabel")
                local ToggleContent = Instance.new("TextLabel")
                local ToggleButton = Instance.new("TextButton")
                local FeatureFrame2 = Instance.new("Frame")
                local UICorner22 = Instance.new("UICorner")
                local UIStroke8 = Instance.new("UIStroke")
                local ToggleCircle = Instance.new("Frame")
                local UICorner23 = Instance.new("UICorner")

                Toggle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Toggle.BackgroundTransparency = 0.935
                Toggle.BorderSizePixel = 0
                Toggle.LayoutOrder = CountItem
                Toggle.Name = "Toggle"
                Toggle.Parent = SectionAdd

                UICorner20.CornerRadius = UDim.new(0, 4)
                UICorner20.Parent = Toggle

                ToggleTitle.Font = Enum.Font.GothamBold
                ToggleTitle.Text = ToggleConfig.Title
                ToggleTitle.TextSize = 13
                ToggleTitle.TextColor3 = Color3.fromRGB(231, 231, 231)
                ToggleTitle.TextXAlignment = Enum.TextXAlignment.Left
                ToggleTitle.TextYAlignment = Enum.TextYAlignment.Top
                ToggleTitle.BackgroundTransparency = 1
                ToggleTitle.Position = UDim2.new(0, 10, 0, 10)
                ToggleTitle.Size = UDim2.new(1, -100, 0, 13)
                ToggleTitle.Name = "ToggleTitle"
                ToggleTitle.Parent = Toggle

                local ToggleTitle2 = Instance.new("TextLabel")
                ToggleTitle2.Font = Enum.Font.GothamBold
                ToggleTitle2.Text = ToggleConfig.Title2
                ToggleTitle2.TextSize = 12
                ToggleTitle2.TextColor3 = Color3.fromRGB(231, 231, 231)
                ToggleTitle2.TextXAlignment = Enum.TextXAlignment.Left
                ToggleTitle2.TextYAlignment = Enum.TextYAlignment.Top
                ToggleTitle2.BackgroundTransparency = 1
                ToggleTitle2.Position = UDim2.new(0, 10, 0, 23)
                ToggleTitle2.Size = UDim2.new(1, -100, 0, 12)
                ToggleTitle2.Name = "ToggleTitle2"
                ToggleTitle2.Parent = Toggle

                ToggleContent.Font = Enum.Font.GothamBold
                ToggleContent.Text = ToggleConfig.Content
                ToggleContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                ToggleContent.TextSize = 12
                ToggleContent.TextTransparency = 0.6
                ToggleContent.TextXAlignment = Enum.TextXAlignment.Left
                ToggleContent.TextYAlignment = Enum.TextYAlignment.Bottom
                ToggleContent.BackgroundTransparency = 1
                ToggleContent.Size = UDim2.new(1, -100, 0, 12)
                ToggleContent.Name = "ToggleContent"
                ToggleContent.Parent = Toggle

                if ToggleConfig.Title2 ~= "" then
                    Toggle.Size = UDim2.new(1, 0, 0, 57)
                    ToggleContent.Position = UDim2.new(0, 10, 0, 36)
                    ToggleTitle2.Visible = true
                else
                    Toggle.Size = UDim2.new(1, 0, 0, 46)
                    ToggleContent.Position = UDim2.new(0, 10, 0, 23)
                    ToggleTitle2.Visible = false
                end

                ToggleContent.Size = UDim2.new(1, -100, 0, 12 + (12 * (ToggleContent.TextBounds.X // ToggleContent.AbsoluteSize.X)))
                ToggleContent.TextWrapped = true
                if ToggleConfig.Title2 ~= "" then
                    Toggle.Size = UDim2.new(1, 0, 0, ToggleContent.AbsoluteSize.Y + 47)
                else
                    Toggle.Size = UDim2.new(1, 0, 0, ToggleContent.AbsoluteSize.Y + 33)
                end

                ToggleContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    ToggleContent.TextWrapped = false
                    ToggleContent.Size = UDim2.new(1, -100, 0, 12 + (12 * (ToggleContent.TextBounds.X // ToggleContent.AbsoluteSize.X)))
                    if ToggleConfig.Title2 ~= "" then
                        Toggle.Size = UDim2.new(1, 0, 0, ToggleContent.AbsoluteSize.Y + 47)
                    else
                        Toggle.Size = UDim2.new(1, 0, 0, ToggleContent.AbsoluteSize.Y + 33)
                    end
                    ToggleContent.TextWrapped = true
                    UpdateSizeSection()
                end)

                ToggleButton.Font = Enum.Font.SourceSans
                ToggleButton.Text = ""
                ToggleButton.BackgroundTransparency = 1
                ToggleButton.Size = UDim2.new(1, 0, 1, 0)
                ToggleButton.Name = "ToggleButton"
                ToggleButton.Parent = Toggle

                FeatureFrame2.AnchorPoint = Vector2.new(1, 0.5)
                FeatureFrame2.BackgroundTransparency = 0.92
                FeatureFrame2.BorderSizePixel = 0
                FeatureFrame2.Position = UDim2.new(1, -15, 0.5, 0)
                FeatureFrame2.Size = UDim2.new(0, 30, 0, 15)
                FeatureFrame2.Name = "FeatureFrame"
                FeatureFrame2.Parent = Toggle

                UICorner22.Parent = FeatureFrame2

                UIStroke8.Color = Color3.fromRGB(255, 255, 255)
                UIStroke8.Thickness = 2
                UIStroke8.Transparency = 0.9
                UIStroke8.Parent = FeatureFrame2

                ToggleCircle.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
                ToggleCircle.BorderSizePixel = 0
                ToggleCircle.Size = UDim2.new(0, 14, 0, 14)
                ToggleCircle.Name = "ToggleCircle"
                ToggleCircle.Parent = FeatureFrame2

                UICorner23.CornerRadius = UDim.new(0, 15)
                UICorner23.Parent = ToggleCircle

                local activeTweens = {}
                
                local function cancelActiveTweens()
                    for _, tween in ipairs(activeTweens) do
                        if tween then
                            pcall(function() tween:Cancel() end)
                        end
                    end
                    activeTweens = {}
                end

                ToggleButton.Activated:Connect(function()
                    if isAnimating then return end
                    
                    ToggleFunc.Value = not ToggleFunc.Value
                    ToggleFunc:Set(ToggleFunc.Value)
                end)

                function ToggleFunc:Set(Value)
                    if isAnimating then return end
                    isAnimating = true
                    
                    if typeof(ToggleConfig.Callback) == "function" then
                        task.spawn(function()
                            local ok, err = pcall(function()
                                ToggleConfig.Callback(Value)
                            end)
                            if not ok then
                                warn("Toggle Callback error:", err)
                            end
                        end)
                    end
                    
                    ConfigData[configKey] = Value
                    if ConfigSystem.AutoSave then task.spawn(SaveConfig) end
                    
                    cancelActiveTweens()
                    
                    if Value then
                        local t1 = TweenService:Create(ToggleTitle, TweenInfo.new(0.2), {TextColor3 = GuiConfig.Color})
                        local t2 = TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 15, 0, 0)})
                        local t3 = TweenService:Create(UIStroke8, TweenInfo.new(0.2), {Color = GuiConfig.Color, Transparency = 0})
                        local t4 = TweenService:Create(FeatureFrame2, TweenInfo.new(0.2), {BackgroundColor3 = GuiConfig.Color, BackgroundTransparency = 0})
                        
                        table.insert(activeTweens, t1)
                        table.insert(activeTweens, t2)
                        table.insert(activeTweens, t3)
                        table.insert(activeTweens, t4)
                        
                        t1:Play()
                        t2:Play()
                        t3:Play()
                        t4:Play()
                    else
                        local t1 = TweenService:Create(ToggleTitle, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(230, 230, 230)})
                        local t2 = TweenService:Create(ToggleCircle, TweenInfo.new(0.2), {Position = UDim2.new(0, 0, 0, 0)})
                        local t3 = TweenService:Create(UIStroke8, TweenInfo.new(0.2), {Color = Color3.fromRGB(255, 255, 255), Transparency = 0.9})
                        local t4 = TweenService:Create(FeatureFrame2, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.92})
                        
                        table.insert(activeTweens, t1)
                        table.insert(activeTweens, t2)
                        table.insert(activeTweens, t3)
                        table.insert(activeTweens, t4)
                        
                        t1:Play()
                        t2:Play()
                        t3:Play()
                        t4:Play()
                    end
                
                    task.delay(0.2, function()
                        isAnimating = false
                    end)
                end

                ToggleFunc:Set(ToggleFunc.Value)
                CountItem = CountItem + 1
                Elements[configKey] = ToggleFunc
                return ToggleFunc
            end

            function Items:AddSlider(SliderConfig)
                local SliderConfig = SliderConfig or {}
                SliderConfig.Title = SliderConfig.Title or "Slider"
                SliderConfig.Content = SliderConfig.Content or ""
                SliderConfig.Increment = SliderConfig.Increment or 1
                SliderConfig.Min = SliderConfig.Min or 0
                SliderConfig.Max = SliderConfig.Max or 100
                SliderConfig.Default = SliderConfig.Default or 50
                SliderConfig.Callback = SliderConfig.Callback or function()
                    end

                local configKey = "Slider_" .. SliderConfig.Title
                if ConfigData[configKey] ~= nil then
                    SliderConfig.Default = ConfigData[configKey]
                end

                local SliderFunc = {Value = SliderConfig.Default}
                local IsFloat = SliderConfig.Increment % 1 ~= 0

                local function GetDecimalPlaces(num)
                    local str = tostring(num)
                    local decimalIndex = string.find(str, "%.")
                    if decimalIndex then
                        return #str - decimalIndex
                    end
                    return 0
                end

                local function RoundToNearest(value, increment)
                    if increment == 0 then
                        return value
                    end
                    return math.floor(value / increment + 0.5) * increment
                end

                local function CleanDecimal(value, decimalPlaces)
                    local rounded = RoundToNearest(value, 10 ^ (-decimalPlaces))
                    return string.format("%." .. decimalPlaces .. "f", rounded)
                end

                local function FormatValue(val)
                    if IsFloat then
                        local decimalPlaces = GetDecimalPlaces(SliderConfig.Increment)
                        local cleaned = CleanDecimal(val, decimalPlaces)
                        local num = tonumber(cleaned)
                        return tostring(num)
                    else
                        return tostring(math.floor(val + 0.5))
                    end
                end

                local function CalculateValue(rawValue)
                    if IsFloat then
                        local stepped = RoundToNearest(rawValue, SliderConfig.Increment)
                        local decimalPlaces = GetDecimalPlaces(SliderConfig.Increment)
                        local cleaned = CleanDecimal(stepped, decimalPlaces)
                        return tonumber(cleaned)
                    else
                        return math.floor(RoundToNearest(rawValue, SliderConfig.Increment) + 0.5)
                    end
                end

                local Slider = Instance.new("Frame")
                local UICorner15 = Instance.new("UICorner")
                local SliderTitle = Instance.new("TextLabel")
                local SliderContent = Instance.new("TextLabel")
                local SliderInput = Instance.new("Frame")
                local UICorner16 = Instance.new("UICorner")
                local TextBox = Instance.new("TextBox")
                local SliderFrame = Instance.new("Frame")
                local UICorner17 = Instance.new("UICorner")
                local SliderDraggable = Instance.new("Frame")
                local UICorner18 = Instance.new("UICorner")
                local SliderCircle = Instance.new("Frame")
                local UICorner19 = Instance.new("UICorner")

                local ThumbSize = 13
                local TextBoxWidth = 30
                local SliderWidth = 100

                Slider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Slider.BackgroundTransparency = 0.935
                Slider.BorderSizePixel = 0
                Slider.LayoutOrder = CountItem
                Slider.Size = UDim2.new(1, 0, 0, 46)
                Slider.Name = "Slider"
                Slider.Parent = SectionAdd

                UICorner15.CornerRadius = UDim.new(0, 4)
                UICorner15.Parent = Slider

                SliderTitle.Font = Enum.Font.GothamBold
                SliderTitle.Text = SliderConfig.Title
                SliderTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
                SliderTitle.TextSize = 13
                SliderTitle.TextXAlignment = Enum.TextXAlignment.Left
                SliderTitle.TextYAlignment = Enum.TextYAlignment.Top
                SliderTitle.BackgroundTransparency = 1
                SliderTitle.Position = UDim2.new(0, 10, 0, 10)
                SliderTitle.Size = UDim2.new(1, -180, 0, 13)
                SliderTitle.Parent = Slider

                SliderContent.Font = Enum.Font.GothamBold
                SliderContent.Text = SliderConfig.Content
                SliderContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                SliderContent.TextSize = 12
                SliderContent.TextTransparency = 0.6
                SliderContent.TextXAlignment = Enum.TextXAlignment.Left
                SliderContent.TextYAlignment = Enum.TextYAlignment.Bottom
                SliderContent.BackgroundTransparency = 1
                SliderContent.Position = UDim2.new(0, 10, 0, 25)
                SliderContent.Size = UDim2.new(1, -180, 0, 12)
                SliderContent.TextWrapped = true
                SliderContent.Parent = Slider

                local function UpdateSliderSize()
                    local textSize = SliderContent.TextBounds
                    local containerWidth = SliderContent.AbsoluteSize.X
                    local lineCount = math.ceil(textSize.X / containerWidth)
                    SliderContent.Size = UDim2.new(1, -180, 0, 12 + (12 * (lineCount - 1)))
                    Slider.Size = UDim2.new(1, 0, 0, SliderContent.AbsoluteSize.Y + 33)
                    UpdateSizeSection()
                end

                SliderContent:GetPropertyChangedSignal("TextBounds"):Connect(UpdateSliderSize)
                UpdateSliderSize()

                SliderInput.AnchorPoint = Vector2.new(0, 0.5)
                SliderInput.BackgroundColor3 = GuiConfig.Color
                SliderInput.BackgroundTransparency = 1
                SliderInput.Position = UDim2.new(1, -155, 0.5, 0)
                SliderInput.Size = UDim2.new(0, TextBoxWidth, 0, 20)
                SliderInput.Parent = Slider

                UICorner16.CornerRadius = UDim.new(0, 2)
                UICorner16.Parent = SliderInput

                TextBox.Font = Enum.Font.GothamBold
                TextBox.Text = FormatValue(SliderConfig.Default)
                TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                TextBox.TextSize = 13
                TextBox.TextWrapped = true
                TextBox.BackgroundTransparency = 1
                TextBox.ClearTextOnFocus = false
                TextBox.Size = UDim2.new(1, 0, 1, 0)
                TextBox.Parent = SliderInput

                SliderFrame.AnchorPoint = Vector2.new(1, 0.5)
                SliderFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                SliderFrame.BackgroundTransparency = 0.8
                SliderFrame.Position = UDim2.new(1, -20, 0.5, 0)
                SliderFrame.Size = UDim2.new(0, SliderWidth, 0, 3)
                SliderFrame.Parent = Slider

                UICorner17.Parent = SliderFrame

                SliderDraggable.AnchorPoint = Vector2.new(0, 0.5)
                SliderDraggable.BackgroundColor3 = GuiConfig.Color
                SliderDraggable.Position = UDim2.new(0, 0, 0.5, 0)
                SliderDraggable.Size = UDim2.new(0, 0, 1, 0)
                SliderDraggable.Parent = SliderFrame

                UICorner18.Parent = SliderDraggable

                SliderCircle.AnchorPoint = Vector2.new(0.5, 0.5)
                SliderCircle.BackgroundColor3 = GuiConfig.Color
                SliderCircle.Size = UDim2.new(0, ThumbSize, 0, ThumbSize)
                SliderCircle.Position = UDim2.new(0, 0, 0.5, 0)
                SliderCircle.Parent = SliderFrame

                UICorner19.CornerRadius = UDim.new(1, 0)
                UICorner19.Parent = SliderCircle

                local function AnimateThumb(expanding)
                    local targetSize =
                        expanding and UDim2.new(0, ThumbSize + 6, 0, ThumbSize + 6) or
                        UDim2.new(0, ThumbSize, 0, ThumbSize)
                    TweenService:Create(
                        SliderCircle,
                        TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {Size = targetSize}
                    ):Play()
                end

                local LastValue = SliderConfig.Default
                local CanCallback = true

                function SliderFunc:Set(Value, input)
                    if not CanCallback then
                        return
                    end

                    local calculatedValue = CalculateValue(Value)
                    local clampedValue = math.clamp(calculatedValue, SliderConfig.Min, SliderConfig.Max)

                    local formattedClamped = FormatValue(clampedValue)
                    local formattedLast = FormatValue(LastValue)

                    if formattedClamped ~= formattedLast then
                        local delta = (clampedValue - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min)
                        delta = math.clamp(delta, 0, 1)

                        local fillWidth = SliderWidth * delta
                        local thumbPosition = fillWidth

                        TweenService:Create(
                            SliderDraggable,
                            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            {Size = UDim2.new(0, fillWidth, 1, 0)}
                        ):Play()

                        TweenService:Create(
                            SliderCircle,
                            TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            {Position = UDim2.new(0, thumbPosition, 0.5, 0)}
                        ):Play()

                        local displayValue = FormatValue(clampedValue)
                        TextBox.Text = displayValue
                        SliderFunc.Value = clampedValue
                        LastValue = clampedValue

                        SliderConfig.Callback(clampedValue)
                        ConfigData[configKey] = clampedValue
                        if ConfigSystem.AutoSave then SaveConfig() end
                    end

                    if
                        input and
                            (input.UserInputType == Enum.UserInputType.MouseButton1 or
                                input.UserInputType == Enum.UserInputType.Touch)
                     then
                        AnimateThumb(true)

                        local isTouch = input.UserInputType == Enum.UserInputType.Touch
                        local connection
                        local frameAbsoluteX = SliderFrame.AbsolutePosition.X
                        local frameWidth = SliderFrame.AbsoluteSize.X

                        connection =
                            game:GetService("RunService").RenderStepped:Connect(
                            function()
                                if not SliderFrame:IsDescendantOf(game) then
                                    if connection then
                                        connection:Disconnect()
                                    end
                                    return
                                end

                                local mouseX =
                                    isTouch and input.Position.X or
                                    game:GetService("UserInputService"):GetMouseLocation().X

                                local relativeX = math.clamp((mouseX - frameAbsoluteX) / frameWidth, 0, 1)

                                local rawValue = SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * relativeX)
                                local newValue = CalculateValue(rawValue)
                                SliderFunc:Set(newValue)
                            end
                        )

                        local releaseConnection
                        releaseConnection =
                            game:GetService("UserInputService").InputEnded:Connect(
                            function(endInput)
                                if
                                    (endInput.UserInputType == Enum.UserInputType.MouseButton1 or
                                        endInput.UserInputType == Enum.UserInputType.Touch)
                                 then
                                    if connection then
                                        connection:Disconnect()
                                    end
                                    if releaseConnection then
                                        releaseConnection:Disconnect()
                                    end
                                    AnimateThumb(false)
                                end
                            end
                        )
                    end
                end

                local function InitializeSlider()
                    local delta = (SliderConfig.Default - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min)
                    delta = math.clamp(delta, 0, 1)
                    local fillWidth = SliderWidth * delta

                    SliderDraggable.Size = UDim2.new(0, fillWidth, 1, 0)
                    SliderCircle.Position = UDim2.new(0, fillWidth, 0.5, 0)
                end

                TextBox.FocusLost:Connect(
                    function(enterPressed)
                        if enterPressed then
                            local text = TextBox.Text
                            text = text:gsub(",", ".")
                            local cleanText = text:gsub("[^%d%.%-]", "")
                            local num = tonumber(cleanText)

                            if num then
                                SliderFunc:Set(num)
                            else
                                TextBox.Text = FormatValue(SliderFunc.Value)
                            end
                        end
                    end
                )

                TextBox:GetPropertyChangedSignal("Text"):Connect(
                    function()
                        if TextBox:IsFocused() then
                            local text = TextBox.Text
                            text = text:gsub(",", ".")
                            local cleanText = text:gsub("[^%d%.%-]", "")

                            local dotCount = 0
                            for i = 1, #cleanText do
                                if cleanText:sub(i, i) == "." then
                                    dotCount = dotCount + 1
                                    if dotCount > 1 then
                                        cleanText = cleanText:sub(1, i - 1) .. cleanText:sub(i + 1)
                                        break
                                    end
                                end
                            end

                            if text ~= cleanText then
                                TextBox.Text = cleanText
                                TextBox.CursorPosition = #cleanText + 1
                            end
                        end
                    end
                )

                SliderFrame.InputBegan:Connect(
                    function(input)
                        if
                            input.UserInputType == Enum.UserInputType.MouseButton1 or
                                input.UserInputType == Enum.UserInputType.Touch
                         then
                            SliderFunc:Set(SliderFunc.Value, input)
                        end
                    end
                )

                function SliderFunc:Lock()
                    CanCallback = false
                    Slider.BackgroundTransparency = 0.95
                    SliderTitle.TextTransparency = 0.5
                    SliderContent.TextTransparency = 0.8
                    TextBox.TextTransparency = 0.5
                    TextBox.TextEditable = false
                    SliderFrame.BackgroundTransparency = 0.9
                    SliderDraggable.BackgroundTransparency = 0.5
                    SliderCircle.BackgroundTransparency = 0.5
                end

                function SliderFunc:Unlock()
                    CanCallback = true
                    Slider.BackgroundTransparency = 0.935
                    SliderTitle.TextTransparency = 0
                    SliderContent.TextTransparency = 0.6
                    TextBox.TextTransparency = 0
                    TextBox.TextEditable = true
                    SliderFrame.BackgroundTransparency = 0.8
                    SliderDraggable.BackgroundTransparency = 0
                    SliderCircle.BackgroundTransparency = 0
                end

                function SliderFunc:SetMax(newMax)
                    SliderConfig.Max = newMax
                    if SliderFunc.Value > newMax then
                        SliderFunc:Set(newMax)
                    end
                end

                function SliderFunc:SetMin(newMin)
                    SliderConfig.Min = newMin
                    if SliderFunc.Value < newMin then
                        SliderFunc:Set(newMin)
                    end
                end

                function SliderFunc:GetValue()
                    return SliderFunc.Value
                end

                InitializeSlider()
                CountItem = CountItem + 1
                Elements[configKey] = SliderFunc

                return SliderFunc
            end

            function Items:AddInput(InputConfig)
                local InputConfig = InputConfig or {}
                InputConfig.Title = InputConfig.Title or "Title"
                InputConfig.Content = InputConfig.Content or ""
                InputConfig.Callback = InputConfig.Callback or function()
                    end
                InputConfig.Default = InputConfig.Default or ""

                local configKey = "Input_" .. InputConfig.Title
                if ConfigData[configKey] ~= nil then
                    InputConfig.Default = ConfigData[configKey]
                end

                local InputFunc = {Value = InputConfig.Default}

                local Input = Instance.new("Frame")
                local UICorner12 = Instance.new("UICorner")
                local InputTitle = Instance.new("TextLabel")
                local InputContent = Instance.new("TextLabel")
                local InputFrame = Instance.new("Frame")
                local UICorner13 = Instance.new("UICorner")
                local InputTextBox = Instance.new("TextBox")

                Input.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Input.BackgroundTransparency = 0.9350000023841858
                Input.BorderColor3 = Color3.fromRGB(0, 0, 0)
                Input.BorderSizePixel = 0
                Input.LayoutOrder = CountItem
                Input.Size = UDim2.new(1, 0, 0, 46)
                Input.Name = "Input"
                Input.Parent = SectionAdd

                UICorner12.CornerRadius = UDim.new(0, 4)
                UICorner12.Parent = Input

                InputTitle.Font = Enum.Font.GothamBold
                InputTitle.Text = InputConfig.Title or "TextBox"
                InputTitle.TextColor3 = Color3.fromRGB(230.77499270439148, 230.77499270439148, 230.77499270439148)
                InputTitle.TextSize = 13
                InputTitle.TextXAlignment = Enum.TextXAlignment.Left
                InputTitle.TextYAlignment = Enum.TextYAlignment.Top
                InputTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputTitle.BackgroundTransparency = 0.9990000128746033
                InputTitle.BorderColor3 = Color3.fromRGB(0, 0, 0)
                InputTitle.BorderSizePixel = 0
                InputTitle.Position = UDim2.new(0, 10, 0, 10)
                InputTitle.Size = UDim2.new(1, -180, 0, 13)
                InputTitle.Name = "InputTitle"
                InputTitle.Parent = Input

                InputContent.Font = Enum.Font.GothamBold
                InputContent.Text = InputConfig.Content or "This is a TextBox"
                InputContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                InputContent.TextSize = 12
                InputContent.TextTransparency = 0.6000000238418579
                InputContent.TextWrapped = true
                InputContent.TextXAlignment = Enum.TextXAlignment.Left
                InputContent.TextYAlignment = Enum.TextYAlignment.Bottom
                InputContent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputContent.BackgroundTransparency = 0.9990000128746033
                InputContent.BorderColor3 = Color3.fromRGB(0, 0, 0)
                InputContent.BorderSizePixel = 0
                InputContent.Position = UDim2.new(0, 10, 0, 25)
                InputContent.Size = UDim2.new(1, -180, 0, 12)
                InputContent.Name = "InputContent"
                InputContent.Parent = Input

                InputContent.Size =
                    UDim2.new(1, -180, 0, 12 + (12 * (InputContent.TextBounds.X // InputContent.AbsoluteSize.X)))
                InputContent.TextWrapped = true
                Input.Size = UDim2.new(1, 0, 0, InputContent.AbsoluteSize.Y + 33)

                InputContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(
                    function()
                        InputContent.TextWrapped = false
                        InputContent.Size =
                            UDim2.new(
                            1,
                            -180,
                            0,
                            12 + (12 * (InputContent.TextBounds.X // InputContent.AbsoluteSize.X))
                        )
                        Input.Size = UDim2.new(1, 0, 0, InputContent.AbsoluteSize.Y + 33)
                        InputContent.TextWrapped = true
                        UpdateSizeSection()
                    end
                )

                InputFrame.AnchorPoint = Vector2.new(1, 0.5)
                InputFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputFrame.BackgroundTransparency = 0.949999988079071
                InputFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
                InputFrame.BorderSizePixel = 0
                InputFrame.ClipsDescendants = true
                InputFrame.Position = UDim2.new(1, -7, 0.5, 0)
                InputFrame.Size = UDim2.new(0, 148, 0, 30)
                InputFrame.Name = "InputFrame"
                InputFrame.Parent = Input

                UICorner13.CornerRadius = UDim.new(0, 4)
                UICorner13.Parent = InputFrame

                InputTextBox.CursorPosition = -1
                InputTextBox.Font = Enum.Font.GothamBold
                InputTextBox.PlaceholderColor3 =
                    Color3.fromRGB(120.00000044703484, 120.00000044703484, 120.00000044703484)
                InputTextBox.PlaceholderText = "Input Here"
                InputTextBox.Text = InputConfig.Default
                InputTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                InputTextBox.TextSize = 12
                InputTextBox.TextXAlignment = Enum.TextXAlignment.Left
                InputTextBox.AnchorPoint = Vector2.new(0, 0.5)
                InputTextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                InputTextBox.BackgroundTransparency = 0.9990000128746033
                InputTextBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
                InputTextBox.BorderSizePixel = 0
                InputTextBox.Position = UDim2.new(0, 5, 0.5, 0)
                InputTextBox.Size = UDim2.new(1, -10, 1, -8)
                InputTextBox.Name = "InputTextBox"
                InputTextBox.Parent = InputFrame
                function InputFunc:Set(Value)
                    InputTextBox.Text = Value
                    InputFunc.Value = Value
                    InputConfig.Callback(Value)
                    ConfigData[configKey] = Value
                    if ConfigSystem.AutoSave then SaveConfig() end
                end

                InputFunc:Set(InputFunc.Value)

                InputTextBox.FocusLost:Connect(
                    function()
                        InputFunc:Set(InputTextBox.Text)
                    end
                )
                CountItem = CountItem + 1
                Elements[configKey] = InputFunc
                return InputFunc
            end

            function Items:AddDropdown(DropdownConfig)
                local DropdownConfig = DropdownConfig or {}
                DropdownConfig.Title = DropdownConfig.Title or "Title"
                DropdownConfig.Content = DropdownConfig.Content or ""
                DropdownConfig.Multi = DropdownConfig.Multi or false
                DropdownConfig.Options = DropdownConfig.Options or {}
                DropdownConfig.Default = DropdownConfig.Default or (DropdownConfig.Multi and {} or nil)
                DropdownConfig.Callback = DropdownConfig.Callback or function()
                    end
                DropdownConfig.ButtonText = DropdownConfig.ButtonText or nil
                DropdownConfig.ButtonCallback = DropdownConfig.ButtonCallback or function()
                    end

                local configKey = "Dropdown_" .. DropdownConfig.Title
                if ConfigData[configKey] ~= nil then
                    DropdownConfig.Default = ConfigData[configKey]
                end

                if not DropdownConfig.Multi and type(DropdownConfig.Default) == "table" and #DropdownConfig.Default == 0 then
                    DropdownConfig.Default = nil
                end

                if DropdownConfig.Multi and DropdownConfig.Default == nil then
                    DropdownConfig.Default = {}
                end

                local DropdownFunc = {
                    Value = DropdownConfig.Default,
                    Options = DropdownConfig.Options
                }

                local baseHeight = 46
                if DropdownConfig.Content ~= "" then
                    baseHeight = baseHeight + 12
                end

                if DropdownConfig.ButtonText then
                    baseHeight = baseHeight + 40
                end

                local Dropdown = Instance.new("Frame")
                local DropdownButton = Instance.new("TextButton")
                local UICorner10 = Instance.new("UICorner")
                local DropdownTitle = Instance.new("TextLabel")
                local DropdownContent = Instance.new("TextLabel")
                local SelectOptionsFrame = Instance.new("Frame")
                local UICorner11 = Instance.new("UICorner")
                local OptionSelecting = Instance.new("TextLabel")
                local OptionImg = Instance.new("ImageLabel")

                Dropdown.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Dropdown.BackgroundTransparency = 0.935
                Dropdown.BorderSizePixel = 0
                Dropdown.LayoutOrder = CountItem
                Dropdown.Size = UDim2.new(1, 0, 0, baseHeight)
                Dropdown.Name = "Dropdown"
                Dropdown.Parent = SectionAdd

                UICorner10.CornerRadius = UDim.new(0, 4)
                UICorner10.Parent = Dropdown

                DropdownTitle.Font = Enum.Font.GothamBold
                DropdownTitle.Text = DropdownConfig.Title
                DropdownTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
                DropdownTitle.TextSize = 13
                DropdownTitle.TextXAlignment = Enum.TextXAlignment.Left
                DropdownTitle.BackgroundTransparency = 1
                DropdownTitle.Position = UDim2.new(0, 10, 0, 10)
                DropdownTitle.Size = UDim2.new(1, -180, 0, 13)
                DropdownTitle.Name = "DropdownTitle"
                DropdownTitle.Parent = Dropdown

                DropdownContent.Font = Enum.Font.GothamBold
                DropdownContent.Text = DropdownConfig.Content
                DropdownContent.TextColor3 = Color3.fromRGB(255, 255, 255)
                DropdownContent.TextSize = 12
                DropdownContent.TextTransparency = 0.6
                DropdownContent.TextWrapped = true
                DropdownContent.TextXAlignment = Enum.TextXAlignment.Left
                DropdownContent.BackgroundTransparency = 1
                DropdownContent.Position = UDim2.new(0, 10, 0, 25)
                DropdownContent.Size = UDim2.new(1, -180, 0, 12)
                DropdownContent.Name = "DropdownContent"
                DropdownContent.Parent = Dropdown

                DropdownContent:GetPropertyChangedSignal("TextBounds"):Connect(
                    function()
                        local textSize = DropdownContent.TextBounds
                        local containerWidth = DropdownContent.AbsoluteSize.X
                        local lineCount = math.ceil(textSize.X / containerWidth)

                        local contentHeight = 12 + (12 * (lineCount - 1))
                        DropdownContent.Size = UDim2.new(1, -180, 0, contentHeight)

                        local totalHeight = 46 + contentHeight - 12
                        if DropdownConfig.ButtonText then
                            totalHeight = totalHeight + 40
                        end

                        Dropdown.Size = UDim2.new(1, 0, 0, totalHeight)
                        UpdateSizeSection()
                    end
                )

                DropdownButton.Text = ""
                DropdownButton.BackgroundTransparency = 1
                DropdownButton.Size = UDim2.new(1, 0, 1, DropdownConfig.ButtonText and -40 or 0)
                DropdownButton.Name = "ToggleButton"
                DropdownButton.Parent = Dropdown

                SelectOptionsFrame.AnchorPoint = Vector2.new(1, 0.5)
                SelectOptionsFrame.BackgroundTransparency = 0.95
                SelectOptionsFrame.Position = UDim2.new(1, -7, 0.5, DropdownConfig.ButtonText and -20 or 0)
                SelectOptionsFrame.Size = UDim2.new(0, 148, 0, 30)
                SelectOptionsFrame.Name = "SelectOptionsFrame"
                SelectOptionsFrame.LayoutOrder = CountDropdown
                SelectOptionsFrame.Parent = Dropdown

                UICorner11.CornerRadius = UDim.new(0, 4)
                UICorner11.Parent = SelectOptionsFrame

                DropdownButton.Activated:Connect(
                    function()
                        if not MoreBlur.Visible then
                            MoreBlur.Visible = true
                            DropPageLayout:JumpToIndex(SelectOptionsFrame.LayoutOrder)
                            TweenService:Create(MoreBlur, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
                            TweenService:Create(
                                DropdownSelect,
                                TweenInfo.new(0.3),
                                {Position = UDim2.new(1, -11, 0.5, 0)}
                            ):Play()
                        end
                    end
                )

                OptionSelecting.Font = Enum.Font.GothamBold
                OptionSelecting.Text = DropdownConfig.Multi and "Select Options" or "Select Option"
                OptionSelecting.TextColor3 = Color3.fromRGB(255, 255, 255)
                OptionSelecting.TextSize = 12
                OptionSelecting.TextTransparency = 0.6
                OptionSelecting.TextXAlignment = Enum.TextXAlignment.Left
                OptionSelecting.AnchorPoint = Vector2.new(0, 0.5)
                OptionSelecting.BackgroundTransparency = 1
                OptionSelecting.Position = UDim2.new(0, 5, 0.5, 0)
                OptionSelecting.Size = UDim2.new(1, -30, 1, -8)
                OptionSelecting.Name = "OptionSelecting"
                OptionSelecting.TextTruncate = Enum.TextTruncate.AtEnd
                OptionSelecting.Parent = SelectOptionsFrame

                OptionImg.Image = "rbxassetid://16851841101"
                OptionImg.ImageColor3 = Color3.fromRGB(230, 230, 230)
                OptionImg.AnchorPoint = Vector2.new(1, 0.5)
                OptionImg.BackgroundTransparency = 1
                OptionImg.Position = UDim2.new(1, 0, 0.5, 0)
                OptionImg.Size = UDim2.new(0, 25, 0, 25)
                OptionImg.Name = "OptionImg"
                OptionImg.Parent = SelectOptionsFrame

                local DropdownContainer = Instance.new("Frame")
                DropdownContainer.Size = UDim2.new(1, 0, 1, 0)
                DropdownContainer.BackgroundTransparency = 1
                DropdownContainer.Parent = DropdownFolder

                local SearchBox = Instance.new("TextBox")
                SearchBox.PlaceholderText = "Search..."
                SearchBox.Font = Enum.Font.Gotham
                SearchBox.Text = ""
                SearchBox.TextSize = 12
                SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                SearchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
                SearchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                SearchBox.BackgroundTransparency = 0.85
                SearchBox.BorderSizePixel = 0
                SearchBox.Size = UDim2.new(1, -16, 0, 25)
                SearchBox.Position = UDim2.new(0, 8, 0, 3)
                SearchBox.ClearTextOnFocus = false
                SearchBox.Name = "SearchBox"
                SearchBox.Parent = DropdownContainer

                local SearchCorner = Instance.new("UICorner")
                SearchCorner.CornerRadius = UDim.new(0, 4)
                SearchCorner.Parent = SearchBox

                local SearchPadding = Instance.new("UIPadding")
                SearchPadding.PaddingLeft = UDim.new(0, 8)
                SearchPadding.PaddingRight = UDim.new(0, 8)
                SearchPadding.Parent = SearchBox

                local ScrollSelect = Instance.new("ScrollingFrame")
                ScrollSelect.Size = UDim2.new(1, 0, 1, -30)
                ScrollSelect.Position = UDim2.new(0, 0, 0, 30)
                ScrollSelect.ScrollBarImageTransparency = 1
                ScrollSelect.BorderSizePixel = 0
                ScrollSelect.BackgroundTransparency = 1
                ScrollSelect.ScrollBarThickness = 0
                ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, 0)
                ScrollSelect.Name = "ScrollSelect"
                ScrollSelect.Parent = DropdownContainer

                local ScrollPadding = Instance.new("UIPadding")
                ScrollPadding.PaddingLeft = UDim.new(0, 8)
                ScrollPadding.PaddingRight = UDim.new(0, 8)
                ScrollPadding.PaddingTop = UDim.new(0, 5)
                ScrollPadding.PaddingBottom = UDim.new(0, 5)
                ScrollPadding.Parent = ScrollSelect

                local UIListLayout4 = Instance.new("UIListLayout")
                UIListLayout4.Padding = UDim.new(0, 3)
                UIListLayout4.SortOrder = Enum.SortOrder.LayoutOrder
                UIListLayout4.Parent = ScrollSelect

                UIListLayout4:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(
                    function()
                        ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, UIListLayout4.AbsoluteContentSize.Y + 10)
                    end
                )

                SearchBox:GetPropertyChangedSignal("Text"):Connect(
                    function()
                        local query = string.lower(SearchBox.Text)
                        for _, option in pairs(ScrollSelect:GetChildren()) do
                            if option.Name == "Option" and option:FindFirstChild("OptionText") then
                                local text = string.lower(option.OptionText.Text)
                                option.Visible = query == "" or string.find(text, query, 1, true)
                            end
                        end
                        ScrollSelect.CanvasSize = UDim2.new(0, 0, 0, UIListLayout4.AbsoluteContentSize.Y + 10)
                    end
                )

                local ButtonMain
                if DropdownConfig.ButtonText then
                    ButtonMain = Instance.new("TextButton")
                    ButtonMain.Font = Enum.Font.GothamBold
                    ButtonMain.Text = DropdownConfig.ButtonText
                    ButtonMain.TextColor3 = Color3.fromRGB(255, 255, 255)
                    ButtonMain.TextSize = 12
                    ButtonMain.TextTransparency = 0.3
                    ButtonMain.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    ButtonMain.BackgroundTransparency = 0.935
                    ButtonMain.Size = UDim2.new(1, -20, 0, 30)
                    ButtonMain.Position = UDim2.new(0, 10, 1, -35)
                    ButtonMain.AutoButtonColor = false
                    ButtonMain.Parent = Dropdown

                    local btnCorner = Instance.new("UICorner")
                    btnCorner.CornerRadius = UDim.new(0, 6)
                    btnCorner.Parent = ButtonMain

                    local isPressed = false
                    local hasTriggered = false
                    local originalTransparency = 0.935

                    ButtonMain.MouseButton1Down:Connect(
                        function()
                            isPressed = true
                            hasTriggered = false
                            ButtonMain.BackgroundTransparency = 0.85
                        end
                    )

                    ButtonMain.MouseLeave:Connect(
                        function()
                            if isPressed then
                                ButtonMain.BackgroundTransparency = originalTransparency
                            end
                        end
                    )

                    ButtonMain.MouseEnter:Connect(
                        function()
                            if isPressed then
                                ButtonMain.BackgroundTransparency = 0.85
                            end
                        end
                    )

                    ButtonMain.MouseButton1Up:Connect(
                        function()
                            if isPressed and not hasTriggered then
                                hasTriggered = true
                                ButtonMain.BackgroundTransparency = originalTransparency

                                if DropdownConfig.ButtonCallback then
                                    if DropdownConfig.Multi then
                                        local values = DropdownFunc.Value or {}
                                        DropdownConfig.ButtonCallback(values)
                                    else
                                        DropdownConfig.ButtonCallback(DropdownFunc.Value)
                                    end
                                end
                            end
                            isPressed = false
                        end
                    )

                    ButtonMain.MouseButton1Click:Connect(
                        function()
                            if not hasTriggered then
                                hasTriggered = true
                                if DropdownConfig.ButtonCallback then
                                    if DropdownConfig.Multi then
                                        local values = DropdownFunc.Value or {}
                                        DropdownConfig.ButtonCallback(values)
                                    else
                                        DropdownConfig.ButtonCallback(DropdownFunc.Value)
                                    end
                                end
                            end
                        end
                    )
                end

                local DropCount = 0

                function DropdownFunc:Clear()
                    for _, DropFrame in ScrollSelect:GetChildren() do
                        if DropFrame.Name == "Option" then
                            DropFrame:Destroy()
                        end
                    end
                    DropdownFunc.Value = DropdownConfig.Multi and {} or nil
                    DropdownFunc.Options = {}
                    OptionSelecting.Text = DropdownConfig.Multi and "Select Options" or "Select Option"
                    DropCount = 0
                end

                function DropdownFunc:AddOption(option)
                    local label, value
                    if typeof(option) == "table" and option.Label and option.Value ~= nil then
                        label = tostring(option.Label)
                        value = option.Value
                    else
                        label = tostring(option)
                        value = option
                    end

                    local Option = Instance.new("Frame")
                    local OptionButton = Instance.new("TextButton")
                    local OptionText = Instance.new("TextLabel")
                    local ChooseFrame = Instance.new("Frame")
                    local UIStroke15 = Instance.new("UIStroke")
                    local UICorner38 = Instance.new("UICorner")
                    local UICorner37 = Instance.new("UICorner")

                    Option.BackgroundTransparency = 0.999
                    Option.Size = UDim2.new(1, 0, 0, 30)
                    Option.Name = "Option"
                    Option.Parent = ScrollSelect

                    UICorner37.CornerRadius = UDim.new(0, 3)
                    UICorner37.Parent = Option

                    OptionButton.BackgroundTransparency = 1
                    OptionButton.Size = UDim2.new(1, 0, 1, 0)
                    OptionButton.Text = ""
                    OptionButton.Name = "OptionButton"
                    OptionButton.Parent = Option

                    OptionText.Font = Enum.Font.GothamBold
                    OptionText.Text = label
                    OptionText.TextSize = 13
                    OptionText.TextColor3 = Color3.fromRGB(230, 230, 230)
                    OptionText.Position = UDim2.new(0, 15, 0, 8)
                    OptionText.Size = UDim2.new(1, -30, 0, 13)
                    OptionText.BackgroundTransparency = 1
                    OptionText.TextXAlignment = Enum.TextXAlignment.Left
                    OptionText.TextTruncate = Enum.TextTruncate.AtEnd
                    OptionText.Name = "OptionText"
                    OptionText.Parent = Option

                    Option:SetAttribute("RealValue", value)

                    ChooseFrame.AnchorPoint = Vector2.new(0, 0.5)
                    ChooseFrame.BackgroundColor3 = GuiConfig.Color
                    ChooseFrame.Position = UDim2.new(0, 5, 0.5, 0)
                    ChooseFrame.Size = UDim2.new(0, 0, 0, 0)
                    ChooseFrame.Name = "ChooseFrame"
                    ChooseFrame.Parent = Option

                    UIStroke15.Color = GuiConfig.Color
                    UIStroke15.Thickness = 1.6
                    UIStroke15.Transparency = 0.999
                    UIStroke15.Parent = ChooseFrame
                    UICorner38.CornerRadius = UDim.new(0, 1)
                    UICorner38.Parent = ChooseFrame

                    OptionButton.Activated:Connect(
                        function()
                            if DropdownConfig.Multi then
                                if not DropdownFunc.Value then
                                    DropdownFunc.Value = {}
                                end

                                if not table.find(DropdownFunc.Value, value) then
                                    table.insert(DropdownFunc.Value, value)
                                else
                                    for i, v in pairs(DropdownFunc.Value) do
                                        if v == value then
                                            table.remove(DropdownFunc.Value, i)
                                            break
                                        end
                                    end
                                end
                            else
                                DropdownFunc.Value = value
                            end
                            DropdownFunc:Set(DropdownFunc.Value)
                        end
                    )
                end

                function DropdownFunc:Set(Value)
                    if DropdownConfig.Multi then
                        if type(Value) == "table" then
                            DropdownFunc.Value = Value
                        elseif Value ~= nil then
                            DropdownFunc.Value = {Value}
                        else
                            DropdownFunc.Value = {}
                        end
                    else
                        if type(Value) == "table" then
                            DropdownFunc.Value = #Value > 0 and Value[1] or nil
                        else
                            DropdownFunc.Value = Value
                        end
                    end

                    if DropdownConfig.Multi then
                        if DropdownFunc.Value == nil then
                            DropdownFunc.Value = {}
                        end

                        for i = #DropdownFunc.Value, 1, -1 do
                            if DropdownFunc.Value[i] == nil then
                                table.remove(DropdownFunc.Value, i)
                            end
                        end
                    end

                    ConfigData[configKey] = DropdownFunc.Value
                    if ConfigSystem.AutoSave then SaveConfig() end

                    local texts = {}
                    local maxDisplayCount = 3
                    local maxDisplayLength = 20

                    for _, Drop in ScrollSelect:GetChildren() do
                        if Drop.Name == "Option" and Drop:FindFirstChild("OptionText") then
                            local v = Drop:GetAttribute("RealValue")
                            local selected

                            if DropdownConfig.Multi then
                                selected = table.find(DropdownFunc.Value or {}, v)
                            else
                                selected = DropdownFunc.Value == v
                            end

                            if selected then
                                TweenService:Create(
                                    Drop.ChooseFrame,
                                    TweenInfo.new(0.2),
                                    {
                                        Size = UDim2.new(0, 1, 0, 12)
                                    }
                                ):Play()
                                TweenService:Create(Drop.ChooseFrame.UIStroke, TweenInfo.new(0.2), {Transparency = 0}):Play(

                                )
                                TweenService:Create(Drop, TweenInfo.new(0.2), {BackgroundTransparency = 0.935}):Play()

                                local displayText = Drop.OptionText.Text
                                if #displayText > maxDisplayLength then
                                    displayText = string.sub(displayText, 1, maxDisplayLength - 3) .. "..."
                                end
                                table.insert(texts, displayText)
                            else
                                TweenService:Create(
                                    Drop.ChooseFrame,
                                    TweenInfo.new(0.15),
                                    {
                                        Size = UDim2.new(0, 0, 0, 0)
                                    }
                                ):Play()
                                TweenService:Create(
                                    Drop.ChooseFrame.UIStroke,
                                    TweenInfo.new(0.15),
                                    {Transparency = 0.999}
                                ):Play()
                                TweenService:Create(Drop, TweenInfo.new(0.15), {BackgroundTransparency = 0.999}):Play()
                            end
                        end
                    end

                    local displayText
                    if #texts == 0 then
                        displayText = DropdownConfig.Multi and "Select Options" or "Select Option"
                    else
                        if #texts > maxDisplayCount then
                            displayText =
                                table.concat({table.unpack(texts, 1, maxDisplayCount)}, ", ") ..
                                " +" .. (#texts - maxDisplayCount)
                        else
                            displayText = table.concat(texts, ", ")
                        end
                    end

                    OptionSelecting.Text = displayText

                    if #displayText > 30 then
                        OptionSelecting.TextSize = 11
                    else
                        OptionSelecting.TextSize = 12
                    end

                    if DropdownConfig.Callback then
                        if DropdownConfig.Multi then
                            local values = DropdownFunc.Value or {}
                            DropdownConfig.Callback(values)
                        else
                            DropdownConfig.Callback(DropdownFunc.Value)
                        end
                    end
                end

                function DropdownFunc:SetValue(val)
                    self:Set(val)
                end

                function DropdownFunc:GetValue()
                    if DropdownConfig.Multi then
                        return self.Value or {}
                    else
                        return self.Value
                    end
                end

                function DropdownFunc:SetValues(newList, selecting)
                    newList = newList or {}
                    selecting = selecting or (DropdownConfig.Multi and {} or nil)
                    DropdownFunc:Clear()
                    for _, v in ipairs(newList) do
                        DropdownFunc:AddOption(v)
                    end
                    DropdownFunc.Options = newList
                    DropdownFunc:Set(selecting)
                end

                function DropdownFunc:GetOptions()
                    return self.Options
                end

                function DropdownFunc:Refresh()
                    self:SetValues(self.Options, self.Value)
                end

                DropdownFunc:SetValues(DropdownFunc.Options, DropdownFunc.Value)

                CountItem = CountItem + 1
                CountDropdown = CountDropdown + 1
                Elements[configKey] = DropdownFunc
                return DropdownFunc
            end

            function Items:AddDivider()
                local Divider = Instance.new("Frame")
                Divider.Name = "Divider"
                Divider.Parent = SectionAdd
                Divider.AnchorPoint = Vector2.new(0.5, 0)
                Divider.Position = UDim2.new(0.5, 0, 0, 0)
                Divider.Size = UDim2.new(1, 0, 0, 2)
                Divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Divider.BackgroundTransparency = 0
                Divider.BorderSizePixel = 0
                Divider.LayoutOrder = CountItem

                local UIGradient = Instance.new("UIGradient")
                UIGradient.Color =
                    ColorSequence.new {
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 20)),
                    ColorSequenceKeypoint.new(0.5, GuiConfig.Color),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20))
                }
                UIGradient.Parent = Divider

                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 2)
                UICorner.Parent = Divider

                CountItem = CountItem + 1
                return Divider
            end

            function Items:AddSubSection(title)
                title = title or "Sub Section"

                local SubSection = Instance.new("Frame")
                SubSection.Name = "SubSection"
                SubSection.Parent = SectionAdd
                SubSection.BackgroundTransparency = 1
                SubSection.Size = UDim2.new(1, 0, 0, 22)
                SubSection.LayoutOrder = CountItem

                local Background = Instance.new("Frame")
                Background.Parent = SubSection
                Background.Size = UDim2.new(1, 0, 1, 0)
                Background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                Background.BackgroundTransparency = 0.935
                Background.BorderSizePixel = 0
                Instance.new("UICorner", Background).CornerRadius = UDim.new(0, 6)

                local Label = Instance.new("TextLabel")
                Label.Parent = SubSection
                Label.AnchorPoint = Vector2.new(0, 0.5)
                Label.Position = UDim2.new(0, 10, 0.5, 0)
                Label.Size = UDim2.new(1, -20, 1, 0)
                Label.BackgroundTransparency = 1
                Label.Font = Enum.Font.GothamBold
                Label.Text = "── [ " .. title .. " ] ──"
                Label.TextColor3 = Color3.fromRGB(230, 230, 230)
                Label.TextSize = 12
                Label.TextXAlignment = Enum.TextXAlignment.Left

                CountItem = CountItem + 1
                return SubSection
            end

            CountSection = CountSection + 1
            return Items
        end

        CountTab = CountTab + 1
        local safeName = TabConfig.Name:gsub("%s+", "_")
        _G[safeName] = Sections
        return Sections
    end

    return Tabs
end

function AesticUI:Notify(NotifyConfig)
    local NotifyConfig = NotifyConfig or {}
    NotifyConfig.Title = NotifyConfig.Title or "AesticUI"
    NotifyConfig.Description = NotifyConfig.Description or "Notification"
    NotifyConfig.Content = NotifyConfig.Content or "Content"
    NotifyConfig.Color = NotifyConfig.Color or Color3.fromRGB(155, 155, 155)
    NotifyConfig.Time = NotifyConfig.Time or 0.5
    NotifyConfig.Delay = NotifyConfig.Delay or 2
    NotifyConfig.Icon = NotifyConfig.Icon or nil
    NotifyConfig.Background = NotifyConfig.Background or nil
    NotifyConfig.CanClose = NotifyConfig.CanClose ~= false

    if not CoreGui:FindFirstChild("NotifyGui") then
        local NotifyGui = Instance.new("ScreenGui")
        NotifyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        NotifyGui.Name = "NotifyGui"
        NotifyGui.Parent = CoreGui
    end

    if not CoreGui.NotifyGui:FindFirstChild("NotifyLayout") then
        local NotifyLayout = Instance.new("Frame")
        NotifyLayout.AnchorPoint = Vector2.new(1, 1)
        NotifyLayout.BackgroundTransparency = 1
        NotifyLayout.Position = UDim2.new(1, -30, 1, -30)
        NotifyLayout.Size = UDim2.new(0, 320, 1, 0)
        NotifyLayout.Name = "NotifyLayout"
        NotifyLayout.Parent = CoreGui.NotifyGui

        local UIListLayout = Instance.new("UIListLayout")
        UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        UIListLayout.Padding = UDim.new(0, 8)
        UIListLayout.Parent = NotifyLayout

        local UIPadding = Instance.new("UIPadding")
        UIPadding.PaddingBottom = UDim.new(0, 30)
        UIPadding.Parent = NotifyLayout

        UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(
            function()
                for i, child in ipairs(NotifyLayout:GetChildren()) do
                    if child:IsA("Frame") and child.Name == "NotifyFrame" then
                        child.LayoutOrder = i
                    end
                end
            end
        )
    end

    local NotifyFunction = {}
    local wait = false

    local notificationCount = 0
    for _, child in ipairs(CoreGui.NotifyGui.NotifyLayout:GetChildren()) do
        if child:IsA("Frame") and child.Name == "NotifyFrame" then
            notificationCount = notificationCount + 1
        end
    end

    local NotifyFrame = Instance.new("Frame")
    NotifyFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    NotifyFrame.BackgroundTransparency = 0.14
    NotifyFrame.Size = UDim2.new(1, 0, 0, 0)
    NotifyFrame.Name = "NotifyFrame"
    NotifyFrame.Parent = CoreGui.NotifyGui.NotifyLayout
    NotifyFrame.LayoutOrder = notificationCount + 1
    NotifyFrame.ClipsDescendants = true

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = NotifyFrame

    if NotifyConfig.Background then
        local BackgroundImage = Instance.new("ImageLabel")
        BackgroundImage.Image = NotifyConfig.Background
        BackgroundImage.BackgroundTransparency = 1
        BackgroundImage.Size = UDim2.new(1, 0, 1, 0)
        BackgroundImage.ScaleType = Enum.ScaleType.Crop
        BackgroundImage.ImageTransparency = 0.3
        BackgroundImage.Parent = NotifyFrame

        local BackgroundCorner = Instance.new("UICorner")
        BackgroundCorner.CornerRadius = UDim.new(0, 8)
        BackgroundCorner.Parent = BackgroundImage
    end

    local Top = Instance.new("Frame")
    Top.BackgroundTransparency = 1
    Top.Size = UDim2.new(1, 0, 0, 36)
    Top.Name = "Top"
    Top.Parent = NotifyFrame

    local TitleContainer = Instance.new("Frame")
    TitleContainer.BackgroundTransparency = 1
    TitleContainer.Size = UDim2.new(1, NotifyConfig.CanClose and -40 or -20, 1, 0)
    TitleContainer.Position = UDim2.new(0, 10, 0, 0)
    TitleContainer.Parent = Top

    local UIListLayoutTitle = Instance.new("UIListLayout")
    UIListLayoutTitle.FillDirection = Enum.FillDirection.Horizontal
    UIListLayoutTitle.Padding = UDim.new(0, 8)
    UIListLayoutTitle.VerticalAlignment = Enum.VerticalAlignment.Center
    UIListLayoutTitle.Parent = TitleContainer

    if NotifyConfig.Icon then
        local IconLabel = Instance.new("ImageLabel")
        IconLabel.Image = NotifyConfig.Icon
        IconLabel.BackgroundTransparency = 1
        IconLabel.Size = UDim2.new(0, 26, 0, 26)
        IconLabel.Parent = TitleContainer
    end

    local TextLabel = Instance.new("TextLabel")
    TextLabel.Font = Enum.Font.GothamBold
    TextLabel.Text = NotifyConfig.Title
    TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.TextSize = 14
    TextLabel.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel.BackgroundTransparency = 1
    TextLabel.Size = UDim2.new(0, 0, 1, 0)
    TextLabel.AutomaticSize = Enum.AutomaticSize.X
    TextLabel.Parent = TitleContainer

    local TextLabel1 = Instance.new("TextLabel")
    TextLabel1.Font = Enum.Font.GothamBold
    TextLabel1.Text = NotifyConfig.Description
    TextLabel1.TextColor3 = NotifyConfig.Color
    TextLabel1.TextSize = 14
    TextLabel1.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel1.BackgroundTransparency = 1
    TextLabel1.Size = UDim2.new(0, 0, 1, 0)
    TextLabel1.AutomaticSize = Enum.AutomaticSize.X
    TextLabel1.Parent = TitleContainer

    if NotifyConfig.CanClose then
        local Close = Instance.new("TextButton")
        Close.Text = ""
        Close.BackgroundTransparency = 1
        Close.Size = UDim2.new(0, 25, 0, 25)
        Close.Position = UDim2.new(1, -5, 0.5, 0)
        Close.AnchorPoint = Vector2.new(1, 0.5)
        Close.Name = "Close"
        Close.Parent = Top

        local ImageLabel = Instance.new("ImageLabel")
        ImageLabel.Image = "rbxassetid://130833076800948"
        ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        ImageLabel.BackgroundTransparency = 1
        ImageLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
        ImageLabel.Size = UDim2.new(1, -8, 1, -8)
        ImageLabel.Parent = Close

        Close.MouseEnter:Connect(
            function()
                TweenService:Create(
                    ImageLabel,
                    TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {ImageTransparency = 0}
                ):Play()
            end
        )

        Close.MouseLeave:Connect(
            function()
                TweenService:Create(
                    ImageLabel,
                    TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {ImageTransparency = 0.5}
                ):Play()
            end
        )

        Close.MouseButton1Click:Connect(
            function()
                NotifyFunction:Close()
            end
        )
    end

    local TextLabel2 = Instance.new("TextLabel")
    TextLabel2.Font = Enum.Font.GothamBold
    TextLabel2.TextColor3 = Color3.fromRGB(150, 150, 150)
    TextLabel2.TextSize = 13
    TextLabel2.Text = NotifyConfig.Content
    TextLabel2.TextXAlignment = Enum.TextXAlignment.Left
    TextLabel2.TextYAlignment = Enum.TextYAlignment.Top
    TextLabel2.BackgroundTransparency = 1
    TextLabel2.Position = UDim2.new(0, 10, 0, 40)
    TextLabel2.Size = UDim2.new(1, -20, 0, 0)
    TextLabel2.AutomaticSize = Enum.AutomaticSize.Y
    TextLabel2.TextWrapped = true
    TextLabel2.Parent = NotifyFrame

    local DurationBar = Instance.new("Frame")
    DurationBar.Size = UDim2.new(1, 0, 0, 3)
    DurationBar.Position = UDim2.new(0, 0, 1, -3)
    DurationBar.AnchorPoint = Vector2.new(0, 1)
    DurationBar.BackgroundColor3 = NotifyConfig.Color
    DurationBar.BackgroundTransparency = 0.3
    DurationBar.Name = "DurationBar"
    DurationBar.Parent = NotifyFrame

    local DurationCorner = Instance.new("UICorner")
    DurationCorner.CornerRadius = UDim.new(0, 2)
    DurationCorner.Parent = DurationBar

    local function UpdateNotificationSize()
        task.wait()
        local contentHeight = TextLabel2.AbsoluteSize.Y
        local totalHeight = math.max(36 + contentHeight + 15, 65)

        NotifyFrame.Size = UDim2.new(1, 0, 0, totalHeight)
    end

    NotifyFrame.Position = UDim2.new(2, 0, 1, 0)
    NotifyFrame.AnchorPoint = Vector2.new(0, 1)

    TweenService:Create(
        NotifyFrame,
        TweenInfo.new(NotifyConfig.Time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 1, 0)}
    ):Play()

    spawn(
        function()
            task.wait(NotifyConfig.Time * 0.5)
            UpdateNotificationSize()

            if NotifyConfig.Delay > 0 then
                TweenService:Create(
                    DurationBar,
                    TweenInfo.new(NotifyConfig.Delay, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
                    {Size = UDim2.new(0, 0, 0, 3)}
                ):Play()

                task.wait(NotifyConfig.Delay)
                NotifyFunction:Close()
            end
        end
    )

    function NotifyFunction:Close()
        if wait then
            return false
        end
        wait = true

        TweenService:Create(
            NotifyFrame,
            TweenInfo.new(NotifyConfig.Time, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {
                Position = UDim2.new(2, 0, 1, 0),
                Size = UDim2.new(1, 0, 0, 0)
            }
        ):Play()

        task.wait(NotifyConfig.Time)
        NotifyFrame:Destroy()
        return true
    end

    function NotifyFunction:CloseAfter(seconds)
        task.wait(seconds)
        self:Close()
    end

    function NotifyFunction:Update(newConfig)
        if newConfig.Title then
            TextLabel.Text = newConfig.Title
        end
        if newConfig.Description then
            TextLabel1.Text = newConfig.Description
            TextLabel1.TextColor3 = newConfig.Color or NotifyConfig.Color
            DurationBar.BackgroundColor3 = newConfig.Color or NotifyConfig.Color
        end
        if newConfig.Content then
            TextLabel2.Text = newConfig.Content
            UpdateNotificationSize()
        end
    end

    function NotifyFunction:GetInfo()
        return {
            Title = TextLabel.Text,
            Description = TextLabel1.Text,
            Content = TextLabel2.Text,
            Color = TextLabel1.TextColor3
        }
    end

    return NotifyFunction
end

return AesticUI