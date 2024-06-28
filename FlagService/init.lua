--!nonstrict

--
--			FlagService
--
--

local FlagService = {}

-- Services
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")

-- Modules
local Promise = require(script.Parent.Parent.Promise)
local Signal = require(script.Parent.Parent.Signal)

-- Types
type PromiseResolve = (props: any) -> ()
type PromiseReject = (errorMessage: string?) -> ()
type Promise<T> = {
	andThen: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
	andThenCall: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
	andThenReturn: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> any,
	await: () -> (),
	awaitStatus: () -> (),
	awaitValue: () -> Promise<T>,
	cancel: () -> (),
	catch: (self: Promise<T>, func: (e: string?) -> ()) -> (),
	done: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
	doneCall: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
	doneReturn: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> (),
	expect: () -> (),
	finally: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
	finallyCall: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> Promise<T>,
	finallyReturn: (self: Promise<T>, func: (resolve: PromiseResolve, reject: PromiseReject, cancel: () -> ()) -> ()) -> (),
	getStatus: () -> any,
	now: () -> (),
	tap: () -> Promise<T>,
	timeout: (secs: any) -> Promise<T>,
}

type Connection = {
	Disconnect: (self: Connection) -> (),
	Destroy: (self: Connection) -> (),
	Connected: boolean,
}

type Signal<T...> = {
	Fire: (self: Signal<T...>, T...) -> (),
	FireDeferred: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	DisconnectAll: (self: Signal<T...>) -> (),
	GetConnections: (self: Signal<T...>) -> { Connection },
	Destroy: (self: Signal<T...>) -> (),
	Wait: (self: Signal<T...>) -> T...,
}
type messagingFlagData = {
    Flag: Flag,
    ServerId: string,
}
type flagMetaData = {
    [string]: any,
}
export type Flag = {
    Name: string,
    Value: any,

    TimeUpdated: number?,

    MetaData: flagMetaData?,
}

-- Constants
local FLAG_SERVICE_DATA_STORE_NAME = "FlagService_DataStore"
local FLAG_SERVICE_DATA_STORE_KEY = "FlagService_DataStore_Key"
local FLAG_SERVICE_MESSAGING_TOPIC = "FlagService_Messaging_Topic"

local SERVER_ID = game.JobId

-- Variables
local isInitialized = false
local hasLoadedFlags = false

local flagsDataStore: DataStore = DataStoreService:GetDataStore(FLAG_SERVICE_DATA_STORE_NAME)
local flags: { [string]: any } = {}
local flagSignals: { [string]: Signal<any> } = {}

-- Private functions
function FlagService:_loadFlags()
    local success, flagData = pcall(function()
        return flagsDataStore:GetAsync(FLAG_SERVICE_DATA_STORE_KEY)
    end)

    if not success then
        warn("Failed to load flags from DataStore", flagData)
        return
    end

    flags = flagData or {}

    hasLoadedFlags = true
end

function FlagService:_readFlagChangedMessages()
    MessagingService:SubscribeAsync(FLAG_SERVICE_MESSAGING_TOPIC, function(message: Message)
        local messagingFlagData: messagingFlagData = message.Data

        if messagingFlagData.ServerId == SERVER_ID then
            return
        end

        local flag = messagingFlagData.Flag

        FlagService:_updateFlagValue(flag.Name, flag.Value)
        if flag.MetaData ~= nil then
            FlagService:_updateFlagMetaData(flag.Name, flag.MetaData)
        end

        FlagService:_fireInternalFlagChangedSignal(flag.Name)
    end)
end

function FlagService:_awaitFlagsLoaded()
    repeat
        task.wait()
    until hasLoadedFlags == true
end

function FlagService:_createFlag(flagData: Flag)
    if flagData.Name == nil then
        warn("Flag data is missing a name")
        return
    end
    if flagData.Value == nil then
        warn("Flag data is missing a value")
        return
    end

    if flagData.TimeUpdated == nil then
        flagData.TimeUpdated = os.time()
    end

    flags[flagData.Name] = flagData
end

function FlagService:_updateFlagValue(flagName: string, flagValue: any)
    if flags[flagName] == nil then
        warn("Flag does not exist")
        return
    end

    flags[flagName].Value = flagValue
    flags[flagName].TimeUpdated = os.time()
end

