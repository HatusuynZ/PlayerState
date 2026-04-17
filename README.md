## Usage Examples

### Getting the local player's state

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.Services.PlayerState)
local LocalPlayer = Players.LocalPlayer

task.spawn(function()
	local state, soap = PlayerState:GetState(LocalPlayer)
	if not state then
		warn("Failed to get local player state.")
		return
	end

	print("Local player state loaded.")
	print("Room:", state.Room)
	print("ToyInUse:", state.ToyInUse)
	print("RateLimit:", state.RateLimit)

	-- `soap` can be used to store cleanup objects if needed.
	print("Soap ready:", soap)
end)
```

---

### Getting another player's state

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.Services.PlayerState)

local function printPlayerRoom(player: Player)
	task.spawn(function()
		local state = PlayerState:GetState(player)
		if not state then
			warn(`State not available for {player.Name}`)
			return
		end

		print(`{player.Name} is in room:`, state.Room)
	end)
end

for _, player in Players:GetPlayers() do
	printPlayerRoom(player)
end

Players.PlayerAdded:Connect(printPlayerRoom)
```

---

### Listening to a specific state change

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.Services.PlayerState)
local LocalPlayer = Players.LocalPlayer

PlayerState
	:GetStateChanged(LocalPlayer, "ToyInUse")
	:Connect(function(newValue)
		print("Toy changed to:", newValue)
	end)
```

---

### Listening to another player's state change

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.Services.PlayerState)

local function watchPlayer(player: Player)
	PlayerState
		:GetStateChanged(player, "Room")
		:Connect(function(newValue)
			print(`{player.Name} changed room to:`, newValue)
		end)
end

for _, player in Players:GetPlayers() do
	watchPlayer(player)
end

Players.PlayerAdded:Connect(watchPlayer)
```

---

### Running code only once when a state changes

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.Services.PlayerState)
local LocalPlayer = Players.LocalPlayer

PlayerState
	:GetStateChanged(LocalPlayer, "DualEmoteName")
	:Once(function(newValue)
		print("Dual emote set for the first time:", newValue)
	end)
```

---

### Accessing the full internal reference

```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.Services.PlayerState)
local LocalPlayer = Players.LocalPlayer

task.spawn(function()
	local reference = PlayerState:GetReference(LocalPlayer)
	if not reference then
		warn("Reference not available.")
		return
	end

	print("State table:", reference.State)
	print("Soap object:", reference.Soap)
end)
```

---

### Reacting when a player's state is cleaned

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.Services.PlayerState)

PlayerState.Signal.OnStateCleanedSnapshot.Event:Connect(function(player, snapshot)
	print(`State cleaned for {player.Name}`)
	print("Last known state snapshot:", snapshot)
end)
```

---

### Manual synchronization example

> In most cases you do not need this because the module already starts and synchronizes by itself.

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerState = require(ReplicatedStorage.Services.PlayerState)

task.spawn(function()
	PlayerState:SynchronizeFromServer()
	print("Manual synchronization finished.")
end)
```

---

## Notes

- `GetState()` may yield while the module waits for the player state to become available.
- `GetStateChanged(player, key)` works for both the local player and other players.
- The state object uses a proxy internally, so assigning a new value to a state key triggers registered listeners automatically.
- The module starts automatically at the bottom of the file, so you do not need to call `Start()` manually in normal usage.
