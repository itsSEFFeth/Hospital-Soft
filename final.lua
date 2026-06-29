--==================================================================
--  tyomich scripts  |  админ-панель (LocalScript)
--  Положить в: StarterPlayer > StarterPlayerScripts
--  Открыть/закрыть: клавиша G
--==================================================================

local Players            = game:GetService("Players")
local Workspace          = game:GetService("Workspace")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local CollectionService  = game:GetService("CollectionService")

local player    = Players.LocalPlayer
local camera    = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")
local npcFolder = Workspace:WaitForChild("NPCs")

--==================================================================
--  НАСТРОЙКА: где лежат предметы для морфа
--  По умолчанию — весь workspace. Можешь указать конкретную папку,
--  например: Workspace:WaitForChild("Misc"):WaitForChild("ShopItems")
--==================================================================
local MORPH_FOLDER = Workspace

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
	skin      = Color3.fromRGB(225, 70, 70),    -- скинволкер (красный)
	safe      = Color3.fromRGB(70, 180, 110),   -- обычный НПС (зелёный)
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

-- определяем скинволкера: разработчик помечает их тегом Skinwalker
-- и/или атрибутом Skinwalker=true. Проверяем оба варианта.
local function isSkinwalker(npc)
	if CollectionService:HasTag(npc, "Skinwalker") then return true end
	if npc:GetAttribute("Skinwalker") == true then return true end
	return false
end

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

-- камера в 3 лицо на собственного персонажа (нужно для морфа и просто как вид)
local function thirdPersonSelf()
	currentNPC = nil
	if freecam.enabled then stopFreecam() end

	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMinZoomDistance = 1
	player.CameraMaxZoomDistance = 15
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
main.Size = UDim2.new(0, 500, 0, 360)
main.Position = UDim2.new(0.5, -250, 0.5, -180)
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
	end
end

