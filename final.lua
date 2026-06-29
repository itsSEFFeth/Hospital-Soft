--==================================================================
--  tyomich scripts  |  админ-панель (LocalScript)
--  Положить в: StarterPlayer > StarterPlayerScripts
--  Открыть/закрыть: клавиша G
--==================================================================

local Players            = game:GetService("Players")
local Workspace          = game:GetService("Workspace")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")

local player    = Players.LocalPlayer
local camera    = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")
local npcFolder = Workspace:WaitForChild("NPCs")

--==================================================================
--  ПАЛИТРА (тёмная тема)
--==================================================================
local COL = {
	bg        = Color3.fromRGB(22, 22, 27),
	panel     = Color3.fromRGB(28, 28, 35),
	titlebar  = Color3.fromRGB(16, 16, 20),
	tabIdle   = Color3.fromRGB(38, 38, 47),
	tabActive = Color3.fromRGB(120, 90, 255),
	btn       = Color3.fromRGB(46, 46, 57),
	btnHover  = Color3.fromRGB(60, 60, 74),
	accent    = Color3.fromRGB(120, 90, 255),
	on        = Color3.fromRGB(70, 180, 110),
	off       = Color3.fromRGB(90, 90, 105),
	text      = Color3.fromRGB(235, 235, 240),
	subtext   = Color3.fromRGB(160, 160, 175),
}

--==================================================================
--  ХЕЛПЕРЫ ДЛЯ UI
--==================================================================
local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

local function padding(parent, p)
	local u = Instance.new("UIPadding")
	u.PaddingTop = UDim.new(0, p); u.PaddingBottom = UDim.new(0, p)
	u.PaddingLeft = UDim.new(0, p); u.PaddingRight = UDim.new(0, p)
	u.Parent = parent
	return u
end

local function makeButton(parent, text, height)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, height or 32)
	b.BackgroundColor3 = COL.btn
	b.Text = text
	b.TextColor3 = COL.text
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 6)
	b.MouseEnter:Connect(function() b.BackgroundColor3 = COL.btnHover end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = COL.btn end)
	return b
end

--==================================================================
--  СОСТОЯНИЕ КАМЕРЫ
--==================================================================
local currentNPC = nil
local updateNpcHighlight   -- определяется ниже, после создания кнопок

-- базовые настройки для режима наблюдения (3 лицо)
local function applyWatchSettings()
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 1
	player.CameraMaxZoomDistance = 15
	camera.CameraType = Enum.CameraType.Custom
end

--==================================================================
--  FREECAM (свободный полёт)
--==================================================================
local freecam = { enabled = false, pos = Vector3.zero, yaw = 0, pitch = 0, conn = nil }
local FREECAM_SPEED = 60      -- обычная скорость (стадов/сек)
local FREECAM_FAST  = 180     -- с зажатым Shift
local SENS          = 0.006   -- чувствительность мыши

-- безопасно достаём управление персонажем, чтобы отключать его в freecam
local function getControls()
	local ps = player:FindFirstChild("PlayerScripts")
	if not ps then return nil end
	local pm = ps:FindFirstChild("PlayerModule")
	if not pm then return nil end
	local ok, controls = pcall(function() return require(pm):GetControls() end)
	return ok and controls or nil
end

local function freecamStep(dt)
	-- осмотр по зажатой ПКМ (чтобы курсор был свободен для панели)
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		local d = UserInputService:GetMouseDelta()
		freecam.yaw   = freecam.yaw - d.X * SENS
		freecam.pitch = math.clamp(freecam.pitch - d.Y * SENS, -math.pi/2 + 0.05, math.pi/2 - 0.05)
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	local rot   = CFrame.fromEulerAnglesYXZ(freecam.pitch, freecam.yaw, 0)
	local speed = (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and FREECAM_FAST or FREECAM_SPEED)

	local dir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += rot.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= rot.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += rot.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= rot.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.E) then dir += Vector3.yAxis end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) then dir -= Vector3.yAxis end

	if dir.Magnitude > 0 then
		freecam.pos += dir.Unit * speed * dt
	end

	camera.CFrame = CFrame.new(freecam.pos) * rot
end

local function startFreecam()
	if freecam.enabled then return end
	freecam.enabled = true

	-- инициализируем из текущего положения камеры
	freecam.pos = camera.CFrame.Position
	local rx, ry = camera.CFrame:ToEulerAnglesYXZ()
	freecam.pitch, freecam.yaw = rx, ry

	camera.CameraType = Enum.CameraType.Scriptable
	local controls = getControls()
	if controls then controls:Disable() end   -- персонаж не двигается на WASD

	freecam.conn = RunService.RenderStepped:Connect(freecamStep)
