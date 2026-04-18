-- Client/Signal.lua
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
    return {
        ReplicateEvent         = PlayerStateShared:WaitForChild("ReplicateState") :: RemoteEvent,
        ReplicateTableEvent    = PlayerStateShared:WaitForChild("ReplicateStateWithTable") :: RemoteEvent,
        StatesLoaded           = PlayerStateShared:WaitForChild("StatesLoaded") :: RemoteFunction,
        OnStateCleanedSnapshot = PlayerStateShared:WaitForChild("OnStateCleanedSnapshot") :: BindableEvent,
    }
end

return Module
