local addon = LibStub("AceAddon-3.0"):NewAddon("MountLeash", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.MountLeash = addon

local L = LibStub("AceLocale-3.0"):GetLocale("MountLeash")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Ascension-only APIs: tolerate clients where they were renamed or removed
function addon.GetActiveSpecID()
	return SpecializationUtil and SpecializationUtil.GetActiveSpecialization and SpecializationUtil.GetActiveSpecialization() or nil
end

-- verify-allow: LibStub, ToggleDropDownMenu, UIDropDownMenu_AddButton, UIDropDownMenu_CreateInfo, UIDropDownMenu_Initialize, GENERAL, BATTLEGROUND, ENABLE, THE_MANASTORM, C_Manastorm.IsInManastorm, SpecializationUtil.GetActiveSpecialization, GetMacroInfo, GetNumMacros, GetNumMacroIcons, GetMacroIconInfo, CreateMacro, EditMacro, InCombatLockdown

local MACRO_NAME = "MountLeash"
local MACRO_ICON = "Interface\\Icons\\INV_Box_MountCarrier_01"
local MACRO_BODY = "#showtooltip\n/run if IsMounted() then Dismount() else MountLeash:SummonMount() end"
local MAX_ACCOUNT_MACROS = 36

-- Binding globals
BINDING_HEADER_MOUNTLEASH = "MountLeash"
BINDING_NAME_MOUNTLEASH_SUMMON = L["Summon Another Mount"]
BINDING_NAME_MOUNTLEASH_CONFIG = L["Open Configuration"]

-- keep track of total number of mounts so we only change the "Enable Mounts" name when the number of mounts change
local prevmounts = 0

-- Default DB
local defaults = {
	profile = {
		enable = true,
		mount_choice = {}, -- [spellid] = num (if nil default is 1)
		weighted_mounts = false,
		mount_weight = {}, -- [spellid] = weight index (if nil default is 3 / Normal)
		dismount_ground = false,
		dismount_air = false,
		immediate_mount = true,
		print_unable = false,
		log_picks = false,
		pick_log = {}, -- last 500 summoned mounts, for analysis
		sets = {
			-- locations
			customLocations = {
				-- custom locations
				["*"] = {
					enable = false,
					inherit = false,
					mounts = {} -- {spellid, spellid, ...}
				}
			},
			specialLocations = {
				-- premade (special) locations
				["*"] = {
					enable = false,
					inherit = false,
					mounts = {} -- {spellid, spellid, ...}
				}
			},
		}
	},
	char = {
		sets = {
			customSpec = {
				-- custom locations
				["*"] = {
					enable = false,
					inherit = false,
					mounts = {} -- {spellid, spellid, ...}
				}
			},
		}
	}
}

-- config

local function config_toggle_get(info) return addon.db.profile[info[#info]] end
local function config_toggle_set(info, v)
	addon.db.profile[info[#info]] = v
	AceConfigRegistry:NotifyChange("MountLeash")
end

local options = {
	name = "MountLeash",
	handler = MountLeash,
	type = 'group',
	args = {
		main = {
			name = GENERAL,
			type = 'group',
			childGroups = "tab",
			args = {
				general = {
					name = GENERAL,
					type = "group",
					order = 10,
					args = {
						dismount_ground = {
							type = "toggle",
							name = L["Dismount if on Ground"],
							order = 12,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						dismount_air = {
							type = "toggle",
							name = L["Dismount if in Air"],
							order = 12,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						immediate_mount = {
							type = "toggle",
							name = L["Summon mount if currently mounted"],
							order = 12,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						print_unable = {
							type = "toggle",
							name = L["Display output when unable to mount."],
							order = 12,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						weighted_mounts = {
							type = "toggle",
							name = L["Weighted Mounts"],
							desc = L["Pick more often the mounts with a higher weight."],
							order = 13,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						macro = {
							type = "group",
							name = L["One-button macro"],
							desc = L["Mounted: dismount. Not mounted: summon a mount with MountLeash."],
							order = 20,
							args = {
								macroText = {
									type = "input",
									name = L["Macro text (copy to a button)"],
									desc = L["Read-only: select the text below and copy it."],
									order = 1,
									width = "full",
									multiline = 2,
									get = function() return MACRO_BODY end,
									set = function() end
								},
								addMacro = {
									type = "execute",
									name = L["Add Macro"],
									desc = L["Creates or updates the macro in the General tab."],
									order = 2,
									func = function() addon:AddGeneralMacro() end
								},
							},
						},
						log_picks = {
							type = "toggle",
							name = L["Log mount picks"],
							desc = L["Store the last 500 summoned mounts in MountLeashDB for analysis."],
							order = 21,
							width = "double",
							get = config_toggle_get,
							set = config_toggle_set
						},
						clearPickLog = {
							type = "execute",
							name = L["Clear pick log"],
							desc = L["Clear the recorded summon log."],
							order = 22,
							func = function() wipe(addon.db.profile.pick_log) end
						},
					},
				},
			}
		},
		mounts = {
			type = "group",
			name = L["Enabled Mounts"],
			order = 10,
			cmdHidden = true,
			args = {
				enableAll = {
					type = "execute",
					name = L["Enable All"],
					order = 1,
					func = function(info)
						addon:_Config_Mount_SetAll(info, 4)
					end
				},
				disableAll = {
					type = "execute",
					name = L["Disable All"],
					order = 2,
					func = function(info)
						addon:_Config_Mount_SetAll(info, 1)
					end
				},
				seperator = {
					type = "header",
					name = "",
					order = 9,
				},
				mounts = {
					type = "group",
					name = "",
					order = 10,
					childGroups = "tab",
					args = {}
				}
			}
		},
		locations = {
			type = "group",
			name = L["Locations"],
			order = 11,
			cmdHidden = true,
			args = {
				specialLocations = {
					type = "group",
					name = L["Special Locations"],
					order = 1,
					args = {
						description = {
							type = "description",
							name = L["Special Locations are predefined areas that cover a certain type of zone."]
						}
					},
					plugins = { data = {} }
				},
				customLocations = {
					type = "group",
					name = L["Custom Locations"],
					order = 2,
					args = {
						addCurrentZone = {
							type = "execute",
							name = L["Add Current Zone"],
							order = 1,
							func = function(info)
								addon:AddCustomLocation(GetZoneText())
							end,
						},
						addCurrentSubZone = {
							type = "execute",
							name = L["Add Current Subzone"],
							order = 1,
							func = function(info)
								addon:AddCustomLocation(GetSubZoneText())
							end,
						},
						--addNamedZone = {
						--
						--}
					},
					plugins = { data = {} }
				},
			}
		},
		specs = {
			type = "group",
			name = L["Specs"],
			order = 12,
			cmdHidden = true,
			args = {
				customSpec = {
					type = "group",
					name = L["Custom Specialization"],
					order = 3,
					args = {
						addCurrentSpec = {
							type = "execute",
							name = L["Add Current Spec"],
							order = 1,
							func = function(info)
								local specid = addon.GetActiveSpecID()
							addon:AddCustomSpec(specid and tostring(specid) or nil)
							end,
						},
					},
					plugins = { data = {} }
				},
			}
		},
		profiles = nil, -- reserve for later setup
	},
}

local options_slashcmd = {
	name = "MountLeash Slash Command",
	handler = MountLeash,
	type = "group",
	order = -2,
	args = {
		config = {
			type = "execute",
			name = L["Open Configuration"],
			dialogHidden = true,
			order = 1,
			func = function(info) addon:OpenOptions() end
		},
		summon = {
			type = "execute",
			name = L["Summon Another Mount"],
			order = 20,
			func = function(info) addon:SummonMount() end
		},
		log = {
			type = "execute",
			name = L["Show pick log count"],
			order = 30,
			func = function()
				addon:Print(L["Pick log entries: %d"]:format(#addon.db.profile.pick_log))
			end
		},
	},
}

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("MountLeashDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChange")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChange")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChange")

	self.usable_mounts = {} -- spellid, spellid
	self.override_mounts = {} -- spellid, spellid -- OVERRIDE FOR USABLE_MOUNTS
	self.mount_map = {}    -- spellid -> {id,name} (complete)

	self.options = options
	self.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	self.options_slashcmd = options_slashcmd

	AceConfig:RegisterOptionsTable(self.name, options)
	self.optionsFrame = LibStub("LibAboutPanel").new(nil, self.name)
	self.optionsFrame.General = AceConfigDialog:AddToBlizOptions(self.name, L["General"], self.name, "main")
	self.optionsFrame.Mounts = AceConfigDialog:AddToBlizOptions(self.name, L["Enabled Mounts"], self.name, "mounts")
	self.optionsFrame.Locations = AceConfigDialog:AddToBlizOptions(self.name, L["Locations"], self.name, "locations")
	self.optionsFrame.Specs = AceConfigDialog:AddToBlizOptions(self.name, L["Specs"], self.name, "specs")
	self.optionsFrame.Profiles = AceConfigDialog:AddToBlizOptions(self.name, L["Profiles"], self.name, "profiles")
	AceConfig:RegisterOptionsTable(self.name .. "SlashCmd", options_slashcmd, { "mountleash", "pl" })

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("COMPANION_UPDATE")
	self:RegisterEvent("COMPANION_LEARNED")
	self:RegisterEvent("ZONE_CHANGED")
	self:RegisterEvent("ZONE_CHANGED_INDOORS")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("PLAYER_UPDATE_RESTING")
	self:RegisterEvent("ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED")

	self:LoadMounts()                 -- attempt to load mounts (might fail)
	self:ScheduleTimer("LoadMounts", 45) -- sometimes COMPANION_* fails

	-- specifically clicking dismiss will disable us
	-- TODO: perhaps clicking summon when we've been disabled in this
	-- way should reenable us?
	self:InitBroker()
end

function addon:OnEnable()
	if select(4, GetBuildInfo()) >= 50001 then
		self:ScheduleTimer(function()
			self:Print("This version of MountLeash is not designed for WoW 5.0.  Please check for an updated version.")
		end, 10)
	end
end

function addon:IsEnabledSummoning()
	return self.db.profile.enable
end

function addon:EnableSummoning(v)
	local oldv = self.db.profile.enable

	if ((not oldv) ~= (not v)) then
		self.db.profile.enable = v

		-- TODO: is there a better way to trigger config update?
		AceConfigRegistry:NotifyChange("MountLeash")
	end

	if (self.broker) then
		local notR = v and 1 or 0.3
		self.broker.iconG = notR
		self.broker.iconB = notR
	end
end

function addon:OpenOptions()
	InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
end

local function MacroIconIndex(path)
	for i = 1, GetNumMacroIcons() do
		if GetMacroIconInfo(i) == path then return i end
	end
	return 1
end

function addon:AddGeneralMacro()
	if InCombatLockdown() then
		self:Print(L["Cannot create a macro while in combat."])
		return
	end

	for i = 1, MAX_ACCOUNT_MACROS do
		local name, _, body = GetMacroInfo(i)
		if name == MACRO_NAME then
			if body ~= MACRO_BODY then
				EditMacro(i, MACRO_NAME, MACRO_ICON, MACRO_BODY)
				self:Print(L["Macro updated in the General tab."])
			else
				self:Print(L["Macro already exists in the General tab."])
			end
			return
		end
	end

	local accountMacros = GetNumMacros()
	if accountMacros >= MAX_ACCOUNT_MACROS then
		self:Print(L["No free General macro slots."])
		return
	end

	if CreateMacro(MACRO_NAME, MacroIconIndex(MACRO_ICON), MACRO_BODY, false) then
		self:Print(L["Macro added to the General tab."])
	else
		self:Print(L["Could not create the macro."])
	end
end

-- utility functions

local function HasCompanion(mounttype)
	for id = 1, GetNumCompanions(mounttype) do
		local _, _, _, _, issum = GetCompanionInfo(mounttype, id)
		if (issum) then
			return id
		end
	end
	return nil
end

local function IsMountted(id)
	if (id) then
		local _, _, _, _, issum = GetCompanionInfo("MOUNT", id)
		if (issum) then
			return id
		end
	else
		return HasCompanion("MOUNT")
	end
end
addon.IsMountted = IsMountted -- expose (mostly for debugging)

local function IsCasting()
	return (UnitCastingInfo("player") or UnitChannelInfo("player"))
end

local BATTLEGROUND_ARENA = { ["pvp"] = 1, ["arena"] = 1 }
local function InBattlegroundOrArena()
	local _, t = IsInInstance()
	return BATTLEGROUND_ARENA[t]
end
addon.InBattlegroundOrArena = InBattlegroundOrArena

local InCombat = InCombatLockdown -- shorthand

local function CanSummonMount()
	return
	-- are we busy?
		not IsCasting()
		and not InCombat()
		and IsOutdoors()
		and not UnitInVehicle("player")
		and not UnitIsGhost("player")
		and not UnitIsDead("player")
		and not UnitOnTaxi("player")
		and not IsFlying()
		and not IsFalling()
		and HasFullControl()
		-- verify we have mounts
		and GetNumCompanions("MOUNT") > 0
		-- gcd check
		and (not GetCompanionCooldown or GetCompanionCooldown("MOUNT", 1) == 0)
		-- don't summon if next to Nozdormu, etc
		and UnitDebuff("player", "Dismounted!") == nil
end
addon.CanSummonMount = CanSummonMount -- expose (mostly for debugging)

-- mount list handling

function addon:LoadMounts(updateconfig)
	wipe(self.usable_mounts)

	local nummounts = GetNumCompanions("MOUNT")
	for i = 1, nummounts do
		local _, name, spellid = GetCompanionInfo("MOUNT", i)

		if (not name) then
			return -- mounts not loaded yet?
		end

		if (
				self.db.profile.mount_choice[spellid] == 4 or
				(self.db.profile.mount_choice[spellid] == 3 and IsFlyableArea()) or
				(self.db.profile.mount_choice[spellid] == 2 and not IsFlyableArea())
			) then
			table.insert(self.usable_mounts, spellid)
		end

		if (not self.mount_map[spellid]) then
			self.mount_map[spellid] = {}
		end
		self.mount_map[spellid].id = i
		self.mount_map[spellid].name = name
	end

	-- Update general mount tab to show total number of mounts
	if prevmounts ~= nummounts then
		options.args.mounts.name = L["Enabled Mounts"] .. " ("..nummounts.." "..L["total mounts"]..")"
		prevmounts = nummounts
	end

	if (updateconfig == nil or updateconfig) then
		self:UpdateConfigTables(true)
	end

	-- does nothing if we've called it successfully before
	self:TryInitLocation()
	self:TryInitSpec()
end

function addon:OnProfileChange()
	self:LoadMounts()
end

addon.MountChoices = {
	"|cffff0000" .. L["Disable"] .. "|r",
	"|cffe5aa70" .. L["Ground"] .. "|r",
	"|cff87ceeb" .. L["Flyable"] .. "|r",
	"|cff7cfc00" .. L["Either"] .. "|r"
}

-- Same ordering as PetLeash, but W = 4 instead of 8: 0, 4^-2, 4^-1, 4^0, 4^1, 4^2.
-- The wider PetLeash spread made Low Priority (~1.4%) almost invisible in normal play.
local MOUNT_WEIGHTS = { 0, 1 / 16, 1 / 4, 1, 4, 16 }
addon.MountWeightChoices = {
	"|cffff0000" .. L["Never"] .. "|r",
	"|cffff6600-2|r " .. L["Extra Low Priority"],
	"|cffff9900-1|r " .. L["Low Priority"],
	"|cffddff00" .. L["Normal"] .. "|r",
	"|cff99ff00+1|r " .. L["High Priority"],
	"|cff00ff00+2|r " .. L["Extra High Priority"]
}

local MOUNTS_PER_PAGE = 25

function addon:UpdateConfigTables()
	local pages = options.args.mounts.args.mounts.args
	wipe(pages)

	local nummounts = GetNumCompanions("MOUNT")
	for start = 1, nummounts, MOUNTS_PER_PAGE do
		local finish = math.min(start + MOUNTS_PER_PAGE - 1, nummounts)
		local entries = {}

		for i = start, finish do
			local _, name, spellid = GetCompanionInfo("MOUNT", i)
			if name and spellid then
				entries[tostring(spellid)] = {
					type = "group",
					name = name,
					order = i,
					inline = true,
					args = {
						mode = {
							type = "select",
							name = L["Mode"],
							order = 1,
							width = 1.5,
							values = addon.MountChoices,
							get = "Config_Mount_Get",
							set = "Config_Mount_Set"
						},
						weight = {
							type = "select",
							name = L["Weight"],
							order = 2,
							width = 1,
							values = addon.MountWeightChoices,
							hidden = function() return not self.db.profile.weighted_mounts end,
							get = "Config_MountWeight_Get",
							set = "Config_MountWeight_Set"
						}
					}
				}
			end
		end

		pages[tostring(start)] = {
			type = "group",
			name = string.format("%d-%d", start, finish),
			order = start,
			args = entries
		}
	end

	self:UpdateLocationConfigTables()
	self:UpdateSpecConfigTables()

	-- Config Tables changed!
	AceConfigRegistry:NotifyChange("MountLeash")
end

local function config_mount_spellid(info)
	return tonumber(info[#info]) or tonumber(info[#info - 1])
end

function addon:Config_Mount_Set(info, v)
	local spellid = config_mount_spellid(info)
	if not spellid then return end
	if v > 1 then
		self.db.profile.mount_choice[spellid] = v
	else
		self.db.profile.mount_choice[spellid] = nil
	end
	self:LoadMounts(false)
end

function addon:Config_Mount_Get(info)
	local spellid = config_mount_spellid(info)
	return spellid and self.db.profile.mount_choice[spellid] or 1
end

function addon:Config_MountWeight_Set(info, v)
	local spellid = config_mount_spellid(info)
	if not spellid then return end
	if v == 3 then
		self.db.profile.mount_weight[spellid] = nil
	else
		self.db.profile.mount_weight[spellid] = v
	end
end

function addon:Config_MountWeight_Get(info)
	local spellid = config_mount_spellid(info)
	return spellid and (self.db.profile.mount_weight[spellid] or 3) or 3
end

function addon:_Config_Mount_SetAll(info, v)
	for i = 1, GetNumCompanions("MOUNT") do
		local _, _, spellid = GetCompanionInfo("MOUNT", i)
		if spellid then self.db.profile.mount_choice[spellid] = v end
	end
	self:LoadMounts(false)
end

-- events

function addon:PLAYER_ENTERING_WORLD()
	self:TryInitSpec()
	self:TryInitLocation()
end

function addon:COMPANION_UPDATE(event, ctype)
	if (ctype == nil) then
		self:LoadMounts()
	end
end

function addon:COMPANION_LEARNED()
	self:LoadMounts()
end

function addon:OnSpecChanged(curSpec)
	if self.currentSpec ~= curSpec then
		self.currentSpec = curSpec
	end
end

function addon:ZONE_CHANGED()
	self:DoLocationCheck()
	self:LoadMounts(false)
end

function addon:ZONE_CHANGED_INDOORS()
	self:DoLocationCheck()
	self:LoadMounts(false)
end

function addon:ZONE_CHANGED_NEW_AREA()
	self:DoLocationCheck()
	self:LoadMounts(false)
end

function addon:ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED(event, spec)
	self:DoLocationCheck()
	self:OnSpecChanged(spec)
end

function addon:PLAYER_UPDATE_RESTING()
	self:DoLocationCheck()
	self:LoadMounts(false)
end

local function mount_weight(self, spellid)
	return MOUNT_WEIGHTS[self.db.profile.mount_weight[spellid] or 3]
end

local function LogPick(self, spellid, source)
	if not self.db.profile.log_picks or not spellid then return end
	local log = self.db.profile.pick_log
	if #log >= 500 then table.remove(log, 1) end
	table.insert(log, {
		time = date("%Y-%m-%d %H:%M:%S"),
		name = self.mount_map[spellid] and self.mount_map[spellid].name or tostring(spellid),
		spellid = spellid,
		source = source,
		weight = self.db.profile.mount_weight[spellid] or 3,
	})
end

local function pick_flat(self, mountlist)
	mountlist = mountlist or self.usable_mounts
	if #mountlist == 0 then return nil end

	local chosen
	if not self.db.profile.weighted_mounts then
		chosen = mountlist[math.random(#mountlist)]
		self.last_pick_spellid = chosen
		return self.mount_map[chosen] and self.mount_map[chosen].id
	end

	local total = 0
	for i = 1, #mountlist do
		total = total + mount_weight(self, mountlist[i])
	end

	-- all weights set to Never: fall back to a uniform pick
	if total <= 0 then
		chosen = mountlist[math.random(#mountlist)]
		self.last_pick_spellid = chosen
		return self.mount_map[chosen] and self.mount_map[chosen].id
	end

	local r = math.random() * total
	for i = 1, #mountlist do
		r = r - mount_weight(self, mountlist[i])
		if r <= 0 then
			chosen = mountlist[i]
			self.last_pick_spellid = chosen
			return self.mount_map[chosen].id
		end
	end

	chosen = mountlist[#mountlist]
	self.last_pick_spellid = chosen
	return self.mount_map[chosen] and self.mount_map[chosen].id
end

function addon:PickMount()
	if (self.override_mounts and #self.override_mounts > 0) then
		self.last_pick_source = "override"
		return pick_flat(self, self.override_mounts)
	end

	self.last_pick_source = "global"
	return pick_flat(self)
end

function addon:SummonMount()
	local was_mounted = false
	if IsMounted() then
		was_mounted = true
		if self.db.profile.dismount_air and IsFlying() then Dismount() end
		if self.db.profile.dismount_ground and not IsFlying() then Dismount() end
	end
	if (not was_mounted or (was_mounted and self.db.profile.immediate_mount)) and (CanSummonMount() and #self.usable_mounts > 0) then
		local mountid = self:PickMount()
		if mountid then
			LogPick(self, self.last_pick_spellid, self.last_pick_source)
			CallCompanion("MOUNT", mountid)
		end
	elseif self.db.profile.print_unable then
		print("Unable to summon mount")
	end
end