end

local function stopFreecam()
	if not freecam.enabled then return end
	freecam.enabled = false

	if freecam.conn then freecam.conn:Disconnect(); freecam.conn = nil end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	local controls = getControls()
	if controls then controls:Enable() end

	-- возвращаем камеру в наблюдение
	applyWatchSettings()
	if currentNPC and currentNPC.Parent then
		local hum = currentNPC:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end
end

--==================================================================
--  НАБЛЮДЕНИЕ ЗА НПС
--==================================================================
local function watchNPC(npc)
	if not npc or not npc.Parent then return end
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if freecam.enabled then stopFreecam() end
	currentNPC = npc
	applyWatchSettings()
	camera.CameraSubject = hum
	if updateNpcHighlight then updateNpcHighlight() end
end

-- вернуть камеру обратно на игрока (первое лицо, как в игре по умолчанию)
local function returnToPlayer()
	currentNPC = nil
	if freecam.enabled then stopFreecam() end

	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	camera.CameraType = Enum.CameraType.Custom

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end

	if updateNpcHighlight then updateNpcHighlight() end
end

--==================================================================
--  ГЛАВНОЕ ОКНО
--==================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "TyomichScripts"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 480, 0, 320)
main.Position = UDim2.new(0.5, -240, 0.5, -160)
main.BackgroundColor3 = COL.bg
main.BorderSizePixel = 0
main.Visible = false
main.Parent = gui
corner(main, 12)

local stroke = Instance.new("UIStroke")
stroke.Color = COL.accent
stroke.Thickness = 1
stroke.Transparency = 0.5
stroke.Parent = main

--// ШАПКА (перетаскиваемая)
local titlebar = Instance.new("Frame")
titlebar.Size = UDim2.new(1, 0, 0, 38)
titlebar.BackgroundColor3 = COL.titlebar
titlebar.BorderSizePixel = 0
titlebar.Parent = main
corner(titlebar, 12)

local titlebarFix = Instance.new("Frame") -- скрываем нижние скруглённые углы шапки
titlebarFix.Size = UDim2.new(1, 0, 0, 12)
titlebarFix.Position = UDim2.new(0, 0, 1, -12)
titlebarFix.BackgroundColor3 = COL.titlebar
titlebarFix.BorderSizePixel = 0
titlebarFix.Parent = titlebar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -20, 1, 0)
titleText.Position = UDim2.new(0, 14, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "tyomich scripts"
titleText.TextColor3 = COL.text
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 15
titleText.Parent = titlebar

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 8, 0, 8)
dot.Position = UDim2.new(1, -22, 0.5, -4)
dot.BackgroundColor3 = COL.accent
dot.BorderSizePixel = 0
dot.Parent = titlebar
corner(dot, 4)

--// ЛЕВАЯ КОЛОНКА С ВКЛАДКАМИ
local tabsCol = Instance.new("Frame")
tabsCol.Size = UDim2.new(0, 110, 1, -38)
tabsCol.Position = UDim2.new(0, 0, 0, 38)
tabsCol.BackgroundColor3 = COL.panel
tabsCol.BorderSizePixel = 0
tabsCol.Parent = main

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.Padding = UDim.new(0, 6)
tabsLayout.Parent = tabsCol
padding(tabsCol, 8)

--// ОБЛАСТЬ КОНТЕНТА
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -110, 1, -38)
content.Position = UDim2.new(0, 110, 0, 38)
content.BackgroundTransparency = 1
content.Parent = main

--==================================================================
--  СИСТЕМА ВКЛАДОК
--==================================================================
local tabs = {}          -- { button=, page= }
local function selectTab(name)
	for n, t in pairs(tabs) do
		local active = (n == name)
		t.button.BackgroundColor3 = active and COL.tabActive or COL.tabIdle
		t.button.TextColor3 = active and Color3.new(1,1,1) or COL.subtext
		t.page.Visible = active
	end
end

local function addTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = COL.tabIdle
	btn.Text = name
	btn.TextColor3 = COL.subtext
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = tabsCol
	corner(btn, 6)

	local page = Instance.new("Frame")
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = content
	padding(page, 12)

	tabs[name] = { button = btn, page = page }
	btn.MouseButton1Click:Connect(function() selectTab(name) end)
	return page
end

--==================================================================
--  ВКЛАДКА: CAMERA
--==================================================================
local cameraPage = addTab("Camera")

