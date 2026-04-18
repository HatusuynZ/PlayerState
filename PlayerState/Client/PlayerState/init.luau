--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Soap = require(script.SoapV2)
local DefaultValues = require(script.State)
local Signal = require(script.Signal)

type DefaultPlayerState = DefaultValues.DefaultPlayerState
type SoapObject = typeof(Soap.New())

type PlayerStateEntry = {
	State: DefaultPlayerState,
	Soap: SoapObject,
}

type StateMap = { [Player]: PlayerStateEntry }
type PendingMap = { [Player]: { (entry: PlayerStateEntry?) -> () } }

export type StateCallback<T> = (newValue: T) -> ()

export type StateChangedConnection<T> = {
	KeyReference: string,
	Connect: (self: StateChangedConnection<T>, callback: StateCallback<T>) -> (),
	Disconnect: (self: StateChangedConnection<T>, callback: StateCallback<T>) -> (),
	Once: (self: StateChangedConnection<T>, callback: StateCallback<T>) -> (),
}

export type ClientStateModule = {
	GetState: (self: ClientStateModule, player: Player) -> (DefaultPlayerState?, SoapObject?),
	GetReference: (self: ClientStateModule, player: Player) -> PlayerStateEntry?,
	GetStateChanged: <T>(self: ClientStateModule, player: Player, key: string) -> StateChangedConnection<T>,
	FireStateChanged: <T>(self: ClientStateModule, player: Player, key: string, value: T) -> (),
	SetState: (self: ClientStateModule, player: Player, cache: DefaultPlayerState?) -> PlayerStateEntry,
	CleanStates: (self: ClientStateModule, player: Player) -> (),
	SynchronizeFromServer: (self: ClientStateModule) -> (),
	Start: (self: ClientStateModule) -> (),
	OnStateCleanedSnapshot: BindableEvent,
	Signal: Signal.PlayerStateSignals,
}

-- =============================================================================
-- INTERNAL STATE
-- =============================================================================

-- Stores all current player states indexed by Player instance.
local StateMap: StateMap = {}

-- Stores waiting callbacks while a state is not ready yet.
local PendingMap: PendingMap = {}

-- Registry of listeners for state changes.
-- Key format: "UserId:StateKey"
local CallbackRegistry: { [string]: { [StateCallback<any>]: true } } = {}

local Module = {} :: ClientStateModule
Module.Signal = Signal:GetSignal()

local StateChangedApi = {}
StateChangedApi.__index = StateChangedApi

function StateChangedApi:Connect<T>(callback: StateCallback<T>)
	assert(type(callback) == "function", "[StateClient] Connect: callback must be a function.")

	if not CallbackRegistry[self.KeyReference] then
		CallbackRegistry[self.KeyReference] = {}
	end

	-- Register callback for this state key.
	CallbackRegistry[self.KeyReference][callback :: StateCallback<any>] = true
	return self
end

function StateChangedApi:Once<T>(callback: StateCallback<T>)
	-- Runs only once, then auto disconnects.
	local wrappedCallback: StateCallback<T>

	wrappedCallback = function(value: T)
		callback(value)
		self:Disconnect(wrappedCallback)
	end

	return self:Connect(wrappedCallback)
end

function StateChangedApi:Disconnect<T>(callback: StateCallback<T>)
	assert(type(callback) == "function", "[StateClient] Disconnect: callback must be a function.")

	local map = CallbackRegistry[self.KeyReference]
	if not map then
		return nil
	end

	if map[callback :: StateCallback<any>] then
		map[callback :: StateCallback<any>] = nil
	else
		return nil
	end

	-- If no listeners remain, remove the registry entry.
	if next(map) == nil then
		CallbackRegistry[self.KeyReference] = nil
	end

	return
end

