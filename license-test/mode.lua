Sim = ac.getSim()
Car = ac.getCar(0)
Session = ac.getSession(Sim.currentSessionIndex)

local SessionRestarted = true
local SessionTimer = 0
local PreviousSessionTimer = 0
local ResultTime = 99999999
local CarMoved = 0
-- local SafetyCarStartPos = (Car.splinePosition+0.01) % 1
local SafetyCarReadjusted = false
SafetyCarSplineOffset = 0

function string_formatTimeMiliseconds(Time)
    --ac.log(Time)
    local miliseconds = math.floor(Time % 1000)
    local seconds = math.floor((Time/1000) % 60)
    local minutes = math.floor((Time/60000) % 60)
    local hours = math.floor((Time/3600000) % 60)
    local hoursString = tostring(hours)
    local minutesString = tostring(minutes)
    local secondsString = tostring(seconds)
    local milisecondsString = tostring(miliseconds)
    if miliseconds < 10 then
        milisecondsString = "00" .. milisecondsString
    elseif miliseconds < 100 then
        milisecondsString = "0" .. milisecondsString
    end
    if seconds < 10 then
        secondsString = "0" .. secondsString
    end
    if hours > 0 and minutes < 10 then
        minutesString = "0" .. minutesString
    end
    if hours > 0 then
        return hoursString .. ":" .. minutesString .. ":" .. secondsString .. "." .. milisecondsString
    else
        return minutesString .. ":" .. secondsString .. "." .. milisecondsString
    end
end

function string_formatTimeSeconds(SecondsValue)
    local hours = math.floor(SecondsValue / 3600)
    local minutes = math.floor((SecondsValue % 3600) / 60)
    local seconds = math.floor(SecondsValue % 60)
    local hoursString = tostring(hours)
    local minutesString = tostring(minutes)
    local secondsString = tostring(seconds)
    if seconds < 10 then
        secondsString = "0" .. secondsString
    end
    if hours > 0 and minutes < 10 then
        minutesString = "0" .. minutesString
    end
    if hours > 0 then
        return hoursString .. ":" .. minutesString .. ":" .. secondsString
    else
        return minutesString .. ":" .. secondsString
    end
end

ConfigINI = ac.INIConfig.load(ac.getFolder(ac.FolderID.ExtCfgUser) .. "/state/lua/new_modes/license-test__settings.ini")
UserConfigINI = ac.INIConfig.load(ac.getFolder(ac.FolderID.ExtLua) .. "/new-modes/license-test/usersettings.ini")
ac.log(UserConfigINI)
-- Miliseconds
GoldTime = ConfigINI:get("SETTINGS", "gold", 30000)
SilverTime = ConfigINI:get("SETTINGS", "silver", 45000)
BronzeTime = ConfigINI:get("SETTINGS", "bronze", 60000)
RequireBraking = ConfigINI:get("SETTINGS", "brakefinish", 0)
FinishLine = ConfigINI:get("SETTINGS", "finishline", 0.25)
RenderCheckpoints = ConfigINI:get("SETTINGS", "rendercheckpoints", 1)
RenderCones = ConfigINI:get("SETTINGS", "rendercones", 1)
TrackLimitsType = ConfigINI:get("SETTINGS", "tracklimitstype", "SURFACE")
TrackLimitsRange = ConfigINI:get("SETTINGS", "tracklimitsrange", 1.1)
WarningTimeoutLimit = ConfigINI:get("SETTINGS", "warningtimeout", 3)
SafetyCarEnabled = ConfigINI:get("SETTINGS", "safetycar", 0)
SafetyCarSpeedLimit = ConfigINI:get("SETTINGS", "safetycarspeedlimit", 1000)

CheckpointCount = math.ceil(900*FinishLine)
CheckpointRange = FinishLine/CheckpointCount
CheckpointsList = {}

local CurrentCheckpoint = 1
local OffTrackTimer = 0
local PassedSafetyCarTimer = 0
local LostSafetyCarTimer = 0

