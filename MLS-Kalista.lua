local version = "0.2"


if myHero.charName ~= "Kalista" then return end
--[[

MLStudio's Kalista v0.1 beta

v0.1 -- First release
v0.2 -- More accurate E dmg calculation and VIP_USER check

--]]

local AUTOUPDATE = true
local UPDATE_SCRIPT_NAME = "MLStudio Kalista"
local UPDATE_HOST = "raw.github.com"
local UPDATE_PATH = "/MLStudio/BoL/master/MLS-Kalista.lua"
local UPDATE_FILE_PATH = SCRIPT_PATH..GetCurrentEnv().FILE_NAME
local UPDATE_URL = "https://"..UPDATE_HOST..UPDATE_PATH

function AutoupdaterMsg(msg) print("<font color=\"#6699ff\"><b>MLStudio Kalista:</b></font> <font color=\"#FFFFFF\">"..msg..".</font>") end
if AUTOUPDATE then
    local ServerData = GetWebResult(UPDATE_HOST, UPDATE_PATH)
    if ServerData then
        --PrintChat(tostring(ServerData))
        local ServerVersion = string.match(ServerData, "local version = \"%d+.%d+\"")
        ServerVersion = string.match(ServerVersion and ServerVersion or "", "%d+.%d+")
        if ServerVersion then
            ServerVersion = tonumber(ServerVersion)
            if tonumber(version) < ServerVersion then
                AutoupdaterMsg("New version available"..ServerVersion)
                AutoupdaterMsg("Updating, please don't press F9")
                DelayAction(function() DownloadFile(UPDATE_URL, UPDATE_FILE_PATH, function () AutoupdaterMsg("Successfully updated. ("..version.." => "..ServerVersion.."), press F9 twice to load the updated version.") end) end, 3)
            else
                AutoupdaterMsg("You have got the latest version ("..ServerVersion..")")
            end
        end
    else
        AutoupdaterMsg("Error downloading version info")
    end
end

if myHero.charName ~= "Kalista" then return end
require 'VPrediction'

local enemyHeroes = {}
local spellE = myHero:GetSpellData(_E)
local VP = nil

UpdateWindow()
tSize = math.floor(WINDOW_H/35 + 0.5)
local x = math.floor(WINDOW_W * 0.2 + 0.5)
local y = math.floor(WINDOW_H * 0.015 + 0.5)
local debugMSG = ""

local SpellRangedQ = {Range = 1450, Speed = 1800, Delay = 0.2, Width = 50}


function Menu()
	ts = TargetSelector(TARGET_LESS_CAST_PRIORITY, SpellRangedQ.Range, DAMAGE_PHYSICAL)
	ts.name = "Ranged Main"
	Config = scriptConfig("Kalista", "Kalista")
	Config:addTS(ts)
	Config:addParam("Combo", "Combo", SCRIPT_PARAM_ONKEYDOWN, false, 32)
    Config:addParam("Harass", "Harass", SCRIPT_PARAM_ONKEYDOWN, false, string.byte('C'))
    Config:addParam("ks", "KS with E", SCRIPT_PARAM_ONOFF, true)
    Config:addSubMenu("Combo options", "ComboSub")
    Config:addSubMenu("Harass options", "HarassSub")
    Config:addSubMenu("Draw", "Draw")
    Config:addSubMenu("Extra", "Extra")
    Config.ComboSub:addParam("useQ", "Use Q", SCRIPT_PARAM_ONOFF, true)
    Config.ComboSub:addParam("autoERange", "Auto E on max range", SCRIPT_PARAM_ONOFF, true)
    Config.ComboSub:addParam("autoE", "Auto E on stacks reached", SCRIPT_PARAM_ONOFF, false)
    Config.ComboSub:addParam("autoEStacks", "Number of stacks reached: ", SCRIPT_PARAM_SLICE, 10, 1, 15, 0)
    Config.HarassSub:addParam("useQ", "Use Q", SCRIPT_PARAM_ONOFF, true)
    Config.HarassSub:addParam("autoERange", "Auto E on max range", SCRIPT_PARAM_ONOFF, true)
    Config.HarassSub:addParam("autoE", "Auto E on stacks reached", SCRIPT_PARAM_ONOFF, true)
    Config.HarassSub:addParam("autoEStacks", "Number of stacks reached: ", SCRIPT_PARAM_SLICE, 10, 1, 15, 0)
    Config.Draw:addParam("drawE", "Draw E Range", SCRIPT_PARAM_ONOFF, true)
    Config.Extra:addParam("debug", "Debug Mode", SCRIPT_PARAM_ONOFF, false)
    Config.Extra:addParam("packetCast", "Packet Cast Spells", SCRIPT_PARAM_ONOFF, true)

end

function OnLoad()
	Menu() --initialize Config Menu
	VP = VPrediction()

	for i = 1, heroManager.iCount do --enemy table for keeping track of stacks of rend
        local hero = heroManager:GetHero(i)
        if hero.team ~= myHero.team then
            table.insert(enemyHeroes, { object =hero, stack = 0, time = 0})
        end
    end

