print("[DEBUG] sh_npc.lua loaded")

-- Global table to store dialog data (shared between server and client)
-- TODO: Set this up as a MySQLite table
NPCDialogsGlobal = NPCDialogsGlobal or {}

ENT = {}
ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Base NPC"
ENT.Author = "Paradise"
ENT.Spawnable = false
ENT.ClassName = "npc_base"

-- Attributes
ENT.ID = 0
ENT.ModelName = "models/Humans/Group01/male_07.mdl"
ENT.Location = Vector(0, 0, 0)
ENT.DailyItinerary = {}
ENT.SpeechPhrases = {}
ENT.NPCDialogs = {}
ENT.MissionStartIDs = {}
ENT.MissionParticipations = {}
ENT.VendorShopID = nil
ENT.CanBeKilled = false
ENT.CanAttackPlayer = false
ENT.CanAttackNPC = false
ENT.Stats = nil
ENT.WeaponID = nil

if SERVER then
    AddCSLuaFile()
    -- util.PrecacheModel(ENT.ModelName)

    NPC_ID_COUNTER = NPC_ID_COUNTER or 0

    function ENT:Initialize()
        NPC_ID_COUNTER = NPC_ID_COUNTER + 1
        self.ID = NPC_ID_COUNTER
        self:SetModel(self.ModelName)
        self:PhysicsInit(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_BBOX)
        self:SetUseType(SIMPLE_USE)
        print("[DEBUG] Server: SetUseType to SIMPLE_USE for NPC " .. self:EntIndex())
        print("[DEBUG] Server: NPC collision bounds: " .. tostring(self:OBBMins()) .. " to " .. tostring(self:OBBMaxs()))

        self:SetNWVars()

        self.Stats = NPCStats:New(self)

        local dialogId = "default"
        print("[DEBUG] Server: DialogTrees['default'] exists: " .. tostring(DialogTrees["default"] ~= nil))
        print("[DEBUG] Server: Creating dialog with dialogId=" .. tostring(dialogId))
        self.NPCDialogs[1] = NPCDialog:New(self, dialogId, 1)
        print("[DEBUG] Server: Initialized dialog for NPC " .. self.ID .. ": " .. table.Count(self.NPCDialogs) .. " dialogs")
        
        -- Network the dialog metadata to the client
        self:SetNWInt("DialogCount", #self.NPCDialogs)
        for i, dialog in ipairs(self.NPCDialogs) do
            self:SetNWString("DialogID_" .. i, dialog.DialogID)
            self:SetNWInt("DialogIndex_" .. i, dialog.DialogIndex)
        end

        timer.Simple(0, function()
            if IsValid(self) then
                self:DropToFloor()
                self.Location = self:GetPos()
                self:SetNWVector("Location", self.Location)
                print("[DEBUG] Server: NPC " .. self:EntIndex() .. " (ID: " .. self.ID .. ") spawned at " .. tostring(self:GetPos()))
            end
        end)
    end
    
    function ENT:SetNWVars()
        self:SetNWInt("NPCID", self.ID)
        self:SetNWString("ModelName", self.ModelName)
        self:SetNWVector("Location", self.Location)
        self:SetNWBool("CanBeKilled", self.CanBeKilled)
        self:SetNWBool("CanAttackPlayer", self.CanAttackPlayer)
        self:SetNWBool("CanAttackNPC", self.CanAttackNPC)
        self:SetNWInt("WeaponID", self.WeaponID)
    end

    function ENT:Use(activator, caller)
        print("[DEBUG] Server: NPC " .. self:EntIndex() .. " (ID: " .. self.ID .. ") used by " .. caller:Nick())
        if not IsValid(caller) or not caller:IsPlayer() then return end
        if not self:HasDialog() then return end

        local dialog = self.NPCDialogs[1]
        dialog:Open(caller, 1)
    end

    function ENT:HasDialog()
        return #self.NPCDialogs > 0
    end

    function ENT:UpdateTransmitState()
        return TRANSMIT_ALWAYS
    end

    function ENT:OnTakeDamage(dmg)
        if not self.CanBeKilled then return end
        local stats = self.Stats:GetStats(self)
        local hp = stats.Health - dmg:GetDamage()
        self.Stats:SetHealth(self, math.max(0, hp))
        if hp <= 0 then
            self:Remove()
        end
    end

    function ENT:GetNPCDialogs()
        return self.NPCDialogs
    end

    function ENT:GetMissionStartIDs()
        return self.MissionStartIDs
    end

    function ENT:GetMissionParticipations()
        return self.MissionParticipations
    end

    function ENT:GetVendorShopID()
        return self.VendorShopID
    end

    function ENT:GetStats()
        return self.Stats:GetStats(self)
    end
end
    --[[ function ENT:OpenDialog(caller, dialogIndex, nodeIndex)
        print("[DEBUG] Server: Opening dialog " .. dialogIndex .. " node " .. nodeIndex .. " for " .. caller:Nick())
        net.Start("OpenNPCDialog")
        net.WriteEntity(self)
        net.WriteInt(dialogIndex, 32)
        net.WriteInt(nodeIndex, 32)
        net.Send(caller)
        print("[DEBUG] Server: Sent OpenNPCDialog to " .. caller:Nick())
    end ]]

    --[[ net.Receive("OpenNPCDialog", function(len, ply)
        local npc = net.ReadEntity()
        if not IsValid(npc) or npc:GetClass() != "npc_base" then return end
        local dialogIndex = net.ReadInt(32)
        local nodeIndex = net.ReadInt(32)
        print("[DEBUG] Server: Received OpenNPCDialog for NPC " .. npc:EntIndex() .. " (ID: " .. npc:GetNWInt("NPCID") .. ") from " .. ply:Nick() .. " - Dialog: " .. dialogIndex .. " Node: " .. nodeIndex)

        -- Validate the NPC and dialog
        if not npc:HasDialog() then return end
        local dialogs = npc:GetNPCDialogs()
        local dialog = dialogs[dialogIndex]
        if not dialog then
            print("[DEBUG] Server: Dialog " .. dialogIndex .. " not found for NPC " .. npc:EntIndex())
            return
        end

        -- Validate the node
        local node = dialog:GetNode(nodeIndex)
        if not node or not node.Text then
            print("[DEBUG] Server: Node " .. nodeIndex .. " not found in dialog " .. dialogIndex .. " for NPC " .. npc:EntIndex())
            return
        end

        -- Send the dialog to the client
        npc:OpenDialog(ply, dialogIndex, nodeIndex)
    end)

    function ENT:UpdateTransmitState()
        return TRANSMIT_PVS
    end

    function ENT:OnTakeDamage(dmg)
        if not self.CanBeKilled then return end
        local stats = self.Stats:GetStats(self)
        local hp = stats.Health - dmg:GetDamage()
        self.NPCStats:SetHealth(self, math.max(0, hp))
        if hp <= 0 then
            self:Remove()
        end
    end

    function ENT:HasDialog()
        return table.getn(self.NPCDialogs) > 0
    end

    function ENT:GetNPCDialogs()
        local dialogs = NPCDialogsGlobal[self:GetNWInt("NPCID")] or {}
        print("[DEBUG] Server: NPC Dialogs for NPC " .. self:GetNWInt("NPCID") .. ": " .. #dialogs)
        return dialogs
    end

    function ENT:GetMissionStartIDs()
        return self.MissionStartIDs
    end

    function ENT:GetMissionParticipations()
        return self.MissionParticipations
    end

    function ENT:GetVendorShopID()
        return self.GetVendorShopID
    end

    function ENT:GetStats()
        return self.NPCStats:GetStats(self)
    end 
end
]]

if CLIENT then
    ENT.RenderGroup = RENDERGROUP_OPAQUE

    --[[ net.Receive("SyncNPCDialogs", function()
        local npcID = net.ReadInt(32)
        local serializedDialogs = net.ReadTable()
        local dialogs = {}
        for index, serialized in pairs(serializedDialogs) do
            -- Find the NPC entity with this NPCID
            local npc
            for _, ent in ipairs(ents.GetAll()) do
                if ent:GetClass() == "npc_base" and ent:GetNWInt("NPCID") == npcID then
                    npc = ent
                    break
                end
            end
            if npc then
                dialogs[index] = NPCDialog:FromSerialized(npc, serialized)
            end
        end
        NPCDialogsGlobal[npcID] = dialogs
        print("[DEBUG] Client: Received SyncNPCDialogs for NPCID " .. npcID .. ": " .. #dialogs .. " dialogs")
    end) ]]

    function ENT:Initialize()
        self:SetupBones()
        self:SetRenderMode(RENDERMODE_NORMAL)
        print("[DEBUG] Client: NPC " .. self:EntIndex() .. " (ID: " .. self:GetNWInt("NPCID") .. ") initialized with model " .. (self:GetModel() or "nil"))
        self.NPCDialogs = {}
    end

    function ENT:Draw()
        self:DrawModel()
    end

    function ENT:GetNPCDialogs()
        --return self.NPCDialogs
        -- Reconstruct NPCDialog objects from networked metadata
        if not self.NPCDialogs or #self.NPCDialogs == 0 then
            local dialogCount = self:GetNWInt("DialogCount", 0)
            self.NPCDialogs = {}
            for i = 1, dialogCount do
                local dialogId = self:GetNWString("DialogID_" .. i, "")
                local dialogIndex = self:GetNWInt("DialogIndex_" .. i, 0)
                if dialogId ~= "" and dialogIndex > 0 then
                    self.NPCDialogs[i] = NPCDialog:New(self, dialogId, dialogIndex)
                end
            end
            print("[DEBUG] Client: Reconstructed " .. #self.NPCDialogs .. " dialogs for NPC " .. self:EntIndex())
        end
        return self.NPCDialogs
    end

    function ENT:GetMissionStartIDs()
        return self.MissionStartIDs
    end

    function ENT:GetMissionParticipations()
        return self.MissionParticipations
    end

    function ENT:GetVendorShopID()
        return self.VendorShopID
    end

    function ENT:GetStats()
        return self.NPCStats:GetStats(self)
    end
end

scripted_ents.Register(ENT, "npc_base")