function script.update(dt)
    Sim = ac.getSim()
    Car = ac.getCar(0)
    Session = ac.getSession(Sim.currentSessionIndex)

    if #CheckpointsList == 0 then
        for i = 1,CheckpointCount do
            if (CheckpointRange*i+Car.splinePosition)%1 > 0.99 then
                CheckpointsList[#CheckpointsList+1] = 0.99
            elseif (CheckpointRange*i+Car.splinePosition)%1 < 0.001 then
                CheckpointsList[#CheckpointsList+1] = 0.001
            else
                CheckpointsList[#CheckpointsList+1] = (CheckpointRange*i+Car.splinePosition)%1
            end
        end
        --ac.log(CheckpointsList)
        CurrentCheckpoint = 1
    end
    --local distance = 9999999
    if ac.getCar(1) then
        if SafetyCarEnabled == 1 then
            SafetyCar = ac.getCar(1)
            if Sim.timeToSessionStart <= 1000 then
                physics.setAIPitStopRequest(1, false)
                --physics.setAINoInput(1, false, false)
                physics.setAISplineOffset(1, SafetyCarSplineOffset, true)
                if SafetyCarSplineOffset ~= 0 then
                    SafetyCarSplineOffset = SafetyCarSplineOffset*0.999
                    if math.abs(SafetyCarSplineOffset) < 0.01 then
                        SafetyCarSplineOffset = 0
                    end
                end
                physics.setAICaution(1, 0.1)
                physics.setAIAggression(1, 1)
                physics.setAILevel(1, 1)
                PassedSafetyCar = false
                local SafetyGap = ac.getGapBetweenCars(0, 1)
                if SafetyGap < 0 and SafetyGap > -10 and Sim.timeToSessionStart < -3000 then --and Car.sessionLapCount == SafetyCar.sessionLapCount  then
                    PassedSafetyCar = true
                else
                    PassedSafetyCar = false
                end
                ac.log(SafetyGap)
                if SafetyGap > 5 and SafetyGap < 10 and Sim.timeToSessionStart < -3000 then
                    LostSafetyCar = true
                elseif SafetyGap > 2.5 and Sim.timeToSessionStart < -3000 then
                    physics.setAITopSpeed(1, math.min(SafetyCarSpeedLimit, math.max(20, Car.speedKmh-100)))
                    physics.setAISplineOffset(1, math.random(-30,30)*0.01, true)
                    LostSafetyCar = false
                elseif SafetyGap > 2 and Sim.timeToSessionStart < -3000 then
                    physics.setAITopSpeed(1, math.min(SafetyCarSpeedLimit, math.max(30, Car.speedKmh-50)))
                    physics.setAISplineOffset(1, math.random(-20,20)*0.01, true)
                    LostSafetyCar = false
                elseif SafetyGap > 1.5 and Sim.timeToSessionStart < -3000 then
                    physics.setAITopSpeed(1, math.min(SafetyCarSpeedLimit, math.max(40, Car.speedKmh-30)))
                    physics.setAISplineOffset(1, math.random(-10,10)*0.01, true)
                    LostSafetyCar = false
                elseif SafetyGap > 1 and Sim.timeToSessionStart < -3000 then
                    physics.setAITopSpeed(1, math.min(SafetyCarSpeedLimit, math.max(50, Car.speedKmh-5)))
                    LostSafetyCar = false
                elseif SafetyGap > 0.3 and Sim.timeToSessionStart < -3000 then
                    physics.setAITopSpeed(1, math.min(SafetyCarSpeedLimit, math.max(50, Car.speedKmh+10)))
                    LostSafetyCar = false
                else
                    physics.setAITopSpeed(1, math.min(SafetyCarSpeedLimit, math.max(50, Car.speedKmh+50)))
                    LostSafetyCar = false
                end
            end
        else
            local SafetyCar = ac.getCar(1)
            physics.setAICarPosition(1, SafetyCar.pitTransform.position, -SafetyCar.pitTransform.look)
        end
        for i = 2,200 do
            if ac.getCar(i) then
                physics.setAICarPosition(i, ac.getCar(i).pitTransform.position, -ac.getCar(i).pitTransform.look)
            else
                break
            end
        end
    end

    if PreviousSessionTimer > Sim.timeToSessionStart-1 and (not Sim.isReplayActive) then
        PreviousSessionTimer = Sim.timeToSessionStart
    else
        SessionRestarted = true
        SessionTimer = 0
        PassedSafetyCar = false
        LostSafetyCar = false
        WentOffTrack = false
        CarMoved = 0
        CurrentCheckpoint = 1
        if not SafetyCarReadjusted then
            -- SafetyCarStartPos = (Car.splinePosition+0.006) % 1
            SafetyCarReadjusted = true
        end
    end

    if Car.speedKmh > 1 then
        SessionTimer = math.ceil(-Sim.timeToSessionStart)
        local pos = ac.worldCoordinateToTrack(Car.position)
        if not Sim.isPaused then
            if TrackLimitsType == "AILINE" then
                if math.abs(pos.x) > TrackLimitsRange then
                    WentOffTrack = true
                    OffTrackTimer = OffTrackTimer + dt
                else
                    WentOffTrack = false
                    OffTrackTimer = 0
                end
            elseif TrackLimitsType == "SURFACE" then
                if not ac.getCar(0).wheels[0].surfaceValidTrack or not ac.getCar(0).wheels[1].surfaceValidTrack or not ac.getCar(0).wheels[2].surfaceValidTrack or not ac.getCar(0).wheels[3].surfaceValidTrack then
                    WentOffTrack = true
                    OffTrackTimer = OffTrackTimer + dt
                else
                    WentOffTrack = false
                    OffTrackTimer = 0
                end
            else
                WentOffTrack = false
                OffTrackTimer = 0
            end
            if PassedSafetyCar then
                PassedSafetyCarTimer = PassedSafetyCarTimer + dt
            else
                PassedSafetyCarTimer = 0
            end
            if LostSafetyCar then
                LostSafetyCarTimer = LostSafetyCarTimer + dt
            else
                LostSafetyCarTimer = 0
            end
        end
        
        if Sim.timeToSessionStart < -1000 then
            CarMoved = CarMoved + Car.speedKmh
        end
        --ac.log(Car.splinePosition)
        if CheckpointsList[CurrentCheckpoint] and Car.splinePosition > CheckpointsList[CurrentCheckpoint] and Car.splinePosition < CheckpointsList[CurrentCheckpoint] + 0.1 then--or Car.splinePosition < CheckpointsList[CurrentCheckpoint]-0.33 then
            CurrentCheckpoint = CurrentCheckpoint+1
        elseif not CheckpointsList[CurrentCheckpoint] then
            CurrentCheckpoint = 0
        end
    elseif SessionRestarted == true then
        SessionRestarted = false
        SessionTimer = 0
        PassedSafetyCar = false
        LostSafetyCar = false
        WentOffTrack = false
        CarMoved = 0
        CurrentCheckpoint = 1
        CheckpointsList = {}
        if not SafetyCarReadjusted then
            -- SafetyCarStartPos = (Car.splinePosition+0.006) % 1
            SafetyCarReadjusted = true
        end
    end

    if Car.speedKmh <= 1 and CarMoved > 10 and Sim.timeToSessionStart < -2000 and (not ((CurrentCheckpoint == 0 or CurrentCheckpoint == #CheckpointsList) and Car.splinePosition > CheckpointsList[#CheckpointsList] and Car.splinePosition < CheckpointsList[#CheckpointsList]+0.0075)) then
        ac.endSession(string.format("You lost! \nYou stopped before the finish line!"), false, {
            summary = "Too slow!",
            message = string.format("You lost! \nYou stopped before the finish line!")
        })
    elseif WentOffTrack and OffTrackTimer > WarningTimeoutLimit and Sim.timeToSessionStart < -WarningTimeoutLimit*3000 then
        ac.endSession(string.format("You lost! \nYou went off the track limits!"), false, {
            summary = "Track Limits!",
            message = string.format("You lost! \nYou went off the track limits!")
        })
    elseif LostSafetyCar and (not (CurrentCheckpoint == 0 or CurrentCheckpoint == #CheckpointsList)) and LostSafetyCarTimer > WarningTimeoutLimit and Sim.timeToSessionStart < -WarningTimeoutLimit*3000 then
        ac.endSession(string.format("You lost! \nYou lost the Safety Car!"), false, {
            summary = "Too slow!",
            message = string.format("You lost! \nYou lost the Safety Car!")
        })
    elseif Car.collidedWith > 0 and Sim.timeToSessionStart < 0 then
        ac.endSession(string.format("You lost! \nYou have collided with the safety car!"), false, {
            summary = "Collision!",
            message = string.format("You lost! \nYou have collided with the safety car!")
        })
    elseif PassedSafetyCar and Sim.timeToSessionStart < 0 and PassedSafetyCarTimer > WarningTimeoutLimit and Sim.timeToSessionStart < -WarningTimeoutLimit*3000 then
        ac.endSession(string.format("You lost! \nYou overtook the safety car!"), false, {
            summary = "Overtake!",
            message = string.format("You lost! \nYou overtook the safety car!")
        })
    elseif CurrentCheckpoint == 0 then
        if RequireBraking == 1 and Car.splinePosition >= CheckpointsList[#CheckpointsList]+0.008 then
            ac.endSession(string.format("You lost! \nYou passed the braking zone!"), false, {
                summary = "Too fast!",
                message = string.format("You lost! \nYou passed the braking zone!")
            })
        elseif RequireBraking == 0 or (Car.speedKmh <= 0.01 and Car.splinePosition < CheckpointsList[#CheckpointsList]+0.008) then
            ResultTime = SessionTimer
            if ResultTime <= GoldTime then
                ac.endSession(string.format("You've got a GOLD medal! \nTime: " .. string_formatTimeMiliseconds(ResultTime)), true, {
                    place = 1,
                    summary = "Gold Medal!",
                    message = string.format("You've got a GOLD medal! \nTime: " .. string_formatTimeMiliseconds(ResultTime))
                })
            elseif ResultTime <= SilverTime then
                ac.endSession(string.format("You've got a SILVER medal! \nTime: " .. string_formatTimeMiliseconds(ResultTime)), true, {
                    place = 2,
                    summary = "Silver Medal!",
                    message = string.format("You've got a SILVER medal! \nTime: " .. string_formatTimeMiliseconds(ResultTime))
                })
            elseif ResultTime <= BronzeTime then
                ac.endSession(string.format("You've got a BRONZE medal! \nTime: " .. string_formatTimeMiliseconds(ResultTime)), true, {
                    place = 3,
                    summary = "Bronze Medal!",
                    message = string.format("You've got a BRONZE medal! \nTime: " .. string_formatTimeMiliseconds(ResultTime))
                })
            elseif ResultTime > BronzeTime then
                ac.endSession(string.format("You lost! You did not finish in time! \nTime: " .. string_formatTimeMiliseconds(ResultTime)), false, {
                    summary = "Too slow!",
                    message = string.format("You lost! You did not finish in time! \nTime: " .. string_formatTimeMiliseconds(ResultTime))
                })
            end 
        end
    end
end

local bronzeIcon = ac.getFolder(ac.FolderID.ExtRoot) .. "/lua/new-modes/license-test/bronze.png"
local silverIcon = ac.getFolder(ac.FolderID.ExtRoot) .. "/lua/new-modes/license-test/silver.png"
local goldIcon = ac.getFolder(ac.FolderID.ExtRoot) .. "/lua/new-modes/license-test/gold.png"
local pepegaIcon = ac.getFolder(ac.FolderID.ExtRoot) .. "/lua/new-modes/license-test/pepega.png"

local UIScale = UserConfigINI:get("SETTINGS", "ui_scale", 1) * Sim.windowHeight/1080 -- i'm adjusting everything to 1080p resolution. with this, your scale will be auto adjusted to have the correct size.
function script.drawUI()
    ui.beginOutline()
    ui.pushDWriteFont('Arkitech:\\fonts;Weight=Regular')
    local basePosX = Sim.windowWidth*0.5
    local basePosY = Sim.windowHeight*0.32

    ui.drawImage(goldIcon, vec2(basePosX-340*UIScale, basePosY), vec2(basePosX-300*UIScale, basePosY-40*UIScale))
    ui.drawImage(silverIcon, vec2(basePosX-110*UIScale, basePosY), vec2(basePosX-70*UIScale, basePosY-40*UIScale))
    ui.drawImage(bronzeIcon, vec2(basePosX+120*UIScale, basePosY), vec2(basePosX+160*UIScale, basePosY-40*UIScale))
    if UserConfigINI:get("SETTINGS", "show_timer", 1) == 1 then
        if SessionTimer < GoldTime then
            ui.drawImage(goldIcon, vec2(basePosX-110*UIScale, basePosY+70*UIScale), vec2(basePosX-70*UIScale, basePosY+30*UIScale))
        elseif SessionTimer < SilverTime then
            ui.drawImage(silverIcon, vec2(basePosX-110*UIScale, basePosY+70*UIScale), vec2(basePosX-70*UIScale, basePosY+30*UIScale))
        elseif SessionTimer < BronzeTime then
            ui.drawImage(bronzeIcon, vec2(basePosX-110*UIScale, basePosY+70*UIScale), vec2(basePosX-70*UIScale, basePosY+30*UIScale))
        else
            ui.drawImage(pepegaIcon, vec2(basePosX-110*UIScale, basePosY+70*UIScale), vec2(basePosX-70*UIScale, basePosY+30*UIScale))
        end
        ui.dwriteDrawText(string_formatTimeMiliseconds(SessionTimer) .. "", 20*UIScale, vec2(basePosX-60*UIScale, basePosY+35*UIScale), rgbm(1,1,1,1))
    end
    
    ui.dwriteDrawText(string_formatTimeMiliseconds(GoldTime) .. "", 20*UIScale, vec2(basePosX-290*UIScale, basePosY-35*UIScale), rgbm(1,1,1,1))
    ui.dwriteDrawText(string_formatTimeMiliseconds(SilverTime) .. "", 20*UIScale, vec2(basePosX-60*UIScale, basePosY-35*UIScale), rgbm(1,1,1,1))
    ui.dwriteDrawText(string_formatTimeMiliseconds(BronzeTime) .. "", 20*UIScale, vec2(basePosX+170*UIScale, basePosY-35*UIScale), rgbm(1,1,1,1))
    local row = 0
    if OffTrackTimer > 0 then
        ui.dwriteDrawText("GO BACK ONTO THE TRACK! " .. string_formatTimeMiliseconds(math.max(WarningTimeoutLimit*3000 + Sim.timeToSessionStart, (WarningTimeoutLimit-OffTrackTimer)*1000)) .. "", 20*UIScale, vec2(basePosX-280*UIScale, basePosY+(70+(row*30))*UIScale), rgbm(1,0,0,1))
        row = row + 1
    end
    if PassedSafetyCarTimer > 0 then
        ui.dwriteDrawText("GO BACK BEHIND THE SAFETY CAR! " .. string_formatTimeMiliseconds(math.max(WarningTimeoutLimit*3000 + Sim.timeToSessionStart, (WarningTimeoutLimit-PassedSafetyCarTimer)*1000)) .. "", 20*UIScale, vec2(basePosX-350*UIScale, basePosY+(70+(row*30))*UIScale), rgbm(1,0,0,1))
        row = row + 1
    end
    if LostSafetyCarTimer > 0 then
        ui.dwriteDrawText("YOU ARE LOSING THE SAFETY CAR! " .. string_formatTimeMiliseconds(math.max(WarningTimeoutLimit*3000 + Sim.timeToSessionStart, (WarningTimeoutLimit-LostSafetyCarTimer)*1000)) .. "", 20*UIScale, vec2(basePosX-350*UIScale, basePosY+(70+(row*30))*UIScale), rgbm(1,0,0,1))
        row = row + 1
    end
    ui.popDWriteFont()
    ui.endOutline(0, 1)
end

function RenderCheckpointGate(Checkpoint,Alpha)
    if CheckpointsList[Checkpoint] then
        local rightBoundaryPos = ac.trackCoordinateToWorld(vec3(TrackLimitsRange, 4, CheckpointsList[Checkpoint]))
        local leftBoundaryPos = ac.trackCoordinateToWorld(vec3(-TrackLimitsRange, 4, CheckpointsList[Checkpoint]))
        if Checkpoint%30 == 29 and RenderCheckpoints == 1 then

            render.rectangle(rightBoundaryPos, vec3(1,0,1), 0.5, 10, rgbm(1,1,0,Alpha))
            render.rectangle(rightBoundaryPos, vec3(-1,0,1), 0.5, 10, rgbm(1,1,0,Alpha))

            render.rectangle(leftBoundaryPos, vec3(1,0,1), 0.5, 10, rgbm(1,1,0,Alpha))
            render.rectangle(leftBoundaryPos, vec3(-1,0,1), 0.5, 10, rgbm(1,1,0,Alpha))

            local quad1 = vec3.new(rightBoundaryPos.x, rightBoundaryPos.y+4, rightBoundaryPos.z)
            local quad2 = vec3.new(rightBoundaryPos.x, rightBoundaryPos.y+2.5, rightBoundaryPos.z)
            local quad3 = vec3.new(leftBoundaryPos.x, leftBoundaryPos.y+2.5, leftBoundaryPos.z)
            local quad4 = vec3.new(leftBoundaryPos.x, leftBoundaryPos.y+4, leftBoundaryPos.z)

            render.quad(quad1, quad2, quad3, quad4, rgbm(1,1,0,Alpha))

        elseif RenderCones == 1 and Checkpoint < CurrentCheckpoint + 45 and Checkpoint > CurrentCheckpoint - 3 and CurrentCheckpoint ~= 0 then
            rightBoundaryPos.y = rightBoundaryPos.y -4.5
            leftBoundaryPos.y = leftBoundaryPos.y -4.5
            render.rectangle(rightBoundaryPos, vec3(1,0,1), 0.2, 1, rgbm(1,1,0,Alpha))
            render.rectangle(rightBoundaryPos, vec3(-1,0,1), 0.2, 1, rgbm(1,1,0,Alpha))

            render.rectangle(leftBoundaryPos, vec3(1,0,1), 0.2, 1, rgbm(1,1,0,Alpha))
            render.rectangle(leftBoundaryPos, vec3(-1,0,1), 0.2, 1, rgbm(1,1,0,Alpha))

        end
    end
end

function RenderFinishGate(Alpha)

    for i = 1,2 do
        if (i == 1 or (i == 2 and RequireBraking == 1)) and #CheckpointsList > 0 then
            local finishOffset = 0
            if i == 2 then 
                finishOffset = 0.005
            end
            local rightBoundaryPos = ac.trackCoordinateToWorld(vec3(TrackLimitsRange, 4, CheckpointsList[#CheckpointsList]+finishOffset))
            local leftBoundaryPos = ac.trackCoordinateToWorld(vec3(-TrackLimitsRange, 4, CheckpointsList[#CheckpointsList]+finishOffset))

            render.rectangle(rightBoundaryPos, vec3(1,0,1), 1, 10, rgbm(1,0,0,Alpha))
            render.rectangle(rightBoundaryPos, vec3(-1,0,1), 1, 10, rgbm(1,0,0,Alpha))

            render.rectangle(leftBoundaryPos, vec3(1,0,1), 1, 10, rgbm(1,0,0,Alpha))
            render.rectangle(leftBoundaryPos, vec3(-1,0,1), 1, 10, rgbm(1,0,0,Alpha))

            local quad1 = vec3.new(rightBoundaryPos.x, rightBoundaryPos.y+4, rightBoundaryPos.z)
            local quad2 = vec3.new(rightBoundaryPos.x, rightBoundaryPos.y+2.5, rightBoundaryPos.z)
            local quad3 = vec3.new(leftBoundaryPos.x, leftBoundaryPos.y+2.5, leftBoundaryPos.z)
            local quad4 = vec3.new(leftBoundaryPos.x, leftBoundaryPos.y+4, leftBoundaryPos.z)

            render.quad(quad1, quad2, quad3, quad4, rgbm(1,0,0,Alpha))

            local quad1 = vec3.new(rightBoundaryPos.x, rightBoundaryPos.y+4, rightBoundaryPos.z)
            local quad2 = vec3.new(rightBoundaryPos.x, rightBoundaryPos.y-5, rightBoundaryPos.z)
            local quad3 = vec3.new(leftBoundaryPos.x, leftBoundaryPos.y-5, leftBoundaryPos.z)
            local quad4 = vec3.new(leftBoundaryPos.x, leftBoundaryPos.y+4, leftBoundaryPos.z)

            render.quad(quad1, quad2, quad3, quad4, rgbm(1,0,0,Alpha*0.5))
        end
    end
end

function script.draw3D()
    render.setBlendMode(13)
    render.setCullMode(9)
    render.setDepthMode(4)
    if TrackLimitsType == "AILINE" then
        if CurrentCheckpoint > 0 and (RenderCheckpoints == 1 or RenderCones == 1) then
            for j = -30, 120 do
                RenderCheckpointGate(CurrentCheckpoint+j, math.min(1, 1))
            end
        end
    end

    if CurrentCheckpoint > #CheckpointsList - 500 or CurrentCheckpoint == 0 then
        RenderFinishGate(1)
    end
end