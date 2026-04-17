local types = require(script.Type)

local Module = {}
local Api = {}
Api.__index = Api

local function isSafeTable(t)
	return typeof(t) == "table" and getmetatable(t) == nil
end

local function clean(t)
	for _, remove in t do
		local valueType = typeof(remove)
		if valueType == "Instance" then
			remove:Destroy()
		elseif valueType == "RBXScriptConnection" then
			remove:Disconnect()
		elseif valueType == "thread" then
			task.cancel(remove)
		elseif valueType == "function" then
			remove()
		elseif valueType == "Tween" then
			remove:Cancel()
		elseif isSafeTable(remove) then
			clean(remove)
		end
	end
end

function Api:Add(...)
	for _, object in { ... } do
		table.insert(self, object)
	end
end

function Api:Remove(...)
	for _, object in { ... } do
		local index = table.find(self, object)
		if index then
			table.remove(self, index)
		end
	end
end

function Api:Destroy()
	self:Cleanup()
	setmetatable(self, nil)
end

function Api:Cleanup()
	clean(self)

	return
end

export type SoapObject = typeof(setmetatable({}, Api))

function Module.New()
	local self = setmetatable({}, Api)
	return self :: types.SoapObject 
end

return Module