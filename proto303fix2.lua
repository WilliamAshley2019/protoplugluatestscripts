--[[
name: Proto-303 Fixed Glide
description: TB-303-style synth with PWM, glide, bitcrush, and proper release
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local glideTime = 0.04 -- seconds
local glideSpeed = 1 / (glideTime * sampleRate)
local filterCutoff = 800
local filterResonance = 0.9
local releaseTime = 0.2
local releaseSamples = math.floor(releaseTime * sampleRate)

-- Simple resonant low-pass filter
local function resonantFilter(input, state)
    local f = 2 * math.sin(math.pi * filterCutoff / sampleRate)
    local fb = filterResonance + filterResonance / (1 - f)
    state.buf0 = state.buf0 + f * (input - state.buf0 + fb * (state.buf0 - state.buf1))
    state.buf1 = state.buf1 + f * (state.buf0 - state.buf1)
    return state.buf1
end

-- Pulse width modulation speed and depth
local pwmSpeed = 0.5 -- Hz
local pwmDepth = 0.4 -- range: 0..0.5

-- Bitcrush resolution
local crushBits = 4
local crushLevels = 2 ^ crushBits

polyGen.initTracks(1) -- monophonic for this patch

function polyGen.VTrack:init()
    self.phase = 0
    self.noteFreq = 440
    self.targetFreq = 440
    self.filter = { buf0 = 0, buf1 = 0 }

    self.releasePos = releaseSamples
    self.noteIsOn = false
    self.pwmPhase = 0
    self.isSliding = false
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    local amp = 1
    local pwmPhaseInc = pwmSpeed * 2 * math.pi / sampleRate
    local freq = self.noteFreq * 2 * math.pi / sampleRate

    for i = 0, smax do
        if not self.noteIsOn then
            if self.releasePos >= releaseSamples then break end
            amp = 1 - (self.releasePos / releaseSamples)
            self.releasePos = self.releasePos + 1
        end

        -- LFO for PWM
        self.pwmPhase = self.pwmPhase + pwmPhaseInc
        if self.pwmPhase > 2 * math.pi then self.pwmPhase = self.pwmPhase - 2 * math.pi end
        local pw = 0.5 + math.sin(self.pwmPhase) * pwmDepth

        -- Pulse wave
        local value = (self.phase / (2 * math.pi)) % 1
        local sample = (value < pw) and 1 or -1

        -- Bitcrush
        sample = math.floor(sample * crushLevels) / crushLevels
        sample = sample * amp * 0.3

        samples[0][i] = samples[0][i] + sample
        samples[1][i] = samples[1][i] + sample

        self.phase = self.phase + freq
        if self.phase > 2 * math.pi then self.phase = self.phase - 2 * math.pi end
    end
end

function polyGen.VTrack:noteOn(note, vel, ev)
    self.phase = 0
    self.releasePos = 0
    self.noteIsOn = true
    self.noteFreq = 440 * 2 ^ ((note - 69) / 12)
end

function polyGen.VTrack:noteOff(note, ev)
    self.noteIsOn = false
    self.releasePos = 0
end