local camTitle = Instance.new("TextLabel")
camTitle.Size = UDim2.new(1, 0, 0, 18)
camTitle.BackgroundTransparency = 1
camTitle.Text = "Наблюдение за НПС"
camTitle.TextColor3 = COL.subtext
camTitle.TextXAlignment = Enum.TextXAlignment.Left
camTitle.Font = Enum.Font.GothamBold
camTitle.TextSize = 12
camTitle.Parent = cameraPage

-- список НПС
local npcScroll = Instance.new("ScrollingFrame")
npcScroll.Size = UDim2.new(1, 0, 1, -116)
npcScroll.Position = UDim2.new(0, 0, 0, 24)
npcScroll.BackgroundTransparency = 1
npcScroll.BorderSizePixel = 0
npcScroll.ScrollBarThickness = 4
npcScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
npcScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
npcScroll.Parent = cameraPage

local npcLayout = Instance.new("UIListLayout")
npcLayout.Padding = UDim.new(0, 5)
npcLayout.SortOrder = Enum.SortOrder.Name
npcLayout.Parent = npcScroll

-- кнопка freecam внизу
local freecamBtn = makeButton(cameraPage, "Freecam: ВЫКЛ", 34)
freecamBtn.Position = UDim2.new(0, 0, 1, -50)
freecamBtn.AnchorPoint = Vector2.new(0, 0)
freecamBtn.Size = UDim2.new(1, 0, 0, 32)

local freecamHint = Instance.new("TextLabel")
freecamHint.Size = UDim2.new(1, 0, 0, 14)
freecamHint.Position = UDim2.new(0, 0, 1, -16)
freecamHint.BackgroundTransparency = 1
freecamHint.Text = "WASD лететь • E/Q вверх-вниз • ПКМ осмотр • Shift быстрее"
freecamHint.TextColor3 = COL.subtext
freecamHint.TextXAlignment = Enum.TextXAlignment.Left
freecamHint.Font = Enum.Font.Gotham
freecamHint.TextSize = 9
freecamHint.Parent = cameraPage

local function updateFreecamBtn()
	if freecam.enabled then
		freecamBtn.Text = "Freecam: ВКЛ"
		freecamBtn.BackgroundColor3 = COL.on
	else
		freecamBtn.Text = "Freecam: ВЫКЛ"
		freecamBtn.BackgroundColor3 = COL.btn
	end
end

freecamBtn.MouseButton1Click:Connect(function()
	if freecam.enabled then stopFreecam() else startFreecam() end
	updateFreecamBtn()
end)

-- кнопка возврата камеры к игроку
local returnBtn = makeButton(cameraPage, "Вернуться к игроку", 30)
returnBtn.Position = UDim2.new(0, 0, 1, -84)
returnBtn.Size = UDim2.new(1, 0, 0, 30)
returnBtn.MouseButton1Click:Connect(function()
	returnToPlayer()
	updateFreecamBtn()
end)

--// наполнение списка НПС (в реальном времени)
local npcButtons = {}  -- [npc] = button

-- подсветка кнопки текущего НПС (присваиваем форвард-объявленный local)
function updateNpcHighlight()
	for npc, b in pairs(npcButtons) do
		local active = (npc == currentNPC)
		b:SetAttribute("active", active)
		b.BackgroundColor3 = active and COL.accent or COL.btn
		b.TextColor3 = active and Color3.new(1, 1, 1) or COL.text
	end
end

local function makeNpcButton(npc)
	if npcButtons[npc] then return end

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = COL.btn
	b.Text = npc.Name
	b.TextColor3 = COL.text
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Parent = npcScroll
	corner(b, 6)

	-- ховер не перебивает подсветку активного
	b.MouseEnter:Connect(function()
		if not b:GetAttribute("active") then b.BackgroundColor3 = COL.btnHover end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = b:GetAttribute("active") and COL.accent or COL.btn
	end)

	b.MouseButton1Click:Connect(function()
		watchNPC(npc)
		updateFreecamBtn()
	end)

	npcButtons[npc] = b
	updateNpcHighlight()
end

local function removeNpcButton(npc)
	if npcButtons[npc] then
		npcButtons[npc]:Destroy()
		npcButtons[npc] = nil
	end
end

for _, npc in ipairs(npcFolder:GetChildren()) do
	if npc:IsA("Model") then makeNpcButton(npc) end
end

npcFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		task.defer(function()
			if child.Parent == npcFolder then makeNpcButton(child) end
		end)
	end
end)

npcFolder.ChildRemoved:Connect(function(child)
	removeNpcButton(child)
	if child == currentNPC then currentNPC = nil end
end)

