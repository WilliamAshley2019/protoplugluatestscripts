--[[
name: sine organ smooth
description: A sinewave organ with clickless attack/release.
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local attackTime = 0.0  05 -- seconds
local releaseTime = 0.1 -- seconds

local attackSamples = sampleRate * attackTime
local releaseSamples = sampleRate * releaseTime

polyGen.initTracks(8)

function polyGen.VTrack:init()
    self.phase = 0
    self.releasePos = releaseSamples
    self.attackPos = attackSamples
    self.noteIsOn = false
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    local amp = 0
    local freq = self.noteFreq * 2 * math.pi / sampleRate

    for i = 0, smax do
        if self.noteIsOn then
            if self.attackPos > 0 then
                amp = 1 - (self.attackPos / attackSamples)
                self.attackPos = self.attackPos - 1
            else
                amp = 1
            end
        else
            if self.releasePos < releaseSamples then
                amp = 1 - (self.releasePos / releaseSamples)
                self.releasePos = self.releasePos + 1
            else
                break -- voice is fully released
            end
        end

        self.phase = self.phase + freq
        if self.phase > 2 * math.pi then
            self.phase = self.phase - 2 * math.pi
        end

        local sample = math.sin(self.phase) * amp * 0.3
        samples[0][i] = samples[0][i] + sample -- left
        samples[1][i] = samples[1][i] + sample -- right
    end
end

function polyGen.VTrack:noteOn(note, vel, ev)
    self.noteIsOn = true
    self.attackPos = attackSamples
    self.releasePos = 0
    -- keep phase where it is to avoid hard reset clicks
end

function polyGen.VTrack:noteOff(note, ev)
    self.noteIsOn = false
    self.releasePos = 0
end