end

function OnTick()
	ts:update()
	local Elvl = myHero:GetSpellData(_E).level

	debugMSG = "debug: "
	for i, target in pairs(enemyHeroes) do --clear timedout stacks
		if Config.Extra.debug then
			debugMSG = debugMSG .. target.object.charName .. ": " .. tostring(target.stack) ..'    ' .. tostring(GetGameTimer() - target.time) .. '\n'
		end

		if target.stack > 0 and (GetGameTimer() - target.time) > 3.5 then
			target.stack = 0
		end
	end

	if Config.ks then
		for i, target in pairs(enemyHeroes) do
			if ValidTarget(target.object, 1000) and target.stack > 0 then
				-- local dmg = getDmg("E", target.object, myHero, 3) 
				-- dmg = dmg * (1.25 + (Elvl -1)* 0.05)^(target.stack-1)
				-- dmg = dmg * 0.90
				local dmg = eDmgCalc(target.object,target.stack)
				if Config.Extra.debug then
					debugMSG = debugMSG .. "First dmg: " .. tostring(getDmg("E", target.object, myHero, 1)) .. " Second dmg: " .. tostring(getDmg("E", target.object, myHero, 2)*target.stack) 
					.. " Third dmg: " .. tostring(getDmg("E", target.object, myHero, 3)) .. "\nE lvl: " .. tostring(Elvl)
				end
				if target.stack > 0 then
					if target.object.health <= dmg then 
						if Config.Extra.packetCast and VIP_USER then
							packetCast(_E)
						else
							CastSpell(_E)
						end
					end
				end
			end
		end 
	end

	if Config.Combo then
		Combo()
	end
	if Config.Harass then
		Harass()
	end
end

function eDmgCalc(unit, stacks)
	local first = {
		dmg = {20, 30, 40, 50, 60},
		scaling = .60
	}
	local adds = {
		dmg = {5, 9, 14, 20, 27},
		scaling = {.15, .18, .21, .24, .27}
	}
	if unit and stacks > 0 then
		local mainDmg  = first.dmg[myHero:GetSpellData(_E).level] + (first.scaling * myHero.totalDamage)
		local extraDmg = (stacks > 1 and (adds.dmg[myHero:GetSpellData(_E).level] + (adds.scaling[myHero:GetSpellData(_E).level] * myHero.totalDamage)) * (stacks - 1)) or 0
		return myHero:CalcDamage(unit, (mainDmg + extraDmg))
	end
end

function Combo()
	local target = ts.target
	if target ~= nil and ValidTarget(target,1500) and myHero:CanUseSpell(_Q) == READY and Config.ComboSub.useQ then
		local castPos, HitChance, Position = VP:GetLineCastPosition(target, 0.2, 50, 1450, 1800, myHero, true)
		if castPos ~= nil and GetDistance(castPos)<SpellRangedQ.Range and HitChance > 0 then
			--PrintChat("castPos x: " .. tostring(castPos.x) .. " castPos z: " .. tostring(castPos.z))
			if Config.Extra.packetCast and VIP_USER then
				packetCast(_Q, castPos.x, castPos.z)
			else
				CastSpell(_Q, castPos.x, castPos.z)
			end
		end
	end

	for i, current in pairs(enemyHeroes) do

		if target ~= nil and current.object.name == target.name then
			--PrintChat("Object matches target")
			if Config.ComboSub.autoE and myHero:CanUseSpell(_E) == READY and current.stack >= Config.ComboSub.autoEStacks then
				if Config.Extra.packetCast and VIP_USER then
					packetCast(_E)
				else
					CastSpell(_E)
				end
			end

			if Config.ComboSub.autoERange and myHero:CanUseSpell(_E) == READY and ValidTarget(current.object,1000) and current.stack > 0 then
				local Position, HitChance = VP:GetPredictedPos(current.object, 0.5)
				--PrintChat("Position Predicted: " .. tostring(Position.x) .. ", " .. tostring(Position.z))
				local myPosition, myHitChance = VP:GetPredictedPos(myHero,0.5)
				if Config.Extra.debug then
					debugMSG = debugMSG .. "\nPredicted Distance: " .. tostring(GetDistance(Position,myPosition)) .. "\n"
					--PrintChat("Predicted distance: " .. GetDistance(Position,myPosition))
				end
				if GetDistance(Position,myPosition) >= 1000 then
					if Config.Extra.debug then
						PrintChat("Leaving range!")
					end
					if Config.Extra.packetCast and VIP_USER then
						packetCast(_E)
					else
						CastSpell(_E)
					end
				end
			end
		end
	end
end