local function makeNpcButton(npc)
	if npcButtons[npc] then return end

	local skin = isSkinwalker(npc)

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = COL.btn
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Parent = npcScroll
	corner(b, 6)

	-- цветной маркер слева: красный = скинволкер, зелёный = обычный
	local dotMark = Instance.new("Frame")
	dotMark.Size = UDim2.new(0, 8, 0, 8)
	dotMark.Position = UDim2.new(0, 8, 0.5, -4)
	dotMark.BackgroundColor3 = skin and COL.skin or COL.safe
	dotMark.BorderSizePixel = 0
	dotMark.Parent = b
	corner(dotMark, 4)

	-- имя НПС
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -75, 1, 0)
	nameLbl.Position = UDim2.new(0, 22, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = npc.Name
	nameLbl.TextColor3 = COL.text
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.Font = Enum.Font.Gotham
	nameLbl.TextSize = 13
	nameLbl.Parent = b

	-- бейдж типа справа
	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.new(0, 46, 0, 16)
	badge.Position = UDim2.new(1, -52, 0.5, -8)
	badge.BackgroundColor3 = skin and COL.skin or COL.safe
	badge.Text = skin and "SKIN" or "SAFE"
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 9
	badge.BorderSizePixel = 0
	badge.Parent = b
	corner(badge, 4)

	-- обновление визуала типа (если тег/атрибут навесят позже спавна)
	local function refreshType()
		local s = isSkinwalker(npc)
		dotMark.BackgroundColor3 = s and COL.skin or COL.safe
		badge.BackgroundColor3 = s and COL.skin or COL.safe
		badge.Text = s and "SKIN" or "SAFE"
	end
	refreshType()

	-- реагируем, если тип определится/сменится уже после создания кнопки
	npc:GetAttributeChangedSignal("Skinwalker"):Connect(refreshType)
	CollectionService:GetInstanceAddedSignal("Skinwalker"):Connect(function(inst)
		if inst == npc then refreshType() end
	end)
	CollectionService:GetInstanceRemovedSignal("Skinwalker"):Connect(function(inst)
		if inst == npc then refreshType() end
	end)

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
--  ВКЛАДКА: PLAYER  (скорость / прыжок / ноуклип / телепорт)
--==================================================================
local playerPage = addTab("Player")

local pLayout = Instance.new("UIListLayout")
pLayout.Padding = UDim.new(0, 10)
pLayout.SortOrder = Enum.SortOrder.LayoutOrder
pLayout.Parent = playerPage

-- желаемые значения (применяются и переустанавливаются после респавна)
local desiredWalkSpeed = 16
local desiredJumpPower = 50
local noclipEnabled = false

local function getHumanoid()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function applyPlayerStats()
	local hum = getHumanoid()
	if not hum then return end
	hum.UseJumpPower = true
	hum.WalkSpeed = desiredWalkSpeed
	hum.JumpPower = desiredJumpPower
end

-- читаем текущие значения как стартовые
do
	local hum = getHumanoid()
	if hum then
		desiredWalkSpeed = hum.WalkSpeed
		desiredJumpPower = (hum.UseJumpPower and hum.JumpPower) or 50
	end
end

--// конструктор ползунка
local function makeSlider(parent, labelText, minVal, maxVal, default, order, onChange)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 44)
	box.BackgroundTransparency = 1
	box.LayoutOrder = order
	box.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -60, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = COL.text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.Parent = box

	local valueLbl = Instance.new("TextLabel")
	valueLbl.Size = UDim2.new(0, 60, 0, 18)
	valueLbl.Position = UDim2.new(1, -60, 0, 0)
	valueLbl.BackgroundTransparency = 1
	valueLbl.TextColor3 = COL.subtext
	valueLbl.TextXAlignment = Enum.TextXAlignment.Right
	valueLbl.Font = Enum.Font.Gotham
	valueLbl.TextSize = 12
	valueLbl.Parent = box

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0, 30)
	track.BackgroundColor3 = COL.tabIdle
	track.BorderSizePixel = 0
	track.Parent = box
	corner(track, 3)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = COL.accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 3)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = track
	corner(knob, 7)

	local value = default

	local function redraw(v)
		local ratio = math.clamp((v - minVal) / (maxVal - minVal), 0, 1)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		knob.Position = UDim2.new(ratio, 0, 0.5, 0)
		valueLbl.Text = tostring(math.floor(v + 0.5))
	end

	local function setFromX(x)
		local rel = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
		rel = math.clamp(rel, 0, 1)
		value = minVal + rel * (maxVal - minVal)
		redraw(value)
		if onChange then onChange(value) end
	end

	redraw(value)

	local dragging = false
	local function press(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end
	track.InputBegan:Connect(press)
	knob.InputBegan:Connect(press)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	return box
end

-- заголовок
local pTitle = Instance.new("TextLabel")
pTitle.Size = UDim2.new(1, 0, 0, 18)
pTitle.BackgroundTransparency = 1
pTitle.Text = "Параметры персонажа"
pTitle.TextColor3 = COL.subtext
pTitle.TextXAlignment = Enum.TextXAlignment.Left
pTitle.Font = Enum.Font.GothamBold
pTitle.TextSize = 12
pTitle.LayoutOrder = 0
pTitle.Parent = playerPage

-- ползунок скорости
makeSlider(playerPage, "Скорость ходьбы", 0, 150, desiredWalkSpeed, 1, function(v)
	desiredWalkSpeed = v
	local hum = getHumanoid()
	if hum then hum.WalkSpeed = v end
end)

-- ползунок прыжка
makeSlider(playerPage, "Сила прыжка", 0, 250, desiredJumpPower, 2, function(v)
	desiredJumpPower = v
	local hum = getHumanoid()
	if hum then hum.UseJumpPower = true; hum.JumpPower = v end
end)

-- тумблер ноуклипа
local noclipBtn = makeButton(playerPage, "Ноуклип: ВЫКЛ", 34)
noclipBtn.LayoutOrder = 3
local function updateNoclipBtn()
	noclipBtn.Text = noclipEnabled and "Ноуклип: ВКЛ" or "Ноуклип: ВЫКЛ"
	noclipBtn.BackgroundColor3 = noclipEnabled and COL.on or COL.btn
end
noclipBtn.MouseButton1Click:Connect(function()
	noclipEnabled = not noclipEnabled
	updateNoclipBtn()
end)
updateNoclipBtn()

-- телепорт к выбранному НПС
local tpBtn = makeButton(playerPage, "Телепорт к выбранному НПС", 34)
tpBtn.LayoutOrder = 4
tpBtn.MouseButton1Click:Connect(function()
	if not currentNPC or not currentNPC.Parent then return end
	local target = currentNPC:FindFirstChild("HumanoidRootPart")
		or currentNPC:FindFirstChild("RootPart")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if target and hrp then
		-- встаём чуть перед НПС, лицом к нему
		hrp.CFrame = target.CFrame * CFrame.new(0, 0, 5)
	end
end)

local tpHint = Instance.new("TextLabel")
tpHint.Size = UDim2.new(1, 0, 0, 14)
tpHint.BackgroundTransparency = 1
tpHint.Text = "Телепорт к тому НПС, за кем сейчас наблюдаешь (вкладка Camera)"
tpHint.TextColor3 = COL.subtext
tpHint.TextXAlignment = Enum.TextXAlignment.Left
tpHint.TextWrapped = true
tpHint.Font = Enum.Font.Gotham
tpHint.TextSize = 9
tpHint.LayoutOrder = 5
tpHint.Parent = playerPage

-- ноуклип: каждый кадр снимаем коллизию с частей персонажа
RunService.Stepped:Connect(function()
	if not noclipEnabled then return end
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end)

-- после респавна возвращаем заданные скорость/прыжок
player.CharacterAdded:Connect(function()
	task.wait(0.3)
	applyPlayerStats()
end)

-- кнопка переключения вида 1/3 лицо за себя (в Player)
local selfTP = false
local viewBtn = makeButton(playerPage, "Вид: 1-е лицо", 34)
viewBtn.LayoutOrder = 6
viewBtn.MouseButton1Click:Connect(function()
	selfTP = not selfTP
	if selfTP then
		thirdPersonSelf()
		viewBtn.Text = "Вид: 3-е лицо"
	else
		returnToPlayer()
		viewBtn.Text = "Вид: 1-е лицо"
	end
end)

--==================================================================
--  ВКЛАДКА: MORPH  (визуальное превращение в предметы, только для себя)
--==================================================================
local morphPage = addTab("Morph")

local currentMorph = nil   -- клон предмета, надетый на игрока
local morphActive  = false
local morphWeld    = nil   -- сварка опоры к игроку (через её C0 двигаем морф)
local offX, offY, offZ = 0, 0, 0   -- смещение морфа (в локальных осях игрока)

local function applyMorphOffset()
	if morphWeld then
		morphWeld.C0 = CFrame.new(offX, offY, offZ)
	end
end

-- посчитать BasePart внутри модели
local function partCount(model)
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

-- снять морф и вернуть свою видимость
local function removeMorph()
	morphActive = false
	morphWeld = nil
	if currentMorph then
		currentMorph:Destroy()
		currentMorph = nil
	end
	local char = player.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
				d.LocalTransparencyModifier = 0
			end
		end
	end
end

-- надеть морф
local function applyMorph(model)
	removeMorph()

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and hrp) then return end
	if partCount(model) == 0 then return end

	local clone = model:Clone()
	-- вырезаем скрипты предмета, чтобы его логика не запускалась
	for _, s in ipairs(clone:GetDescendants()) do
		if s:IsA("LuaSourceContainer") then s:Destroy() end
	end
	clone.Name = "TyomichMorph"

	-- ставим предмет на позицию игрока
	if clone:IsA("Model") then
		clone:PivotTo(hrp.CFrame)
	end

	-- невидимая опора в позиции игрока: к ней приварим все части,
	-- а саму опору — к игроку сваркой с управляемым смещением (C0)
	local root = Instance.new("Part")
	root.Name = "MorphRoot"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.CanCollide = false
	root.Massless = true
	root.Anchored = false
	root.CFrame = hrp.CFrame
	root.Parent = clone

	-- части предмета привариваем к опоре (сохраняя их взаимное расположение)
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end

	-- опору крепим к игроку сваркой; C0 = смещение, его двигаем вживую
	local weld = Instance.new("Weld")
	weld.Part0 = hrp
	weld.Part1 = root
	weld.C0 = CFrame.new(offX, offY, offZ)
	weld.Parent = root
	morphWeld = weld

	clone.Parent = char
	currentMorph = clone
	morphActive = true

	-- авто 3 лицо, чтобы видеть превращение
	selfTP = true
	if viewBtn then viewBtn.Text = "Вид: 3-е лицо" end
	thirdPersonSelf()
