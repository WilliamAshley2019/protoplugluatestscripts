--[[
name: SID Pulse Synth
description: A gritty chiptune-style pulsewave synth with PWM and bitcrush
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local releaseTime = 0.2
local releaseSamples = releaseTime * sampleRate

-- Pulse width modulation speed and depth
local pwmSpeed = 0.5 -- Hz
local pwmDepth = 0.4 -- range: 0..0.5

-- Bitcrush resolution
local crushBits = 4
local crushLevels = 2 ^ crushBits

polyGen.initTracks(1) -- monophonic for this patch

function polyGen.VTrack:init()
    self.phase = 0
    self.releasePos = releaseSamples
    self.noteIsOn = false
    self.pwmPhase = 0
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    local amp = 1
    local freq = self.noteFreq * 2 * math.pi
    local pwmPhaseInc = pwmSpeed * 2 * math.pi / sampleRate

    for i = 0, smax do
        if not self.noteIsOn then
            if self.releasePos >= releaseSamples then break end
            amp = 1 - (self.releasePos / releaseSamples)
            self.releasePos = self.releasePos + 1
        end

        -- Simple LFO pulse width modulation
        self.pwmPhase = self.pwmPhase + pwmPhaseInc
        if self.pwmPhase > 2 * math.pi then self.pwmPhase = self.pwmPhase - 2 * math.pi end
        local pw = 0.5 + math.sin(self.pwmPhase) * pwmDepth -- pulse width between 0.1 and 0.9

        -- Hard-edged pulse wave
        local value = (self.phase / (2 * math.pi)) % 1
        local sample = (value < pw) and 1 or -1

        -- Bitcrush
        sample = math.floor(sample * crushLevels) / crushLevels
        sample = sample * amp * 0.3

        samples[0][i] = samples[0][i] + sample
        samples[1][i] = samples[1][i] + sample

        -- Increment and wrap phase
        self.phase = self.phase + freq
        if self.phase > 2 * math.pi then self.phase = self.phase - 2 * math.pi end
    end
end

function polyGen.VTrack:noteOn(note, vel, ev)
    self.phase = 0
    self.releasePos = 0
    self.noteIsOn = true
end

function polyGen.VTrack:noteOff(note, ev)
    self.noteIsOn = false
    self.releasePos = 0
end
