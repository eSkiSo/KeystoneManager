KeystoneManager = LibStub('AceAddon-3.0'):NewAddon('KeystoneManager', 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0');
AceGUI = LibStub('AceGUI-3.0');

local defaults = {
	global = {
		keystones = {},
		target = 'GUILD',
		whisper = ''
	}
};

function KeystoneManager:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New('KeystoneManagerDb', defaults);
	self:RegisterChatCommand('keystonemanager', 'ShowWindow');
	self:RegisterChatCommand('keylist', 'ShowWindow');
	self:RegisterChatCommand('keyprint', 'PrintKeystone');
	self:RegisterEvent('BAG_UPDATE');
	self:RegisterEvent('PLAYER_ENTERING_WORLD');
end

function KeystoneManager:PLAYER_ENTERING_WORLD()
	self:GetWeeklyBest();
end

function KeystoneManager:BAG_UPDATE()
	self:GetKeystone();
end

function KeystoneManager:ShowWindow(input)
	if not self.KeystoneWindow then
		KeystoneManager:GetWeeklyBest();

		self.KeystoneWindow = AceGUI:Create('Window');
		self.KeystoneWindow:SetTitle('Keystone Manager');
		self.KeystoneWindow:SetLayout('Flow');
		self.KeystoneWindow:SetWidth(570);
		self.KeystoneWindow:SetHeight(500);
		self.KeystoneWindow:EnableResize(false);

		local target = AceGUI:Create('Dropdown');
		target:SetLabel('Report to');
		target:SetList({
			['WHISPER'] = 'Whisper',
			['GUILD'] = 'Guild',
			['PARTY'] = 'Party',
			['RAID'] = 'Raid',
			['INSTANCE_CHAT'] = 'Instance',
		});
		target:SetValue(self.db.global.target);
		target:SetCallback('OnValueChanged', function(self, event, key)
			KeystoneManager.db.global.target = key;
		end);
		self.KeystoneWindow:AddChild(target);

		local whisper = AceGUI:Create('EditBox');
		whisper:SetLabel('Whisper target');
		whisper:SetText(self.db.global.whisper);
		whisper:SetCallback('OnTextChanged', function(self, event, text)
			KeystoneManager.db.global.whisper = text;
		end);
		self.KeystoneWindow:AddChild(whisper);


		local btn = AceGUI:Create('Button');
		btn:SetWidth(100);
		btn:SetText('Report');
		btn:SetCallback('OnClick', function()
			self:ReportKeys();
		end);
		self.KeystoneWindow:AddChild(btn);

		local ScrollingTable = LibStub('ScrollingTable');
		local cols = {
			{
				['name'] = 'Character',
				['width'] = 120,
				['align'] = 'LEFT',
			},

			{
				['name'] = 'Weekly Best',
				['width'] = 80,
				['align'] = 'LEFT',
			},

			{
				['name'] = 'Key',
				['width'] = 120,
				['align'] = 'LEFT',
			},

			{
				['name'] = 'Dungeon',
				['width'] = 140,
				['align'] = 'LEFT',
			},

			{
				['name'] = 'Level',
				['width'] = 40,
				['align'] = 'LEFT',
			},
		}
		self.ScrollTable = ScrollingTable:CreateST(cols, 16, 20, nil, self.KeystoneWindow.content);

		self:UpdateTable(self.ScrollTable);

		self.ScrollTable:RegisterEvents({
			['OnClick'] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
				local link = data[row][3];
				if link then
					GameTooltip:SetOwner(UIParent);
					GameTooltip:SetHyperlink(link);
					GameTooltip:Show();
				end
			end,
		});
		local tableWrapper = AceGUI:Create('lib-st'):WrapST(self.ScrollTable);

		tableWrapper.head_offset = 20;
		self.KeystoneWindow:AddChild(tableWrapper);

		-- Clear button
		local clearBtn = AceGUI:Create('Button');
		clearBtn:SetWidth(100);
		clearBtn:SetText('Clear');

		clearBtn:SetCallback('OnClick', function()
			self:ClearKeystones();
		end);
		self.KeystoneWindow:AddChild(clearBtn);

		-- Refresh button
		local refreshbtn = AceGUI:Create('Button');
		refreshbtn:SetWidth(100);
		refreshbtn:SetText('Refresh');

		refreshbtn:SetCallback('OnClick', function()
			self:GetKeystone(true);
			self:GetWeeklyBest();
		end);
		self.KeystoneWindow:AddChild(refreshbtn);

		-- Set points manually
		clearBtn:ClearAllPoints();
		clearBtn:SetPoint('BOTTOMLEFT', self.KeystoneWindow.frame, 20, 20);
		refreshbtn:ClearAllPoints();
		refreshbtn:SetPoint('BOTTOMLEFT', self.KeystoneWindow.frame, 130, 20);
	end

	self.KeystoneWindow:Show();
end

function KeystoneManager:GetKeystone(force)
	force = force or false;
	local name = self:NameAndRealm();
	if not self.db.global.keystones then
		self.db.global.keystones = {};
	end
	local keystone = self.db.global.keystones[name];

	for bag = 0, NUM_BAG_SLOTS do
		local numSlots = GetContainerNumSlots(bag);
		if numSlots ~= 0 then
			for slot = 1, numSlots do
				if (GetContainerItemID(bag, slot) == 138019) then
					local link = GetContainerItemLink(bag, slot);
					local oldKey = self.db.global.keystones[name];

					local info = self:ExtractKeystoneInfo(link);
					local oldInfo = self:ExtractKeystoneInfo(oldKey);

					if force or oldInfo == nil or (info.dungeonId ~= oldInfo.dungeonId and info.level ~= oldInfo.level) then --keystone has changed
						SendChatMessage(
							'New Keystone - ' .. link .. ' - ' .. info.dungeonName .. ' +' .. info.level,
							'PARTY'
						);
						self.db.global.keystones[name] = link;
						self:GetWeeklyBest();
						self:UpdateTable(self.ScrollTable);
					end
					return link;
				end
			end
		end
	end

	return keystone;
end

function KeystoneManager:GetWeeklyBest()
	local name = self:NameAndRealm();
	if not self.db.global.weeklyBest then
		self.db.global.weeklyBest = {};
	end

	C_ChallengeMode.RequestMapInfo();
	local mapTable = C_ChallengeMode.GetMapTable();
	local best = 0;
	for i, mapId in pairs(mapTable) do
		local _, weeklyBestTime, weeklyBestLevel = C_ChallengeMode.GetMapPlayerStats(mapId);

		if weeklyBestLevel and weeklyBestLevel > best then
			best = weeklyBestLevel;
		end
	end

	self.db.global.weeklyBest[name] = best;
	return best;
end

function KeystoneManager:PrintKeystone()
	local name = self:NameAndRealm();
	local keystone = self.db.global.keystones[name];
	if keystone then
		keystone = self:GetKeystone();
	end
	self:Print(keystone);
end

function KeystoneManager:ReportKeys()
	local target = self.db.global.whisper;
	if self.db.global.target ~= 'WHISPER' then
		target = nil;
	end

	for char, key in pairs(self.db.global.keystones) do
		local info = self:ExtractKeystoneInfo(key);

		SendChatMessage(
			self:NameWithoutRealm(char) .. ' - ' .. key .. ' - ' .. info.dungeonName .. ' +' .. info.level,
			self.db.global.target,
			nil,
			target
		);
	end
end

function KeystoneManager:ClearKeystones()
	self.db.global.weeklyBest = {};
	self.db.global.keystones = {};
	self:UpdateTable(self.ScrollTable);
end

function KeystoneManager:UpdateTable(table)
	if not table then
		return;
	end

	local tableData = {};
	for char, key in pairs(self.db.global.keystones) do
		local info = self:ExtractKeystoneInfo(key);
		local weeklyBest = self.db.global.weeklyBest[char];

		local color = '|cff1eff00';
		if not info.lootEligible then
			color = '|cff9d9d9d';
		end

		tinsert(tableData, {
			self:NameWithoutRealm(char),
			weeklyBest,
			key,
			color .. info.dungeonName,
			'+' .. info.level
		});
	end

	table:SetData(tableData, true);
end

function KeystoneManager:NameAndRealm()
	return UnitName('player') .. '-' .. GetRealmName();
end

function KeystoneManager:NameWithoutRealm(name)
	return gsub(name, "%-[^|]+", "");
end

function KeystoneManager:ExtractKeystoneInfo(link)
	if not link then
		return nil;
	end

	local parts = { strsplit(':', link) }

	local dungeonId = tonumber(parts[15]);
	local level = tonumber(parts[16]);
	local numAffixes = ({0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3})[level];
	local lootEligible = (tonumber(parts[17 + numAffixes]) == 1)
	local dungeonName = C_ChallengeMode.GetMapInfo(dungeonId);

	return {
		dungeonId = dungeonId,
		dungeonName = dungeonName,
		level = level,
		lootEligible = lootEligible,
	}
end
