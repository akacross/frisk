script_name("frisk")
script_version("0.1")
script_author("akacross")
script_url("https://akacross.net/")

if getMoonloaderVersion() >= 27 then
	require 'libstd.deps' {
	   'fyp:mimgui',
	   'fyp:fa-icons-4',
	   'donhomka:extensions-lite'
	}
end

require"lib.moonloader"
require"lib.sampfuncs"
require 'extensions-lite'

local imgui, ffi = require 'mimgui', require 'ffi'
local new, str = imgui.new, ffi.string
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local mem = require 'memory'
local vk = require 'vkeys'
local faicons = require 'fa-icons'
local ti = require 'tabler_icons'
local fa = require 'fAwesome5'
local mainc = imgui.ImVec4(0.92, 0.27, 0.92, 1.0) -- Розовый
local path = getWorkingDirectory() .. '\\config\\' 
local cfg = path .. 'frisk.ini'
local PressType = {KeyDown = isKeyDown, KeyPressed = wasKeyPressed}

local blank = {}
local frisk = {
	key = VK_F,
	bool = {false,false},
	autosave = false
}
local show = new.bool()
local changekey = false

local function loadIconicFont(fromfile, fontSize, min, max, fontdata)
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    local iconRanges = new.ImWchar[3](min, max, 0)
	if fromfile then
		imgui.GetIO().Fonts:AddFontFromFileTTF(fontdata, fontSize, config, iconRanges)
	else
		imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fontdata, fontSize, config, iconRanges)
	end
end

imgui.OnInitialize(function()
	apply_custom_style() -- apply custom style

	loadIconicFont(false, 14.0, faicons.min_range, faicons.max_range, faicons.get_font_data_base85())
	loadIconicFont(true, 14.0, fa.min_range, fa.max_range, 'moonloader/resource/fonts/fa-solid-900.ttf')
	loadIconicFont(false, 14.0, ti.min_range, ti.max_range, ti.get_font_data_base85())
	
	imgui.GetIO().ConfigWindowsMoveFromTitleBarOnly = true
	imgui.GetIO().IniFilename = nil
end)

