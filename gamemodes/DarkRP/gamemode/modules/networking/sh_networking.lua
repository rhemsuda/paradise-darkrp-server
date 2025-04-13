print("[DEBUG] sh_networking.lua loaded")

Networking = Networking or {}

if SERVER then
    AddCSLuaFile()

    -- Register a net message
    function Networking:RegisterMessage(messageName)
        util.AddNetworkString(messageName)
        print("[DEBUG] Server: Registered net message " .. messageName)
    end

    -- Send a message to a client
    function Networking:SendToClient(messageName, caller, writeData)
        net.Start(messageName)
        writeData()
        net.Send(caller)
        print("[DEBUG] Server: Sent " .. messageName .. " to " .. caller:Nick())
    end

    -- Register a server-side receiver
    function Networking:RegisterReceiver(messageName, callback)
        net.Receive(messageName, function(len, ply)
            callback(ply)
        end)
    end
end

if CLIENT then
    -- Register a client-side receiver
    function Networking:RegisterReceiver(messageName, callback)
        net.Receive(messageName, function()
            callback()
        end)
    end

    -- Send a message to the server
    function Networking:SendToServer(messageName, writeData)
        net.Start(messageName)
        writeData()
        net.SendToServer()
        print("[DEBUG] Client: Sent " .. messageName .. " to server")
    end
end