function Module:FireStateChanged<T>(player: Player, key: string, value: T)
	assert(player and typeof(player) == "Instance" and player:IsA("Player"), "[StateClient] FireStateChanged: invalid Player.")
	assert(type(key) == "string", "[StateClient] FireStateChanged: key must be a string.")

	local compositeKey = player.UserId .. ":" .. key
	local map = CallbackRegistry[compositeKey]

	if not map then
		return
	end

	-- Fire all listeners asynchronously.
	for callback in map do
		task.spawn(callback, value)
	end
end

-- ASYNC AWAIT

local function notifyPending(player: Player, entry: PlayerStateEntry?)
	local callbacks = PendingMap[player]

	if not callbacks then
		return
	end

	PendingMap[player] = nil

	-- Resume all waiting callbacks.
	for _, callback in callbacks do
		task.spawn(callback, entry)
	end
end

local function awaitPlayerState(player: Player): PlayerStateEntry?
	assert(player and typeof(player) == "Instance" and player:IsA("Player"), "[StateClient] awaitPlayerState: invalid Player.")

	-- State already loaded.
	if StateMap[player] then
		return StateMap[player]
	end

	if not player:IsDescendantOf(Players) then
		warn(`[StateClient] awaitPlayerState: player '{player.Name}' is no longer in Players.`)
		return nil
	end

	-- Instead of using a while true loop with coroutine to manage threads,
	-- we use task.delay to handle the wait time. This way, if the server
	-- does not respond within 3 seconds, the state is cleaned up and the player is notified.

	local thread = coroutine.running()
	local resolved = false
	local timeout = 3
	local delayThread: thread?

	assert(thread, "[StateClient] awaitPlayerState must run inside a coroutine.")

	if not PendingMap[player] then
		PendingMap[player] = {}
	end

	table.insert(PendingMap[player], function(entry: PlayerStateEntry?)
		if resolved then
			return
		end

		if delayThread then
			task.cancel(delayThread)
		end

		resolved = true
		task.spawn(thread, entry)
	end)

	delayThread = task.delay(timeout, function()
		if resolved then
			return
		end

		resolved = true
		PendingMap[player] = nil
		warn(`[StateClient] Timed out waiting for state of player '{player.Name}'.`)
		task.spawn(thread, nil)
	end)

	return coroutine.yield() :: PlayerStateEntry?
end

-- SYNCHRONIZATION

function Module:SynchronizeFromServer()
	-- Here we use InvokeServer to request all currently active states.
	local success, snapshot = pcall(function()
		return self.Signal.StatesLoaded:InvokeServer() or {}
	end)

	assert(success, "[StateClient] SynchronizeFromServer failed to invoke server.")
	assert(type(snapshot) == "table", "[StateClient] SynchronizeFromServer: snapshot must be a table.")

	-- Iterate through the snapshot and create an entry for each player.
	-- After that, notify all pending callbacks waiting for that state.
	for userId, originState in snapshot do
		local player = Players:GetPlayerByUserId(userId)

		if not player then
			warn(`[StateClient] SynchronizeFromServer: player with userId {userId} not found.`)
			continue
		end

		if StateMap[player] then
			continue
		end

		local entry = self:SetState(player, originState)
		StateMap[player] = entry
		notifyPending(player, entry)
	end
end

-- Used to update a replicated single state value from the server.
local function onReplicateState<Value>(userId: number, key: string, value: Value)
	local player = Players:GetPlayerByUserId(userId)

	if not player then
		warn(`[StateClient] ReplicateState ignored. Player with userId {userId} not found.`)
		return
	end

	local entry = StateMap[player]

	if not entry then
		warn(`[StateClient] ReplicateState ignored. No state for '{player.Name}'.`)
		return
	end

	entry.State[key] = value
end