end

-- каждый кадр прячем своё тело (локально), пока активен морф
RunService.RenderStepped:Connect(function()
	if not morphActive then return end
	local char = player.Character
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		-- не трогаем сам морф
		if not (currentMorph and d:IsDescendantOf(currentMorph)) then
			if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
				d.LocalTransparencyModifier = 1
			end
		end
	end
end)

-- сброс морфа при респавне
player.CharacterAdded:Connect(function()
	currentMorph = nil
	morphActive = false
end)

--// интерфейс вкладки Morph
local morphSearch = Instance.new("TextBox")
morphSearch.Size = UDim2.new(1, 0, 0, 26)
morphSearch.BackgroundColor3 = COL.btn
morphSearch.PlaceholderText = "Поиск предмета..."
morphSearch.Text = ""
morphSearch.TextColor3 = COL.text
morphSearch.PlaceholderColor3 = COL.subtext
morphSearch.Font = Enum.Font.Gotham
morphSearch.TextSize = 12
morphSearch.ClearTextOnFocus = false
morphSearch.BorderSizePixel = 0
morphSearch.Parent = morphPage
corner(morphSearch, 6)
padding(morphSearch, 6)

local morphScroll = Instance.new("ScrollingFrame")
morphScroll.Size = UDim2.new(1, 0, 1, -106)
morphScroll.Position = UDim2.new(0, 0, 0, 32)
morphScroll.BackgroundTransparency = 1
morphScroll.BorderSizePixel = 0
morphScroll.ScrollBarThickness = 4
morphScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
morphScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
morphScroll.Parent = morphPage

