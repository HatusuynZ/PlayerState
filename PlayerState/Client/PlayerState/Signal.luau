--!strict

local PlayerStateShared = script.Parent

local Module = {}

export type PlayerStateSignals = {
	ReplicateEvent: RemoteEvent,
	ReplicateTableEvent: RemoteEvent,
	StatesLoaded: RemoteFunction,
	OnStateCleanedSnapshot: BindableEvent,
}

function Module:GetSignal(): PlayerStateSignals
	local ReplicateEvent: RemoteEvent = PlayerStateShared:WaitForChild("ReplicateState") :: RemoteEvent
	local ReplicateTableEvent: RemoteEvent = PlayerStateShared:WaitForChild("ReplicateStateWithTable") :: RemoteEvent
	local StatesLoaded: RemoteFunction = PlayerStateShared:WaitForChild("StatesLoaded") :: RemoteFunction
	local OnStateCleanedSnapshot: BindableEvent = PlayerStateShared:WaitForChild("OnStateCleanedSnapshot") :: BindableEvent

	return {
		ReplicateEvent = ReplicateEvent,
		ReplicateTableEvent = ReplicateTableEvent,
		StatesLoaded = StatesLoaded,
		OnStateCleanedSnapshot = OnStateCleanedSnapshot,
	}
end

return Module