imgui.OnFrame(function() return show[0] end,
function()
	local width, height = getScreenResolution()
	imgui.SetNextWindowPos(imgui.ImVec2(width / 2, height / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.Begin('Frisk', show, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
		if imgui.Button(ti.ICON_DEVICE_FLOPPY.. 'Save') then
			saveIni()
		end 
		imgui.SameLine()
		if imgui.Button(ti.ICON_FILE_UPLOAD.. 'Load') then
			loadIni()
		end 
		imgui.SameLine()
		if imgui.Button(ti.ICON_ERASER .. 'Reset') then
			blankIni()
		end 
		imgui.SameLine()
		if imgui.Checkbox('Autosave', new.bool(frisk.autosave)) then 
			frisk.autosave = not frisk.autosave 
			saveIni() 
		end  
		
		if imgui.Checkbox("Player Target", new.bool(frisk.bool[1])) then
			frisk.bool[1] = not frisk.bool[1]
		end
		imgui.SameLine()
		if imgui.Checkbox("Player Aim", new.bool(frisk.bool[2])) then
			frisk.bool[2] = not frisk.bool[2]
		end
	
		imgui.Text('Change frisk key:')
		imgui.SameLine()
		if imgui.Button(changekey and 'Press any key' or vk.id_to_name(frisk.key)) then
			changekey = true
			lua_thread.create(function()
				while changekey do wait(0)
					local keydown, result = getDownKeys()
					if result then
						frisk.key = keydown
						changekey = false
					end
				end
			end)
		end
	imgui.End()
end)

function main()
	blank = table.deepcopy(frisk)
	if not doesDirectoryExist(path) then createDirectory(path) end
	if doesFileExist(cfg) then loadIni() else blankIni() end
	while not isSampAvailable() do wait(100) end
    sampfuncsLog("(Frisk: /frisk)")
	sampRegisterChatCommand('frisk', function() show[0] = not show[0] end)
	while true do wait(0)
		if keycheck({k  = {VK_RBUTTON,frisk.key}, t = {'KeyDown', 'KeyPressed'}}) then
			local _, ped = storeClosestEntities(playerPed)
			local result, id = sampGetPlayerIdByCharHandle(ped)
			local result2, target = getCharPlayerIsTargeting(playerHandle)
			if result then
				if (result2 and frisk.bool[1]) or not frisk.bool[1] then
					if (target == ped and frisk.bool[1]) or not frisk.bool[1] then
						if (isPlayerAiming(true, true) and frisk.bool[2]) or not frisk.bool[2] then
							sampSendChat(string.format("/frisk %d", id))
							wait(1000)
						end
					end
				end
			end
		end
	end
end

function onScriptTerminate(scr, quitGame) 
	if scr == script.this then 
		if frisk.autosave then 
			saveIni() 
		end 
	end
end

function keycheck(k)
    local r = true
    for i = 1, #k.k do r = r and PressType[k.t[i]](k.k[i]) end
    return r
end

function getDownKeys()
    local keyslist = nil
    local bool = false
    for k, v in pairs(vk) do
        if isKeyDown(v) then
            keyslist = v
            bool = true
        end
    end
    return keyslist, bool
end

function isPlayerAiming(thirdperson, firstperson)
	local id = mem.read(11989416, 2, false)
	if thirdperson and (id == 5 or id == 53 or id == 55 or id == 65) then return true end
	if firstperson and (id == 7 or id == 8 or id == 16 or id == 34 or id == 39 or id == 40 or id == 41 or id == 42 or id == 45 or id == 46 or id == 51 or id == 52) then return true end
end

function blankIni()
	frisk = table.deepcopy(blank)
	saveIni()
	loadIni()
end

function loadIni()
	local f = io.open(cfg, "r")
	if f then
		frisk = decodeJson(f:read("*all"))
		f:close()
	end
end

function saveIni()
	if type(frisk) == "table" then
		local f = io.open(cfg, "w")
		f:close()
		if f then
			f = io.open(cfg, "r+")
			f:write(encodeJson(frisk))
			f:close()
		end
	end
end

function apply_custom_style()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	style.WindowRounding = 1.5
	style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
	style.FrameRounding = 1.0
	style.ItemSpacing = imgui.ImVec2(4.0, 4.0)
	style.ScrollbarSize = 13.0
	style.ScrollbarRounding = 0
	style.GrabMinSize = 8.0
	style.GrabRounding = 1.0
	style.WindowBorderSize = 0.0
	style.WindowPadding = imgui.ImVec2(4.0, 4.0)
	style.FramePadding = imgui.ImVec2(2.5, 3.5)
	style.ButtonTextAlign = imgui.ImVec2(0.5, 0.35)
 
	colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
	colors[clr.TextDisabled]           = ImVec4(0.7, 0.7, 0.7, 1.0)
	colors[clr.WindowBg]               = ImVec4(0.07, 0.07, 0.07, 1.0)
	colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
	colors[clr.Border]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.4)
	colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.FrameBg]                = ImVec4(mainc.x, mainc.y, mainc.z, 0.7)
	colors[clr.FrameBgHovered]         = ImVec4(mainc.x, mainc.y, mainc.z, 0.4)
	colors[clr.FrameBgActive]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.9)
	colors[clr.TitleBg]                = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
	colors[clr.TitleBgActive]          = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
	colors[clr.TitleBgCollapsed]       = ImVec4(mainc.x, mainc.y, mainc.z, 0.79)	
	colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
	colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
	colors[clr.ScrollbarGrab]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
	colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
	colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)
	colors[clr.CheckMark]              = ImVec4(mainc.x + 0.13, mainc.y + 0.13, mainc.z + 0.13, 1.00)
	colors[clr.SliderGrab]             = ImVec4(0.28, 0.28, 0.28, 1.00)
	colors[clr.SliderGrabActive]       = ImVec4(0.35, 0.35, 0.35, 1.00)
	colors[clr.Button]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
	colors[clr.ButtonHovered]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
	colors[clr.ButtonActive]           = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
	colors[clr.Header]                 = ImVec4(mainc.x, mainc.y, mainc.z, 0.6)
	colors[clr.HeaderHovered]          = ImVec4(mainc.x, mainc.y, mainc.z, 0.43)
	colors[clr.HeaderActive]           = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
	colors[clr.Separator]              = colors[clr.Border]
	colors[clr.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
	colors[clr.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.ResizeGrip]             = ImVec4(mainc.x, mainc.y, mainc.z, 0.8)
	colors[clr.ResizeGripHovered]      = ImVec4(mainc.x, mainc.y, mainc.z, 0.63)
	colors[clr.ResizeGripActive]       = ImVec4(mainc.x, mainc.y, mainc.z, 1.0)
	colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
	colors[clr.PlotHistogram]          = ImVec4(0.90, 0.70, 0.00, 1.00)
	colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.60, 0.00, 1.00)
	colors[clr.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
 end