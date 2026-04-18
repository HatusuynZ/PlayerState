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

## Defining Player State

All state variables are defined in `State.lua`. **This is where you add your own fields.**

Edit the `DefaultPlayerState` type and the `DEFAULT_PLAYER_STATE` table to match your game's data:

```lua
-- State.lua
export type DefaultPlayerState = {
    Coins: number,
    Level: number,
    Inventory: { [string]: any },
    IsReady: boolean,
    -- Add your own fields here
}

local DEFAULT_PLAYER_STATE: DefaultPlayerState = {
    Coins = 0,
    Level = 1,
    Inventory = {},
    IsReady = false,
    -- Initialize your own fields here
}
```

> Every player receives a **deep copy** of `DEFAULT_PLAYER_STATE` on join, so tables are never shared between players.

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
Fired just before a player's state is destroyed. Receives a **deep copy** of the state, allowing you to safely observe the player's last values without risk of the data being wiped mid-read.

```lua
PlayerState.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
    print(snapshot.State.Coins)  -- safe to read, this is a clone
    print(snapshot.State.Level)
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

**Updating a single value (Server)**
```lua
local state = PlayerState:GetState(player)
if state then
    PlayerState:ReplicateState(player, "Coins", state.Coins + 100)
end
```

**Updating multiple values at once (Server)**
```lua
PlayerState:ReplicateStateWithTable(player, {
    Coins = 500,
    Level = 10,
})
```

**Updating the HUD reactively (Client)**
```lua
local conn = PlayerState:GetStateChanged(game.Players.LocalPlayer, "Coins")
conn:Connect(function(newCoins)
    CoinsLabel.Text = tostring(newCoins)
end)
```

**Observing values when a player leaves (Server)**
```lua
PlayerState.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
    -- snapshot.State is a cloned table — safe to read even after the state is destroyed
    print(player.Name, "had", snapshot.State.Coins, "coins")
end)
```

---

## Notes

- `GetState` yields if the state isn't ready and returns `nil` after a 3-second timeout.
- `ReplicateStateWithTable` is preferred over multiple `ReplicateState` calls for batch updates.
- `OnStateCleanedSnapshot` gives you a **cloned snapshot** — the original state is already being destroyed when this fires, so always read from `snapshot.State`.
- To add new state fields, edit both the `DefaultPlayerState` type and the `DEFAULT_PLAYER_STATE` table in `State.lua`.
