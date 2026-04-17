--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerStateShared = ReplicatedStorage.Services.PlayerState

local Module = {}

export type Events = {
	ReplicateEvent: RemoteEvent,
	ReplicateTableEvent: RemoteEvent,
	StatesLoaded: RemoteFunction,
	OnStateCleanedSnapshot: BindableEvent,
}

function Module.New(): Events
	local ReplicateEvent: RemoteEvent = Instance.new("RemoteEvent")
	ReplicateEvent.Name = "ReplicateState"
	ReplicateEvent.Parent = PlayerStateShared

	local ReplicateTableEvent: RemoteEvent = Instance.new("RemoteEvent")
	ReplicateTableEvent.Name = "ReplicateStateWithTable"
	ReplicateTableEvent.Parent = PlayerStateShared

	local StatesLoaded: RemoteFunction = Instance.new("RemoteFunction")
	StatesLoaded.Name = "StatesLoaded"
	StatesLoaded.Parent = PlayerStateShared

	local OnStateCleanedSnapshot: BindableEvent = Instance.new("BindableEvent")
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