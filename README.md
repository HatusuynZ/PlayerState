🎮 PlayerState
A lightweight, type-safe player state management module for Roblox, written in Luau strict mode. It handles state creation, reactive change detection, server → client replication, and automatic cleanup — all with a clean API and zero boilerplate.

✨ Features

Reactive state — metatables proxy all writes, firing listeners automatically without polling or manual wiring
Async-safe — built-in coroutine-based await: callers are queued and resumed when the state is ready, with a 3-second timeout fallback
Server → Client replication — sync individual keys or batch updates through dedicated RemoteEvents
Automatic cleanup — integrates with Soap (a Trove-like janitor) to destroy connections, instances, and threads on player leave
Snapshot on leave — fires OnStateCleanedSnapshot with a deep copy before cleanup, preventing race conditions
Idempotent creation — CreatePlayerState is safe to call multiple times; it returns the existing entry if one already exists
Late-join safe — on startup, the Server iterates existing players so the module works even when required after some players are already in the game
Fully typed — all public methods and exported types work with Luau's type checker and autocomplete


📁 Module Structure
PlayerState/
├── Client/
│   └── init.lua       # Client-side state module
├── Server/
│   └── init.lua       # Server-side state module
├── State.lua          # Default state definition & DeepCopy utility
├── Signal.lua         # RemoteEvents / BindableEvents setup
└── SoapV2.lua         # Janitor/cleanup utility (like Trove)

🔄 Architecture Overview
SERVER                                CLIENT
──────────────────────────────────────────────────────────
PlayerAdded                           PlayerAdded
  └─> CreatePlayerState()               └─> SetState()
        └─> StateMap[player] = entry          └─> awaits server sync

ReplicateState(player, key, value)    StatesLoaded:InvokeServer()
  └─> state[key] = value                └─> receives snapshot
  └─> FireAllClients(userId, key, val)        └─> SetState() for each player

PlayerRemoving                        PlayerRemoving
  └─> CleanPlayerState()                └─> CleanStates()
        └─> OnStateCleanedSnapshot            └─> OnStateCleanedSnapshot
        └─> Soap:Destroy()                    └─> Soap:Destroy()

🖥️ Server API
Require the server module from a Script inside ServerScriptService.
lualocal PlayerState = require(path.to.Server.PlayerState)

Server:GetState(player)
Returns the player's state table and Soap object. Yields if the state isn't ready yet (up to 3 seconds).
lualocal state, soap = PlayerState:GetState(player)
if state then
    print(state.Coins)
end

Server:GetReference(player)
Returns the full internal PlayerStateEntry (State + Soap). Useful for advanced use cases.
lualocal entry = PlayerState:GetReference(player)

Server:ReplicateState(player, key, value)
Updates a single key in the player's state on the server and replicates it to all clients via FireAllClients.
luaPlayerState:ReplicateState(player, "Coins", 500)

Server:ReplicateStateWithTable(player, updates)
Applies and replicates multiple key-value pairs in a single remote call. More efficient than calling ReplicateState in a loop.
luaPlayerState:ReplicateStateWithTable(player, {
    Coins = 500,
    Level = 10,
    LastSeen = os.time(),
})

Server:CreatePlayerState(player)
Creates a new state entry for the player using the default values from State.lua. If an entry already exists, it returns the existing one (idempotent).
lualocal entry = PlayerState:CreatePlayerState(player)

Server:CleanPlayerState(player)
Destroys all state data for a player. Before destroying, fires OnStateCleanedSnapshot with a deep copy of the state.
luaPlayerState:CleanPlayerState(player)

Server.OnStateCleanedSnapshot
A BindableEvent fired just before a player's state is destroyed. Receives (player, stateCopy).
luaPlayerState.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
    -- Save snapshot.State to DataStore here
    print(player.Name, "left with", snapshot.State.Coins, "coins")
end)

💻 Client API
Require the client module from a LocalScript or ModuleScript inside StarterPlayerScripts.
lualocal PlayerState = require(path.to.Client.PlayerState)

Client:GetState(player)
Returns the player's state table and Soap object. Yields if the state isn't ready (up to 3 seconds).
lualocal state, soap = PlayerState:GetState(game.Players.LocalPlayer)
if state then
    print(state.Coins)
end

Client:GetReference(player)
Returns the full internal PlayerStateEntry. Useful when you need access to the Soap janitor directly.
lualocal entry = PlayerState:GetReference(player)

Client:GetStateChanged(player, key)
Returns a StateChangedConnection for a specific key. Fires whenever that key is updated on the client — either by local logic or by a server replication event.
lualocal conn = PlayerState:GetStateChanged(player, "Coins")

-- Listen indefinitely
conn:Connect(function(newValue)
    print("Coins changed to:", newValue)
end)

-- Listen only once, then auto-disconnect
conn:Once(function(newValue)
    print("First coin change:", newValue)
end)

-- Stop listening
conn:Disconnect(myCallback)

Client:FireStateChanged(player, key, value)
Manually fires all listeners for a given key. Called internally by the state proxy on every write, but can also be triggered externally.
luaPlayerState:FireStateChanged(player, "Health", 75)

Client.Signal.OnStateCleanedSnapshot
A BindableEvent fired just before the client-side state is destroyed. Useful for cleaning up UI or local saves.
luaPlayerState.Signal.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
    print(player.Name, "left. Last coins:", snapshot.State.Coins)
end)

💡 Usage Examples
Server — granting coins on purchase
lua-- ServerScript
local PlayerState = require(path.to.Server.PlayerState)

game:GetService("MarketplaceService").ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

    local state = PlayerState:GetState(player)
    if state then
        PlayerState:ReplicateState(player, "Coins", state.Coins + 100)
    end

    return Enum.ProductPurchaseDecision.PurchaseGranted
end
Client — updating the HUD reactively
lua-- LocalScript
local PlayerState = require(path.to.Client.PlayerState)
local localPlayer = game.Players.LocalPlayer

-- Get current value
local state = PlayerState:GetState(localPlayer)
if state then
    CoinsLabel.Text = tostring(state.Coins)
end

-- React to future changes automatically
local conn = PlayerState:GetStateChanged(localPlayer, "Coins")
conn:Connect(function(newCoins)
    CoinsLabel.Text = tostring(newCoins)
end)
Server — saving data on leave
lua-- ServerScript
local PlayerState = require(path.to.Server.PlayerState)

PlayerState.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
    local data = snapshot.State
    -- Save data.Coins, data.Level, etc. to DataStore
end)

⏳ Async Await Behavior
Both GetState and GetReference (on server and client) use a coroutine-based await pattern. If the state doesn't exist yet when you call them, they yield the current thread and resume it as soon as the state is created. If the state is not ready within 3 seconds, a warning is printed and nil is returned — no infinite loops or busy waits.
lua-- Safe to call immediately, even before the state is created
task.spawn(function()
    local state = PlayerState:GetState(player) -- yields if needed
    print(state and state.Coins or "State unavailable")
end)

🔁 Replication Events
EventDirectionPurposeReplicateEventServer → All ClientsReplicates a single key, value pairReplicateTableEventServer → All ClientsReplicates a batch of { key = value } updatesStatesLoadedClient → Server (Invoke)Client requests a full snapshot of all active states on join
