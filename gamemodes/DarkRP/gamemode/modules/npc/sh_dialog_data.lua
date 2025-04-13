print("[DEBUG] sh_dialog_data.lua loaded")

-- Shared table of dialog trees, accessible on both server and client
DialogTrees = DialogTrees or {}

-- Default dialog tree for testing
DialogTrees["default"] = {
    [1] = {
        Text = "Hello, I’m an NPC. What do you want?",
        Responses = {
            { Text = "Nothing", NextNode = nil, Action = nil },
            { Text = "Tell me more", NextNode = 2, Action = nil }
        }
    },
    [2] = {
        Text = "I’m just a test NPC. Not much to say!",
        Responses = {
            { Text = "Goodbye", NextNode = nil, Action = nil }
        }
    }
}