local morphLayout = Instance.new("UIListLayout")
morphLayout.Padding = UDim.new(0, 4)
morphLayout.SortOrder = Enum.SortOrder.LayoutOrder
morphLayout.Parent = morphScroll

-- подпись к полям смещения
local offLabel = Instance.new("TextLabel")
offLabel.Size = UDim2.new(1, 0, 0, 14)
offLabel.Position = UDim2.new(0, 0, 1, -72)
offLabel.BackgroundTransparency = 1
offLabel.Text = "Смещение X / Y / Z  (например Y = -5 — опустить на пол)"
offLabel.TextColor3 = COL.subtext
offLabel.TextXAlignment = Enum.TextXAlignment.Left
offLabel.Font = Enum.Font.Gotham
offLabel.TextSize = 9
offLabel.Parent = morphPage

-- контейнер с тремя полями
local offRow = Instance.new("Frame")
offRow.Size = UDim2.new(1, 0, 0, 24)
offRow.Position = UDim2.new(0, 0, 1, -56)
offRow.BackgroundTransparency = 1
offRow.Parent = morphPage

local function makeAxisBox(axisName, xScale, onSet)
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.31, 0, 1, 0)
	box.Position = UDim2.new(xScale, 0, 0, 0)
	box.BackgroundColor3 = COL.btn
	box.PlaceholderText = axisName
	box.Text = "0"
	box.TextColor3 = COL.text
	box.PlaceholderColor3 = COL.subtext
	box.Font = Enum.Font.Gotham
	box.TextSize = 12
	box.ClearTextOnFocus = false
	box.BorderSizePixel = 0
	box.Parent = offRow
	corner(box, 6)

	box.FocusLost:Connect(function()
		local n = tonumber(box.Text) or 0
		box.Text = tostring(n)
		onSet(n)
		applyMorphOffset()
	end)
	return box
end

makeAxisBox("X", 0,     function(n) offX = n end)
makeAxisBox("Y", 0.345, function(n) offY = n end)
makeAxisBox("Z", 0.69,  function(n) offZ = n end)

local unmorphBtn = makeButton(morphPage, "Снять морф (вернуть себя)", 32)
unmorphBtn.Position = UDim2.new(0, 0, 1, -30)
unmorphBtn.Size = UDim2.new(1, 0, 0, 28)
unmorphBtn.MouseButton1Click:Connect(function()
	removeMorph()
end)

