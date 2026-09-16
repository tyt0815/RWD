local ReturnActors = {}

function ReturnActors.apply(runtime, event)
    runtime.guideActor.bounceEnabled = false
    runtime.playerActor.bounceEnabled = false
    runtime.crepeActor:stopMovement(event.startBeat, runtime.tempoMap:beatToSeconds(event.startBeat))
    runtime.guideActor:moveOutside(false, event.startBeat, 0.5)
    runtime.playerActor:moveOutside(false, event.startBeat, 0.5)
end

return ReturnActors
