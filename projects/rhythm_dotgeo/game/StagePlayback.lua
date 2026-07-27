local Core = require("core")

local StagePlayback = {}
StagePlayback.__index = StagePlayback

local function defaultTransportFactory(stage)
    return Core.PlaybackTransport.new({
        bpm = stage.bpm,
        musicPlayback = Core.MusicPlayback.new(),
    })
end

local function resolveMusicPath(projectId, music)
    if not music then return nil end
    return "projects/" .. projectId .. "/" .. music
end

function StagePlayback.new(project, options)
    options = options or {}
    return setmetatable({
        project = project,
        standalone = options.standalone == true,
        transportFactory = options.transportFactory or defaultTransportFactory,
        eventHandlers = options.eventHandlers or {},
        runtime = nil,
        transport = nil,
    }, StagePlayback)
end

function StagePlayback:applyOccurrences(game, occurrences)
    for _, occurrence in ipairs(occurrences) do
        local event = occurrence.event
        if event.type == "projectEvent" then
            local handler = self.eventHandlers[event.eventId]
            if not handler then
                return nil, "Unknown Rhythm Dotgeo Project Event: " .. tostring(event.eventId)
            end
            local succeeded, handlerError = pcall(handler.apply, game, event, occurrence)
            if not succeeded then return nil, tostring(handlerError) end
        end
    end
    return true, nil
end

function StagePlayback:start(game, stage, startBeat)
    self:stop()
    self.runtime = Core.StageRuntime.new()
    local occurrences, runtimeError = self.runtime:start(stage, startBeat or 0)
    if not occurrences then return nil, runtimeError end
    local applied, applyError = self:applyOccurrences(game, occurrences)
    if not applied then return nil, applyError end
    if not self.standalone or self.runtime:isEnded() then return true, nil end

    local transport, transportError = self.transportFactory(stage)
    if not transport then return nil, transportError end
    local mixtape = Core.MixtapeSettings.resolve(stage.mixtape)
    local configured, configureError = transport:configureMixtape(
        mixtape,
        resolveMusicPath(self.project.id, mixtape.music)
    )
    if not configured then return nil, configureError end
    local started, startError = transport:play()
    if not started then
        transport:pause()
        return nil, startError
    end
    self.transport = transport
    return true, nil
end

function StagePlayback:update(game, deltaTime, externalBeat)
    local beat = externalBeat
    if self.transport and beat == nil then
        local updated, updateError = self.transport:update(deltaTime)
        if not updated then return nil, updateError end
        beat = self.transport:getBeat()
    end
    if beat == nil then return true, nil end

    local occurrences, runtimeError = self.runtime:update(beat)
    if not occurrences then return nil, runtimeError end
    local applied, applyError = self:applyOccurrences(game, occurrences)
    if not applied then return nil, applyError end

    if self.runtime:isEnded() and self.transport then
        self.transport:pause()
        self.transport:seekBeat(self.runtime:getEndBeat())
    elseif self.transport and self.transport:isMusicFinished()
        and not self.runtime:hasEndEvent() then
        self.transport:pause()
    end
    return true, nil
end

function StagePlayback:getBeat()
    return self.runtime and self.runtime:getCurrentBeat() or 0
end

function StagePlayback:isInputEnabled()
    return self.runtime == nil or self.runtime:isInputEnabled()
end

function StagePlayback:stop()
    if not self.transport then return true end
    local paused, pauseError = self.transport:pause()
    self.transport = nil
    return paused, pauseError
end

return StagePlayback
