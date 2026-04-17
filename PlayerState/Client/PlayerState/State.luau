--!strict

local Module = {} :: {
	DEFAULT_PLAYER_STATE: DefaultPlayerState,
	CreateDefaultState: <T>(self: any, tbl: T) -> T & DefaultPlayerState,
	DeepCopy: <T>(self: any, tbl: T) -> T,
	CloneValue: <T>(self: any, value: T) -> T,
}

export type DefaultPlayerState = {
	CurrentTrack: { [string]: any },
	RateLimit: number,
	AntiCheat: { [string]: any },
	CurrentEmotes: { [string]: any },
	AvatarOriginItems: { [string]: any },
	LastEmmit: number,
	BaseHumanoidDescription: HumanoidDescription | boolean,
	Room: number,
	DualEmoteName: string,
	ToyInUse: string,
	DualEmoted: Player?,
	AvatarOriginFolder: Folder?,
}

local DEFAULT_PLAYER_STATE: DefaultPlayerState = {
	CurrentTrack = {},
	RateLimit = 0,
	AntiCheat = {},
	CurrentEmotes = {},
	AvatarOriginItems = {},
	LastEmmit = time(),
	BaseHumanoidDescription = false,
	Room = 0,
	ToyInUse = "",
	DualEmoteName = "",
	DualEmoted = nil,
	AvatarOriginFolder = nil,
}


--//
Module.DEFAULT_PLAYER_STATE = DEFAULT_PLAYER_STATE

function Module:CloneValue<T>(value: T): T
	if typeof(value) == "table" then
		return Module.DeepCopy(Module, value) :: T
	end
	
	return value
end

function Module:CreateDefaultState<T>(tbl: T): T & DefaultPlayerState
	for key, value in (DEFAULT_PLAYER_STATE :: any) :: { [any]: any } do
		(tbl :: any)[key] = self:CloneValue(value)
	end
	
	return tbl :: T & DefaultPlayerState
end

function Module:DeepCopy<T>(tbl: T): T
	local copy: any = {}

	for key, value in (tbl :: any) do
		if typeof(value) == "table" then
			copy[key] = self.DeepCopy(self, value)
		else
			copy[key] = value
		end
	end

	return copy :: T
end

return Module