function FlagService:_updateFlagMetaData(flagName: string, flagMetaData: flagMetaData)
    if flags[flagName] == nil then
        warn("Flag does not exist")
        return
    end

    flags[flagName].MetaData = flagMetaData
end

function FlagService:_sendFlagChangedMessageToOtherServers(Flag: Flag)
    local messagingFlagData: messagingFlagData = {
        Flag = Flag,
        ServerId = SERVER_ID,
    }

    MessagingService:PublishAsync(FLAG_SERVICE_MESSAGING_TOPIC, messagingFlagData)
end

function FlagService:_fireInternalFlagChangedSignal(flagName: string)
    if not flagSignals[flagName] then
        return
    end

    flagSignals[flagName]:Fire(flags[flagName].Value)
end

function FlagService:_initialize()
    isInitialized = true
    FlagService:_loadFlags()
    FlagService:_readFlagChangedMessages()
end

-- Public functions

--//
--// Set a flag by name
--//

function FlagService:SetFlag(flagName: string, newValue: any, metaData: flagMetaData?)
    if flags[flagName] == nil then
        FlagService:_createFlag({
            Name = flagName,
            Value = newValue,
            MetaData = metaData,
        })
    end

    FlagService:_updateFlagValue(flagName, newValue)

    if metaData ~= nil then
        FlagService:_updateFlagMetaData(flagName, metaData)
    end

    local thisFlag: Flag = flags[flagName]

    local success, result = pcall(function()
        return flagsDataStore:UpdateAsync(FLAG_SERVICE_DATA_STORE_KEY, function(oldData: any?)
            local newFlags = oldData or {}

            newFlags[flagName] = thisFlag

            return newFlags
        end)
    end)

    if not success then
        warn("Failed to update flag in DataStore", result)
        return false, result
    end

    FlagService:_fireInternalFlagChangedSignal(flagName)
    FlagService:_sendFlagChangedMessageToOtherServers(thisFlag)

    return true, thisFlag
end

function FlagService:SetFlagAsync(flagName: string, newValue: any, metaData: flagMetaData?): Promise<boolean | string>
    return Promise.new(function(resolve: PromiseResolve, reject: PromiseReject)
        if hasLoadedFlags == false then
            FlagService:_awaitFlagsLoaded()
        end

        local success, result = FlagService:SetFlag(flagName, newValue, metaData)

        if not success then
            reject(result)
            return
        end

        resolve(result)
    end)
end

--//
--// Get a flag by name
--//

function FlagService:GetFlag(flagName: string): Flag?
    return flags[flagName]
end

function FlagService:GetFlagAsync(flagName: string): Promise<Flag>
    return Promise.new(function(resolve: PromiseResolve, reject: PromiseReject)
        if hasLoadedFlags == false then
            FlagService:_awaitFlagsLoaded()
        end

        local flagData = FlagService:GetFlag(flagName)

        if flagData == nil then
            reject("Flag does not exist")
            return
        end

        resolve(flagData)
    end)
end

--//
--// Update a flag by name
--//
function FlagService:UpdateFlag(flagName: string, updateFunction: (oldValue: any) -> any, metaData: any)
    if flags[flagName] == nil then
        warn("Flag does not exist")
        return
    end

    local flag = flags[flagName]

    local newValue = updateFunction(flag.Value)

    local success, result = FlagService:SetFlagAsync(flagName, newValue, metaData):await()

    if not success then
        return success, result
    end

    return success, result
end

function FlagService:UpdateFlagAsync(flagName: string, updateFunction: (oldValue: any) -> any, metaData: any): Promise<Flag>
    return Promise.new(function(resolve: PromiseResolve, reject: PromiseReject)
        if hasLoadedFlags == false then
            FlagService:_awaitFlagsLoaded()
        end

        local success, result = FlagService:UpdateFlag(flagName, updateFunction, metaData)

        if not success then
            reject(result)
            return
        end

        resolve(result)
    end)
end

--//
--// Get a flag changed signal
--//

function FlagService:GetFlagChangedSignal(flagName: string): Signal<any>
    if not flagSignals[flagName] then
        flagSignals[flagName] = Signal.new()
    end

    return flagSignals[flagName]
end

--//
--// Setup
--//

if isInitialized == false then
    FlagService:_initialize()
end

return FlagService