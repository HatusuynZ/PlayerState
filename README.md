 # PlayerState

A lightweight, type-safe player state management module for Roblox. Handles state creation, reactive change detection, server → client replication, and automatic cleanup.

---

## Installation

Place the `PlayerState` folder inside `ReplicatedStorage`. Then require the appropriate module:

```lua
-- Server (inside a Script in ServerScriptService)
local PlayerState = require(ServerScriptService.Server)

-- Client (inside a LocalScript or ModuleScript)
local PlayerState = require(ReplicatedStorage.Client)
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
local CoinsChanged = PlayerState:GetStateChanged(player, "Coins")

CoinsChanged:Connect(function(newValue)
    print("Coins:", newValue)
end)

-- Fires only once
CoinsChanged:Once(function(newValue)
    print("First change:", newValue)
end)

-- Stop listening
CoinsChanged:Disconnect(myCallback)
```

---

## Real Usage Example

This example simulates a coin collection system where the server grants coins every few seconds and the client updates the HUD reactively.

**Server**
```lua
-- ServerScript
local Players = game:GetService("Players")
local PlayerState = require(ServerScriptService.PlayerState)

Players.PlayerAdded:Connect(function(player)
    local state, soap = PlayerState:GetState(player)
    if not state then return end

    -- Grant 10 coins every 5 seconds.
    -- The loop thread is registered in Soap so it's cancelled automatically when the player leaves.
    soap:Add(task.spawn(function()
        while true do
            task.wait(5)

            local currentState = PlayerState:GetState(player)
            if not currentState then break end

            PlayerState:ReplicateStateWithTable(player, {
                Coins = currentState.Coins + 10,
                Level = math.floor(currentState.Coins / 100) + 1,
            })
        end
    end))

    -- Register a part created for this player so it's destroyed on leave.
    local part = Instance.new("Part")
    part.Parent = workspace
    soap:Add(part)
end)

-- Observe the player's final state before cleanup.
PlayerState.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
    print(player.Name, "left with", snapshot.State.Coins, "coins at level", snapshot.State.Level)
end)
```

**Client**
```lua
-- LocalScript
local Players = game:GetService("Players")
local PlayerState = require(ReplicatedStorage.PlayerState)

local localPlayer = Players.LocalPlayer
local PlayerGui = localPlayer.PlayerGui

local CoinsLabel = PlayerGui.HUD.CoinsLabel
local LevelLabel = PlayerGui.HUD.LevelLabel

-- Set initial values once the state is ready.
local state = PlayerState:GetState(localPlayer)
if state then
    CoinsLabel.Text = tostring(state.Coins)
    LevelLabel.Text = "Level " .. state.Level
end

-- React to every update pushed by the server.
local CoinsChanged = PlayerState:GetStateChanged(localPlayer, "Coins")
CoinsChanged:Connect(function(newCoins)
    CoinsLabel.Text = tostring(newCoins)
end)

local LevelChanged = PlayerState:GetStateChanged(localPlayer, "Level")
LevelChanged:Connect(function(newLevel)
    LevelLabel.Text = "Level " .. newLevel
end)
```

---

## Soap

`Soap` é um janitor embutido no módulo — cada player recebe um ao ter seu estado criado. Ele serve para registrar objetos que devem ser limpos automaticamente quando o player sair.

Você o recebe pelo `GetState`:

```lua
local state, soap = PlayerState:GetState(player)
```

### `soap:Add(...)`
Registra um ou mais objetos para serem limpos depois.

```lua
soap:Add(
    workspace.Part,                           -- Instance        → :Destroy()
    humanoid.Running:Connect(function() end), -- RBXScriptConnection → :Disconnect()
    coroutine.running(),                      -- thread          → task.cancel()
    tween,                                    -- Tween           → :Cancel()
    function() print("cleaned") end           -- function        → chamada diretamente
)
```

### `soap:Remove(...)`
Remove um objeto do Soap sem limpá-lo.

```lua
soap:Remove(workspace.Part)
```

### `soap:Cleanup()`
Limpa todos os objetos registrados, mas mantém o Soap utilizável.

```lua
soap:Cleanup()
```

### `soap:Destroy()`
Limpa tudo e descarta o Soap por completo. Chamado automaticamente quando o player sai.

> Você não precisa chamar `Destroy` manualmente — o módulo já faz isso no `PlayerRemoving`.

---

## Notes

- `GetState` yields if the state isn't ready and returns `nil` after a 3-second timeout.
- `ReplicateStateWithTable` is preferred over multiple `ReplicateState` calls for batch updates.
- `OnStateCleanedSnapshot` gives you a **cloned snapshot** — the original state is already being destroyed when this fires, so always read from `snapshot.State`.
- To add new state fields, edit both the `DefaultPlayerState` type and the `DEFAULT_PLAYER_STATE` table in `State.lua`.