-- Replicates multiple values at once using a table payload.
local function onReplicateStateWithTable<K, V>(userId: number, updates: { [K]: V })
	assert(type(updates) == "table", "[StateClient] ReplicateStateWithTable: updates must be a table.")

	local player = Players:GetPlayerByUserId(userId)

	if not player then
		warn(`[StateClient] ReplicateStateWithTable ignored. Player with userId {userId} not found.`)
		return
	end

	local entry = StateMap[player]

	if not entry then
		warn(`[StateClient] ReplicateStateWithTable ignored. No state for '{player.Name}'.`)
		return
	end

	for key, value in updates do
		entry.State[key] = value
	end
end

-- PUBLIC API

-- Gets the full internal entry.
function Module:GetReference(player: Player): PlayerStateEntry?
	assert(player and typeof(player) == "Instance" and player:IsA("Player"), "[StateClient] GetReference: expected Player instance.")
	return awaitPlayerState(player)
end

function Module:GetState(player: Player): (DefaultPlayerState?, SoapObject?)
	assert(player and typeof(player) == "Instance" and player:IsA("Player"), "[StateClient] GetState: expected Player instance.")

	local entry = awaitPlayerState(player)

	if not entry then
		return
	end

	return entry.State, entry.Soap
end

function Module:GetStateChanged<T>(player: Player, key: string): StateChangedConnection<T>
	assert(player and typeof(player) == "Instance" and player:IsA("Player"), "[StateClient] GetStateChanged: invalid Player.")
	assert(type(key) == "string" and key ~= "", "[StateClient] GetStateChanged: invalid key.")

	local compositeKey = player.UserId .. ":" .. key

	return (setmetatable({
		KeyReference = compositeKey,
	}, StateChangedApi) :: unknown) :: StateChangedConnection<T>
end

function Module:SetState(player: Player, cache: DefaultPlayerState?): PlayerStateEntry
	assert(player and typeof(player) == "Instance" and player:IsA("Player"), "[StateClient] SetState: expected Player.")
	assert(not StateMap[player], `[StateClient] Attempt to overwrite existing state for '{player.Name}'.`)

	local resolvedCache: DefaultPlayerState = cache or DefaultValues:CreateDefaultState({})

	-- Here we create a proxy metatable used to detect changed values.
	-- This is similar to AttributeChanged, but uses metatables instead
	-- of creating multiple connections.
	local proxy = setmetatable({} :: any, {
		__index = resolvedCache,

		__newindex = function<T>(_, key: string, value: T)
			resolvedCache[key] = value
			Module:FireStateChanged(player, key, value)
		end,
	}) :: DefaultPlayerState

	local entry: PlayerStateEntry = {
		State = proxy,
		Soap = Soap.New(),
	}

	-- Soap works similarly to Trove, but was built from scratch.
	-- You can add connections, instances, threads, etc.
	-- Everything will be cleaned when the player leaves.
	StateMap[player] = entry
	notifyPending(player, entry)

	return entry
end

function Module:CleanStates(player: Player)
	assert(player and typeof(player) == "Instance" and player:IsA("Player"), "[StateClient] CleanStates: expected Player.")

	local entry = StateMap[player]

	if not entry then
		notifyPending(player, nil)
		return
	end

	local entryCopy = DefaultValues:DeepCopy(entry)

	-- This signal is used to avoid race conditions when the player leaves the game.
	self.Signal.OnStateCleanedSnapshot:Fire(player, entryCopy)

	setmetatable(entry.State, nil)
	entry.Soap:Destroy()

	StateMap[player] = nil
end

-- Here we initialize the main logic by connecting events
-- and synchronizing states.
function Module:Start()

    -- Connect
	Players.PlayerAdded:Connect(function(player: Player)
		self:SetState(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:CleanStates(player)
	end)

	self.Signal.ReplicateEvent.OnClientEvent:Connect(onReplicateState)
	self.Signal.ReplicateTableEvent.OnClientEvent:Connect(onReplicateStateWithTable)

    ------------//

    -- initialize
	self:SetState(Players.LocalPlayer)

	task.spawn(function()
		self:SynchronizeFromServer()
	end)
end

Module:Start()

return Module
