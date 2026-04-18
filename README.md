# PlayerState

A lightweight, type-safe player state management module for Roblox. Handles state creation, reactive change detection, server → client replication, and automatic cleanup.

---

## Installation

Place the `PlayerState` folder inside `ReplicatedStorage`. Then require the appropriate module:

```lua
-- Server (inside a Script in ServerScriptService)
local PlayerState = require(ReplicatedStorage.Services.PlayerState.Server)

-- Client (inside a LocalScript or ModuleScript)
local PlayerState = require(ReplicatedStorage.Services.PlayerState.Client)
```

---

## Server API

### `ReplicateState(player, key, value)`
Updates a key in the player's state and replicates it to all clients.

```lua
PlayerState:ReplicateState(player, "Coins", 500)
```

### `ReplicateStateWithTable(player, updates)`
Updates and replicates multiple keys in a single call.

```lua
PlayerState:ReplicateStateWithTable(player, {
    Coins = 500,
    Level = 10,
})
```

### `GetState(player)`
Returns the player's state table and Soap janitor. Yields up to 3 seconds if the state isn't ready yet.

```lua
local state, soap = PlayerState:GetState(player)
```

### `OnStateCleanedSnapshot`
Fired just before a player's state is destroyed. Use this to save data to DataStore.

```lua
PlayerState.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
    -- save snapshot.State to DataStore
end)
```

---

## Client API

### `GetState(player)`
Returns the player's state table. Yields up to 3 seconds if the state isn't ready yet.

```lua
local state = PlayerState:GetState(game.Players.LocalPlayer)
```

### `GetStateChanged(player, key)`
Listens for changes on a specific state key.

```lua
local conn = PlayerState:GetStateChanged(player, "Coins")

conn:Connect(function(newValue)
    print("Coins:", newValue)
end)

-- Fires only once
conn:Once(function(newValue)
    print("First change:", newValue)
end)

-- Stop listening
conn:Disconnect(myCallback)
```

---

## Examples

**Granting coins on purchase (Server)**
```lua
local state = PlayerState:GetState(player)
if state then
    PlayerState:ReplicateState(player, "Coins", state.Coins + 100)
end
```

**Updating HUD reactively (Client)**
```lua
local conn = PlayerState:GetStateChanged(game.Players.LocalPlayer, "Coins")
conn:Connect(function(newCoins)
    CoinsLabel.Text = tostring(newCoins)
end)
```

**Saving data on leave (Server)**
```lua
PlayerState.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
    DataStore:SetAsync(player.UserId, snapshot.State)
end)
```

---

## Notes

- `GetState` and `GetReference` are async — they yield if the state isn't ready and return `nil` after a 3-second timeout.
- `ReplicateStateWithTable` is preferred over multiple `ReplicateState` calls for batch updates.
- `OnStateCleanedSnapshot` receives a **deep copy** of the state, so it's safe to read after the player leaves.