-- собираем список предметов (Model с хотя бы одной частью), считаем дубли имён
local function buildMorphList(filter)
	for _, c in ipairs(morphScroll:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	filter = string.lower(filter or "")

	local seen = {}
	local order = 0
	for _, item in ipairs(MORPH_FOLDER:GetChildren()) do
		if item:IsA("Model") and partCount(item) > 0 then
			local name = item.Name
			seen[name] = (seen[name] or 0) + 1
			local display = name
			if seen[name] > 1 then
				display = name .. " #" .. seen[name]
			end

			if filter == "" or string.find(string.lower(display), filter, 1, true) then
				order += 1
				local b = makeButton(morphScroll, display, 28)
				b.LayoutOrder = order
				b.MouseButton1Click:Connect(function()
					applyMorph(item)
				end)
			end
		end
	end
end

buildMorphList("")
morphSearch:GetPropertyChangedSignal("Text"):Connect(function()
	buildMorphList(morphSearch.Text)
end)

--==================================================================
--  ВКЛАДКА: SHIFT  (визуальная правка номера смены, только у тебя)
--==================================================================
local shiftPage = addTab("Shift")

-- находим ВСЕ лейблы номера смены: над основным часто лежит дубликат
-- (тень), который перекрывал наш текст. Меняем все одинаковые сразу.
local function getShiftLabels()
	local sg = playerGui:FindFirstChild("Shift")
	if not sg then return {} end

	-- опорный лейбл: header, иначе первый со словом Shift
	local anchor
	for _, d in ipairs(sg:GetDescendants()) do
		if d:IsA("TextLabel") and d.Name == "header" then anchor = d break end
	end
	if not anchor then
		for _, d in ipairs(sg:GetDescendants()) do
			if d:IsA("TextLabel") and string.find(d.Text, "Shift") then anchor = d break end
		end
	end
	if not anchor then return {} end

	-- все лейблы с тем же текстом, что у опорного (основной + тень/дубликаты)
	local target = anchor.Text
	local labels = {}
	for _, d in ipairs(sg:GetDescendants()) do
		if d:IsA("TextLabel") and d.Text == target then
			table.insert(labels, d)
		end
	end
	if #labels == 0 then labels = { anchor } end
	return labels
end

local shiftTitle = Instance.new("TextLabel")
shiftTitle.Size = UDim2.new(1, 0, 0, 18)
shiftTitle.BackgroundTransparency = 1
shiftTitle.Text = "Текст смены (виден только тебе)"
shiftTitle.TextColor3 = COL.subtext
shiftTitle.TextXAlignment = Enum.TextXAlignment.Left
shiftTitle.Font = Enum.Font.GothamBold
shiftTitle.TextSize = 12
shiftTitle.Parent = shiftPage

local shiftInput = Instance.new("TextBox")
shiftInput.Size = UDim2.new(1, 0, 0, 30)
shiftInput.Position = UDim2.new(0, 0, 0, 24)
shiftInput.BackgroundColor3 = COL.btn
shiftInput.PlaceholderText = "Напиши что угодно..."
shiftInput.Text = ""
shiftInput.TextColor3 = COL.text
shiftInput.PlaceholderColor3 = COL.subtext
shiftInput.Font = Enum.Font.Gotham
shiftInput.TextSize = 13
shiftInput.ClearTextOnFocus = false
shiftInput.BorderSizePixel = 0
shiftInput.Parent = shiftPage
corner(shiftInput, 6)
padding(shiftInput, 8)

local applyShiftBtn = makeButton(shiftPage, "Применить", 32)
applyShiftBtn.Position = UDim2.new(0, 0, 0, 62)
applyShiftBtn.Size = UDim2.new(0.48, 0, 0, 30)

local resetShiftBtn = makeButton(shiftPage, "Сбросить", 32)
resetShiftBtn.Position = UDim2.new(0.52, 0, 0, 62)
resetShiftBtn.Size = UDim2.new(0.48, 0, 0, 30)

local shiftHint = Instance.new("TextLabel")
shiftHint.Size = UDim2.new(1, 0, 0, 40)
shiftHint.Position = UDim2.new(0, 0, 0, 100)
shiftHint.BackgroundTransparency = 1
shiftHint.Text = "Закрепляет твой текст, даже когда игра меняет смену. Шрифт и стиль остаются прежними. «Сбросить» возвращает управление игре."
shiftHint.TextColor3 = COL.subtext
shiftHint.TextXAlignment = Enum.TextXAlignment.Left
shiftHint.TextYAlignment = Enum.TextYAlignment.Top
shiftHint.TextWrapped = true
shiftHint.Font = Enum.Font.Gotham
shiftHint.TextSize = 10
shiftHint.Parent = shiftPage

local customText = nil      -- если задан — закрепляем
local lockedLabels = {}     -- лейблы, которые держим под нашим текстом
local lockConns = {}        -- соединения слежения за изменением текста

local function clearShiftLocks()
	for _, c in ipairs(lockConns) do
		c:Disconnect()
	end
	lockConns = {}
	lockedLabels = {}
end

local function applyShift()
	-- если уже закреплены — переиспользуем те же лейблы, иначе ищем заново
	local labels = (#lockedLabels > 0) and lockedLabels or getShiftLabels()
	if #labels == 0 then return end

	customText = shiftInput.Text
	clearShiftLocks()
	lockedLabels = labels

	for _, lbl in ipairs(labels) do
		lbl.Text = customText
		-- закрепляем: если игра вернёт свой текст — снова ставим наш
		local conn = lbl:GetPropertyChangedSignal("Text"):Connect(function()
			if customText and lbl.Text ~= customText then
				lbl.Text = customText
			end
		end)
		table.insert(lockConns, conn)
	end
end

applyShiftBtn.MouseButton1Click:Connect(applyShift)
resetShiftBtn.MouseButton1Click:Connect(function()
	customText = nil
	clearShiftLocks()
end)

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