--==================================================================
--  ВКЛАДКА: UI  (скрытие элементов из PlayerGui)
--==================================================================
local uiPage = addTab("UI")

local uiTitle = Instance.new("TextLabel")
uiTitle.Size = UDim2.new(1, 0, 0, 18)
uiTitle.BackgroundTransparency = 1
uiTitle.Text = "Элементы интерфейса"
uiTitle.TextColor3 = COL.subtext
uiTitle.TextXAlignment = Enum.TextXAlignment.Left
uiTitle.Font = Enum.Font.GothamBold
uiTitle.TextSize = 12
uiTitle.Parent = uiPage

local uiScroll = Instance.new("ScrollingFrame")
uiScroll.Size = UDim2.new(1, 0, 1, -28)
uiScroll.Position = UDim2.new(0, 0, 0, 24)
uiScroll.BackgroundTransparency = 1
uiScroll.BorderSizePixel = 0
uiScroll.ScrollBarThickness = 4
uiScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
uiScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
uiScroll.Parent = uiPage

local uiLayout = Instance.new("UIListLayout")
uiLayout.Padding = UDim.new(0, 5)
uiLayout.SortOrder = Enum.SortOrder.Name
uiLayout.Parent = uiScroll

-- читаем/задаём видимость для разных типов
local function isElementVisible(el)
	if el:IsA("LayerCollector") then return el.Enabled
	elseif el:IsA("GuiObject") then return el.Visible end
	return true
end
local function setElementVisible(el, v)
	if el:IsA("LayerCollector") then el.Enabled = v
	elseif el:IsA("GuiObject") then el.Visible = v end
end

local function makeUiRow(el)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundColor3 = COL.btn
	row.BorderSizePixel = 0
	row.Parent = uiScroll
	corner(row, 6)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -90, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = el.Name
	label.TextColor3 = COL.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.Parent = row

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0, 72, 0, 22)
	toggle.Position = UDim2.new(1, -80, 0.5, -11)
	toggle.Text = ""
	toggle.AutoButtonColor = false
	toggle.BorderSizePixel = 0
	toggle.Parent = row
	corner(toggle, 11)

	local function refresh()
		local vis = isElementVisible(el)
		toggle.BackgroundColor3 = vis and COL.on or COL.off
		toggle.Text = vis and "Показан" or "Скрыт"
		toggle.TextColor3 = Color3.new(1, 1, 1)
		toggle.Font = Enum.Font.GothamMedium
		toggle.TextSize = 11
	end
	refresh()

	toggle.MouseButton1Click:Connect(function()
		setElementVisible(el, not isElementVisible(el))
		refresh()
	end)

	return row
end

local function refreshUiList()
	for _, c in ipairs(uiScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for _, el in ipairs(playerGui:GetChildren()) do
		-- не показываем саму нашу панель
		if el ~= gui and (el:IsA("LayerCollector") or el:IsA("GuiObject")) then
			makeUiRow(el)
		end
	end
end

refreshUiList()
playerGui.ChildAdded:Connect(function() task.defer(refreshUiList) end)
playerGui.ChildRemoved:Connect(function() task.defer(refreshUiList) end)

--==================================================================
--  ПЕРЕТАСКИВАНИЕ ОКНА ЗА ШАПКУ
--==================================================================
local dragging, dragStart, startPos
titlebar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

--==================================================================
--  ХОТКЕЙ: G — открыть/закрыть панель
--==================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.G then
		main.Visible = not main.Visible
	end
end)

--==================================================================
--  СВОБОДНЫЙ КУРСОР, ПОКА ПАНЕЛЬ ОТКРЫТА
--  В первом лице движок лочит мышь по центру (она крутит камеру),
--  поэтому по кнопкам не кликнуть. Пока панель видна — освобождаем
--  курсор. Делаем это ПОСЛЕ обновления камеры (приоритет Camera+1),
--  иначе камера тут же залочит мышь обратно.
--==================================================================
RunService:BindToRenderStep("TyomichPanelMouse", Enum.RenderPriority.Camera.Value + 1, function()
	if not main.Visible then return end          -- панель закрыта — не вмешиваемся
	if freecam.enabled then return end            -- во фрикаме мышь управляется отдельно
	-- даём осмотреться по зажатой ПКМ (3 лицо), не мешаем
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

	UserInputService.MouseIconEnabled = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end)

--==================================================================
--  СТАРТ
--==================================================================
selectTab("Camera")
applyWatchSettings()
updateFreecamBtn()

-- сразу садимся на первого НПС (необязательно — можно удалить)
local first = npcFolder:FindFirstChildWhichIsA("Model")
if first then watchNPC(first) end
