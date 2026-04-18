-- Client/Signal.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Module = {}

export type PlayerStateSignals = {
    ReplicateEvent: RemoteEvent,
    ReplicateTableEvent: RemoteEvent,
    StatesLoaded: RemoteFunction,
    OnStateCleanedSnapshot: BindableEvent,
}

function Module:GetSignal(): PlayerStateSignals
    return {
        ReplicateEvent = ReplicatedStorage:WaitForChild("ReplicateState") :: RemoteEvent,
        ReplicateTableEvent = ReplicatedStorage:WaitForChild("ReplicateStateWithTable") :: RemoteEvent,
        StatesLoaded = ReplicatedStorage:WaitForChild("StatesLoaded") :: RemoteFunction,
        OnStateCleanedSnapshot = ReplicatedStorage:WaitForChild("OnStateCleanedSnapshot") :: BindableEvent,
    }
end

return Module
