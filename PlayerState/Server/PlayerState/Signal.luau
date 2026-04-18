-- Server/Signal.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerStateShared = ReplicatedStorage.Services.PlayerState

local Module = {}
local created = false

export type PlayerStateSignals = {
	ReplicateEvent: RemoteEvent,
	ReplicateTableEvent: RemoteEvent,
	StatesLoaded: RemoteFunction,
	OnStateCleanedSnapshot: BindableEvent,
}

function Module.New(): PlayerStateSignals
	assert(not created, "[Signal] New() called more than once.")
	created = true

	local ReplicateEvent = Instance.new("RemoteEvent")
	ReplicateEvent.Name = "ReplicateState"
	ReplicateEvent.Parent = PlayerStateShared

	local ReplicateTableEvent = Instance.new("RemoteEvent")
	ReplicateTableEvent.Name = "ReplicateStateWithTable"
	ReplicateTableEvent.Parent = PlayerStateShared

	local StatesLoaded = Instance.new("RemoteFunction")
	StatesLoaded.Name = "StatesLoaded"
	StatesLoaded.Parent = PlayerStateShared

	local OnStateCleanedSnapshot = Instance.new("BindableEvent")
	OnStateCleanedSnapshot.Name = "OnStateCleanedSnapshot"
	OnStateCleanedSnapshot.Parent = PlayerStateShared

	return {
		ReplicateEvent = ReplicateEvent,
		ReplicateTableEvent = ReplicateTableEvent,
		StatesLoaded = StatesLoaded,
		OnStateCleanedSnapshot = OnStateCleanedSnapshot,
	}
end

return Module
