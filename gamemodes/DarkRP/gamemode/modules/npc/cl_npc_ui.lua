if CLIENT then
    print("[DEBUG] cl_npc_ui.lua loaded")

    NPCDialogUI = NPCDialogUI or {}
    NPCDialogUI.Frame = nil
    NPCDialogUI.CurrentNPC = nil
    NPCDialogUI.CurrentDialogIndex = nil
    NPCDialogUI.CurrentNodeIndex = nil

    function NPCDialogUI:Open(npc, dialogId, dialogIndex, nodeIndex)
        print("[DEBUG] Client: Opening dialog, self.Frame is " .. tostring(IsValid(self.Frame)))
        if not IsValid(self.Frame) then
            self.Frame = vgui.Create("DFrame")
            if not IsValid(self.Frame) then
                print("[ERROR] Client: Failed to create DFrame for NPC " .. npc:EntIndex())
                return
            end
            self.Frame:SetSize(400, 300)
            self.Frame:Center()
            self.Frame:SetTitle("NPC Dialog")
            self.Frame:MakePopup()
            self.Frame.OnClose = function()
                print("[DEBUG] Client: Frame closed for NPC " .. (self.CurrentNPC and self.CurrentNPC:EntIndex() or "nil"))
                self.Frame = nil
                self.CurrentNPC = nil
                self.CurrentDialogIndex = nil
                self.CurrentNodeIndex = nil
            end
        else
            print("[DEBUG] Client: Reusing existing frame, setting title first")
            self.Frame:SetTitle("NPC: " .. npc:GetNWString("ModelName", "Unknown")) -- Move here
            if not IsValid(self.Frame) then
                print("[ERROR] Client: self.Frame is invalid after SetTitle for NPC " .. npc:EntIndex())
                return
            end
            self.Frame:SetVisible(true)
            self.Frame:MakePopup()
        end
    
        self.CurrentNPC = npc
        self.CurrentDialogIndex = dialogIndex
        self.CurrentNodeIndex = nodeIndex
    
        if not IsValid(self.Frame) then
            print("[ERROR] Client: self.Frame is invalid after state update for NPC " .. npc:EntIndex())
            return
        end
    
        -- No need to set title again if already done
        if not IsValid(self.Frame) then
            print("[ERROR] Client: self.Frame is invalid after state update for NPC " .. npc:EntIndex())
            return
        end
    
        local children = self.Frame:GetChildren()
        if children then
            for _, child in ipairs(children) do
                if IsValid(child) and child != self.Frame.CloseButton then
                    child:Remove()
                end
            end
        end
        if not IsValid(self.Frame) then
            print("[ERROR] Client: self.Frame is invalid after removing children for NPC " .. npc:EntIndex())
            return
        end
    
        local dialogs = npc:GetNPCDialogs()
        print("[DEBUG] Client: Dialogs= " .. #dialogs)
        local dialog = dialogs[dialogIndex]
        if not dialog then
            print("[DEBUG] Client: Dialog " .. dialogIndex .. " not found for NPC " .. npc:EntIndex())
            self.Frame:Close()
            return
        end
    
        if dialog.DialogID != dialogId then
            print("[DEBUG] Client: Dialog ID mismatch for NPC " .. npc:EntIndex() .. " (Expected: " .. dialogId .. ", Got: " .. dialog.DialogID .. ")")
            self.Frame:Close()
            return
        end
    
        local dialogTree = dialog:GetDialogTree()
        local node = dialog:GetNode(nodeIndex)
        local responses = dialog:GetResponses(nodeIndex)
    
        timer.Simple(0.1, function() -- Increased to 0.1
            if not IsValid(self.Frame) then
                print("[ERROR] Client: self.Frame is invalid during child creation for NPC " .. npc:EntIndex())
                return
            end
    
            local textLabel = vgui.Create("DLabel", self.Frame)
            if not IsValid(textLabel) then
                print("[ERROR] Client: Failed to create DLabel for NPC " .. npc:EntIndex())
                return
            end
            textLabel:SetPos(10, 30)
            if not IsValid(textLabel) then
                print("[ERROR] Client: textLabel is invalid after SetPos for NPC " .. npc:EntIndex())
                return
            end
            textLabel:SetSize(380, 50)
            textLabel:SetText(node.Text)
            textLabel:SetWrap(true)
    
            local responseList = vgui.Create("DListView", self.Frame)
            if not IsValid(responseList) then
                print("[ERROR] Client: Failed to create DListView for NPC " .. npc:EntIndex())
                return
            end
            responseList:SetPos(10, 90)
            if not IsValid(responseList) then
                print("[ERROR] Client: responseList is invalid after SetPos for NPC " .. npc:EntIndex())
                return
            end
            responseList:SetSize(380, 160)
            responseList:AddColumn("Response")
    
            for i, response in ipairs(responses) do
                local line = responseList:AddLine(response.Text)
                line.responseData = response
            end
    
            local lastClick = 0
            responseList.OnRowSelected = function(self, rowIndex, row)
                local currentTime = CurTime()
                if currentTime - lastClick < 0.5 then return end
                lastClick = currentTime
    
                local response = row.responseData
                if response.NextNode then
                    if not Networking then
                        print("[ERROR] Networking module not loaded in cl_npc_ui.lua")
                        return
                    end
                    Networking:SendToServer("OpenNPCDialog", function()
                        net.WriteEntity(npc)
                        net.WriteString(dialogId)
                        net.WriteInt(dialogIndex, 32)
                        net.WriteInt(response.NextNode, 32)
                    end)
                else
                    self.Frame:Close()
                end
                if response.Action then
                    response.Action(npc)
                end
            end
    
            print("[DEBUG] Client: Updated dialog UI for NPC " .. npc:EntIndex() .. " (DialogID: " .. dialogId .. ", Dialog: " .. dialogIndex .. ", Node: " .. nodeIndex .. ")")
        end)
    end

    Networking:RegisterReceiver("OpenNPCDialog", function()
        local npc = net.ReadEntity()
        if not IsValid(npc) then return end
        local dialogId = net.ReadString()
        local dialogIndex = net.ReadInt(32)
        local nodeIndex = net.ReadInt(32)
        print("[DEBUG] Client: OpenNPCDialog received for NPCID " .. npc:GetNWInt("NPCID") .. " (DialogID: " .. dialogId .. ", Dialog: " .. dialogIndex .. ", Node: " .. nodeIndex .. ")")

        NPCDialogUI:Open(npc, dialogId, dialogIndex, nodeIndex)
    end)
end





--[[ if CLIENT then
    print("[DEBUG] cl_npc_ui.lua loaded")

    net.Receive("OpenNPCDialog", function()
        
        local npc = net.ReadEntity()
        print("[DEBUG] Client: OpenNPCDialog received for " .. npc.ID)
        if not IsValid(npc) then return end
        local dialogIndex = net.ReadInt(32)
        local nodeIndex = net.ReadInt(32)
        print("[DEBUG] Client: Loading: " .. dialogIndex .. " node: " .. nodeIndex)
        

        local dialogs = npc:GetNPCDialogs()
        local dialog = dialogs[dialogIndex]
        if not dialog then
            print("[DEBUG] Client: Dialog " .. dialogIndex .. " not found for NPC " .. npc:EntIndex())
            return
        end

        local dialogTree = dialog:GetDialogTree()
        local node = dialog:GetNode(nodeIndex)
        local responses = dialog:GetResponses(nodeIndex)

        -- Create the dialog UI
        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 300)
        frame:Center()
        frame:SetTitle("NPC: " .. npc:GetNWString("ModelName", "Unknown"))
        frame:MakePopup()

        local textLabel = vgui.Create("DLabel", frame)
        textLabel:SetPos(10, 30)
        textLabel:SetSize(380, 50)
        textLabel:SetText(node.Text)
        textLabel:SetWrap(true)

        local responseList = vgui.Create("DListView", frame)
        responseList:SetPos(10, 90)
        responseList:SetSize(380, 160)
        responseList:AddColumn("Response")

        for i, response in ipairs(responses) do
            local line = responseList:AddLine(response.Text)
            line.responseData = response
        end

        responseList.OnRowSelected = function(self, rowIndex, row)
            local response = row.responseData
            if response.NextNode then
                -- Send request for next dialog node
                net.Start("OpenNPCDialog")
                print("[DEBUG] Client: Open next dialog node " .. dialogIndex .. " next node: " .. response.NextNode)
                net.WriteEntity(npc)
                net.WriteInt(dialogIndex, 32)
                net.WriteInt(response.NextNode, 32)
                net.SendToServer()                
            end

            frame:Close()

            if response.Action then
                response.Action(npc)
            end
        end
    end)
end ]]