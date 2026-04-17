--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientPlayerState = ReplicatedStorage.Services.PlayerState

local Soap = require(ClientPlayerState.SoapV2)
local DefaultValues = require(ClientPlayerState.State)
local SignalModule = require(script.Signal)

-- TYPES

type DefaultPlayerState = DefaultValues.DefaultPlayerState
type SoapObject = typeof(Soap.New())

type PlayerStateEntry = {
	State: DefaultPlayerState,
	Soap: SoapObject,
}

type StateMap = { [Player]: PlayerStateEntry }
type PendingCallback = (entry: PlayerStateEntry?) -> ()
type PendingMap = { [Player]: { PendingCallback } }

export type ServerStateModule = {
	GetReference: (self: ServerStateModule, player: Player) -> PlayerStateEntry?,
	GetState: (self: ServerStateModule, player: Player) -> (DefaultPlayerState?, SoapObject?),
	ReplicateState: <T>(self: ServerStateModule, player: Player, key: string, value: T) -> (),
	ReplicateStateWithTable: (self: ServerStateModule, player: Player, updates: { [string]: any }) -> (),
	CreatePlayerState: (self: ServerStateModule, player: Player) -> PlayerStateEntry,
	CleanPlayerState: (self: ServerStateModule, player: Player) -> (),
	Start: (self: ServerStateModule) -> (),
	OnStateCleanedSnapshot: BindableEvent,
}

-- INTERNAL STATE

local Signal = SignalModule.New()

local StateMap: StateMap = {}
local PendingMap: PendingMap = {}

local Module = {} :: ServerStateModule
Module.OnStateCleanedSnapshot = Signal.OnStateCleanedSnapshot

-- UTILS

--[[
	Resolves every coroutine waiting for a player's state.
	If the state failed to exist or was cleaned before creation,
	the callbacks receive nil.
]]
local function notifyPending(player: Player, entry: PlayerStateEntry?)
	local callbacks = PendingMap[player]
	if not callbacks then
		return
	end

	PendingMap[player] = nil

	for _, callback in callbacks do
		task.spawn(callback, entry)
	end
end

--[[
	Removes a single pending callback from the waiting list.
	This is mainly used by the timeout path, so the callback
	does not stay referenced longer than needed.
]]
local function cleanupPendingCallback(player: Player, pendingCallback: PendingCallback)
	local callbacks = PendingMap[player]
	if not callbacks then
		return
	end

	local index = table.find(callbacks, pendingCallback)
	if index then
		table.remove(callbacks, index)
	end

	if #callbacks == 0 then
		PendingMap[player] = nil
	end
end

--[[
	Waits for a player's state to exist.

	This is coroutine-based on purpose so the caller can yield
	without running a polling loop. If the player leaves before
	the state exists, or creation takes too long, nil is returned.
]]
local function awaitPlayerState(player: Player): PlayerStateEntry?
	assert(player and player:IsA("Player"), "[StateServer] awaitPlayerState: invalid Player.")

	local existing = StateMap[player]
	if existing then
		return existing
	end

	if not player:IsDescendantOf(Players) then
		return nil
	end

	local thread = coroutine.running()
	assert(thread, "[StateServer] awaitPlayerState must run inside a coroutine.")

	if not PendingMap[player] then
		PendingMap[player] = {}
	end


	--[[ Instead of using a while true loop with coroutine to manage threads,
	-- we use task.delay to handle the wait time. This way, if the server
	-- does not respond within 3 seconds, the state is cleaned up and the player is notified.
     ]]

	local resolved = false
	local delayThread: thread?
	local pendingCallback: PendingCallback

	pendingCallback = function(entry: PlayerStateEntry?)
		if resolved then
			return
		end

		if delayThread then
			task.cancel(delayThread)
			delayThread = nil
		end

		resolved = true
		task.spawn(thread, entry)
	end

	table.insert(PendingMap[player], pendingCallback)

	delayThread = task.delay(3, function()
		if resolved then
			return
		end

		resolved = true
		cleanupPendingCallback(player, pendingCallback)
		task.spawn(thread, nil)
	end)

	return coroutine.yield() :: PlayerStateEntry?
end

-- PUBLIC API