function Harass()
	local target = ts.target
	if target ~= nil and ValidTarget(target,1500) and myHero:CanUseSpell(_Q) == READY and Config.HarassSub.useQ then
		local castPos, HitChance, Position = VP:GetLineCastPosition(target, 0.2, 50, 1450, 1800, myHero, true)
		if castPos ~= nil and GetDistance(castPos)<SpellRangedQ.Range and HitChance > 0 then
			--PrintChat("castPos x: " .. tostring(castPos.x) .. " castPos z: " .. tostring(castPos.z))
			if Config.Extra.packetCast and VIP_USER then
				packetCast(_Q, castPos.x, castPos.z)
			else
				CastSpell(_Q, castPos.x, castPos.z)
			end
		end
	end

	for i, current in pairs(enemyHeroes) do

		if target ~= nil and current.object.name == target.name then
			--PrintChat("Object matches target")
			if Config.HarassSub.autoE and myHero:CanUseSpell(_E) == READY and current.stack >= Config.HarassSub.autoEStacks then
				if Config.Extra.packetCast and VIP_USER then
					packetCast(_E)
				else
					CastSpell(_E)
				end
			end

			if Config.HarassSub.autoERange and myHero:CanUseSpell(_E) == READY and ValidTarget(current.object,1000) and current.stack > 0 then
				local Position, HitChance = VP:GetPredictedPos(current.object, 0.5)
				--PrintChat("Position Predicted: " .. tostring(Position.x) .. ", " .. tostring(Position.z))
				local myPosition, myHitChance = VP:GetPredictedPos(myHero,0.5)
				if Config.Extra.debug then
					debugMSG = debugMSG .. "\nPredicted Distance: " .. tostring(GetDistance(Position,myPosition)) .. "\n"
					--PrintChat("Predicted distance: " .. GetDistance(Position,myPosition))
				end
				if GetDistance(Position,myPosition) >= 1000 then
					if Config.Extra.debug then
						PrintChat("Leaving range!")
					end
					if Config.Extra.packetCast and VIP_USER then
						packetCast(_E)
					else
						CastSpell(_E)
					end
				end
			end
		end
	end

end

function OnDraw()
	if Config.Extra.debug then
		DrawText(debugMSG,tSize,x,y,0xFFFF0000)
	end

	if Config.Draw.drawE and myHero:CanUseSpell(_E) == READY then
		DrawCircle(myHero.x, myHero.y, myHero.z, 1000, ARGB(200,17,17,17))
	end

end

function OnCreateObj(obj)
	for i, target in pairs(enemyHeroes) do

 		if GetDistance(target.object, obj) <80 then
 			if obj.name == "Kalista_Base_E_Spear_tar6.troy" then
 				if target.stack < 6 then
 					target.stack = 6
 				end
 				target.time = GetGameTimer()

		 	elseif obj.name == "Kalista_Base_E_Spear_tar5.troy" then
		 		if target.stack < 6 then
 					target.stack = 5
 				end
		 		target.time = GetGameTimer()
		 	elseif obj.name == "Kalista_Base_E_Spear_tar4.troy" then
		 		if target.stack < 6 then
 					target.stack = 4
 				end
		 		target.time = GetGameTimer()
		 	elseif obj.name == "Kalista_Base_E_Spear_tar3.troy" then
		 		if target.stack < 6 then
 					target.stack = 3
 				end
		 		target.time = GetGameTimer()
		 	elseif obj.name == "Kalista_Base_E_Spear_tar2.troy" then
		 		if target.stack < 6 then
 					target.stack = 2
 				end
		 		target.time = GetGameTimer()
		 	elseif obj.name == "Kalista_Base_E_Spear_tar1.troy" then
		 		if target.stack < 6 then
 					target.stack = 1
 				end
		 		target.time = GetGameTimer()
		 	end
		end
	end
end

function OnProcessSpell(unit, spell) 
    if unit.isMe then 
        if spell.name == spellE.name then
        	--PrintChat(spell.name .. " was cast! Stacks cleared!")
        	for i, target in pairs(enemyHeroes) do
        		target.stack = 0
        	end
        end

        if spell.name:lower():find("attack") then
        	--PrintChat(spell.target.name)
        	--PrintChat(tostring(spell.windUpTime))
        	for i, target in pairs(enemyHeroes) do
        		if spell.target == target.object then
        			if target.stack > 5 then
        				DelayAction(function() target.stack = target.stack + 1 end,spell.windUpTime)
        			end
        		end
        	end
        end
    end
end

function packetCast(id, param1, param2)
    if param1 ~= nil and param2 ~= nil then
    Packet("S_CAST", {spellId = id, toX = param1, toY = param2, fromX = param1, fromY = param2}):send()
    elseif param1 ~= nil then
    Packet("S_CAST", {spellId = id, toX = param1.x, toY = param1.z, fromX = param1.x, fromY = param1.z, targetNetworkId = param1.networkID}):send()
    else
    Packet("S_CAST", {spellId = id, toX = player.x, toY = player.z, fromX = player.x, fromY = player.z, targetNetworkId = player.networkID}):send()
    end
end

-- function DelayAddStack(i)
-- 	local target = enemyHeroes[i]
-- 	if target~= nil then
-- 		target.stack = target.stack + 1
-- 	end
-- end