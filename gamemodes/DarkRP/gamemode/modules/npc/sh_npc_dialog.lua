print("[DEBUG] sh_npc_dialog.lua loaded")

NPCDialog = NPCDialog or {}

if SERVER then
    Networking:RegisterMessage("OpenNPCDialog")
end

function NPCDialog:New(npc, dialogId, dialogIndex)
    local dialog = {
        NPC = npc,
        NPCID = npc:GetNWInt("NPCID"),
        DialogID = dialogId,
        DialogIndex = dialogIndex
    }

    if not DialogTrees[dialogId] then
        error("Dialog tree " .. tostring(dialogId) .. " not found")
    end

    setmetatable(dialog, { __index = NPCDialog })
    return dialog
end

--[[ function NPCDialog:FromSerialized(npc, serialized)
    local dialog = {
        NPCID = npc:GetNWInt("NPCID"),
        Dialog = serialized.Dialog or {}
    }

    if table.IsEmpty(dialog.Dialog) then
        dialog.Dialog = {
            [1] = {
                Text = "I have nothing to say.",
                Responses = {}
            }
        }
    end

    setmetatable(dialog, { __index = NPCDialog })
    return dialog
end
 ]]
function NPCDialog:GetDialogTree()
    return DialogTrees[self.DialogID] or {}
end

function NPCDialog:GetNode(nodeIndex)
    local dialogTree = self:GetDialogTree()
    return dialogTree[nodeIndex] or { Text = "Dialog not found.", Responses = {} }
end

function NPCDialog:GetResponses(nodeIndex)
    local node = self:GetNode(nodeIndex)
    return node.Responses or {}
end


if SERVER then
    function NPCDialog:Open(caller, nodeIndex)
        local node = self:GetNode(nodeIndex)
        if not node or not node.Text then
            print("[DEBUG] Server: Node " .. nodeIndex .. " not found in dialog " .. self.DialogIndex .. " for NPC " .. self.NPC:EntIndex())
            return false
        end

        Networking:SendToClient("OpenNPCDialog", caller, function()
            net.WriteEntity(self.NPC)
            net.WriteString(self.DialogID)
            net.WriteInt(self.DialogIndex, 32)
            net.WriteInt(nodeIndex, 32)
        end)
        return true
    end

    -- Register the server-side receiver for OpenNPCDialog
    Networking:RegisterReceiver("OpenNPCDialog", function(ply)
        local npc = net.ReadEntity()
        if not IsValid(npc) or npc:GetClass() != "npc_base" then return end
        local dialogId = net.ReadString()
        local dialogIndex = net.ReadInt(32)
        local nodeIndex = net.ReadInt(32)
        print("[DEBUG] Server: Received OpenNPCDialog for NPC " .. npc:EntIndex() .. " (ID: " .. npc:GetNWInt("NPCID") .. ") from " .. ply:Nick() .. " - DialogID: " .. dialogId .. ", Dialog: " .. dialogIndex .. ", Node: " .. nodeIndex)

        local dialogs = npc:GetNPCDialogs()
        local dialog = dialogs[dialogIndex]
        if not dialog or dialog.DialogID != dialogId then
            print("[DEBUG] Server: Dialog " .. dialogIndex .. " (ID: " .. dialogId .. ") not found for NPC " .. npc:EntIndex())
            return
        end

        dialog:Open(ply, nodeIndex)
    end)
end