--[[
	Returns the full entry stored for a player.
	This includes both the replicated state table and the cleanup container.
]]
function Module:GetReference(player: Player): PlayerStateEntry?
	assert(
		player and typeof(player) == "Instance" and player:IsA("Player"),
		"[StateServer] GetReference: expected Player instance."
	)

	return awaitPlayerState(player)
end

--[[
	Returns the player's state table and its Soap object.
	If the state is unavailable, both return values are nil.
]]
function Module:GetState(player: Player): (DefaultPlayerState?, SoapObject?)
	assert(
		player and typeof(player) == "Instance" and player:IsA("Player"),
		"[StateServer] GetState: expected Player instance."
	)

	local entry = self:GetReference(player)
	if not entry then
		return nil, nil
	end

	return entry.State, entry.Soap
end

--[[
	Updates a single key in the player's state and replicates it to clients.
	If the state no longer exists, the operation is ignored safely.
]]
function Module:ReplicateState<T>(player: Player, key: string, value: T)
	assert(
		player and typeof(player) == "Instance" and player:IsA("Player"),
		"[StateServer] ReplicateState: expected Player instance."
	)

	assert(type(key) == "string" and key ~= "", "[StateServer] ReplicateState: key must be a non-empty string.")

	local state = self:GetState(player)
	if not state then
		return
	end

	state[key] = value
	Signal.ReplicateEvent:FireAllClients(player.UserId, key, value)
end

--[[
	Applies a batch of changes to the player's state and replicates
	the whole update payload in a single remote call.
]]
function Module:ReplicateStateWithTable(player: Player, updates: { [string]: any })
	assert(
		player and typeof(player) == "Instance" and player:IsA("Player"),
		"[StateServer] ReplicateStateWithTable: expected Player instance."
	)

	assert(type(updates) == "table", "[StateServer] ReplicateStateWithTable: updates must be a table.")

	local state = self:GetState(player)
	if not state then
		return
	end

	for key, value in updates do
		state[key] = value
	end

	Signal.ReplicateTableEvent:FireAllClients(player.UserId, updates)
end

--[[
	Creates the server-side state entry for a player.

	If the state already exists, the current entry is returned.
	This keeps the function idempotent during startup or reconnection flows.
]]
function Module:CreatePlayerState(player: Player): PlayerStateEntry
	assert(
		player and typeof(player) == "Instance" and player:IsA("Player"),
		"[StateServer] CreatePlayerState: expected Player instance."
	)

	local existing = StateMap[player]
	if existing then
		return existing
	end

	local entry: PlayerStateEntry = {
		State = DefaultValues:CreateDefaultState({}),
		Soap = Soap.New(),
	}

	StateMap[player] = entry
	notifyPending(player, entry)

	return entry
end

--[[
	Cleans the player's state entry and fires a snapshot before destruction.
	The snapshot is deep-copied so listeners can inspect old data safely.
]]
function Module:CleanPlayerState(player: Player)
	assert(
		player and typeof(player) == "Instance" and player:IsA("Player"),
		"[StateServer] CleanPlayerState: expected Player instance."
	)

	local entry = StateMap[player]
	if not entry then
		notifyPending(player, nil)
		return
	end

	local entryCopy = DefaultValues:DeepCopy(entry)
	self.OnStateCleanedSnapshot:Fire(player, entryCopy)

	setmetatable(entry.State, nil)
	entry.Soap:Destroy()

	StateMap[player] = nil
	notifyPending(player, nil)
end

--[[
	Builds a snapshot of every loaded state currently stored on the server.
	Only players with a valid entry are included.
]]
local function getStatesLoaded(): { [number]: DefaultPlayerState }
	local snapshot: { [number]: DefaultPlayerState } = {}

	for _, player in Players:GetPlayers() do
		local entry = StateMap[player]
		if entry then
			snapshot[player.UserId] = entry.State
		end
	end

	return snapshot
end

-- INITIALIZATION

--[[
	Wires remote access and player lifecycle hooks.

	Existing players are initialized as well so the module can be required
	after some users are already in the server.
]]
function Module:Start()
	Signal.StatesLoaded.OnServerInvoke = function(): { [number]: DefaultPlayerState }
		return getStatesLoaded()
	end

	Players.PlayerAdded:Connect(function(player: Player)
		self:CreatePlayerState(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:CleanPlayerState(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(self.CreatePlayerState, self, player)
	end
end

Module:Start()

return Module
