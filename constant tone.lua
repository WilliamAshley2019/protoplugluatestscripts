--[[
name: Nukleuz Hoover Lead
description: UK Hard House synth inspired by Nukleuz label
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local bpm = 150
local lfoSpeed = 5.0 -- Hz
local lfoDepth = 0.3
local detune = 0.02
local filterCutoff = 1200
local filterResonance = 0.8

-- LFO for PWM
local lfoPhase = 0
local lfoInc = 2 * math.pi * lfoSpeed / sampleRate

-- Simple resonant low-pass filter
local function resonantFilter(input, state)
    local f = 2 * math.sin(math.pi * filterCutoff / sampleRate)
    local fb = filterResonance + filterResonance / (1 - f)
    state.buf0 = state.buf0 + f * (input - state.buf0 + fb * (state.buf0 - state.buf1))
    state.buf1 = state.buf1 + f * (state.buf0 - state.buf1)
    return state.buf1
end

polyGen.initTracks(1)

function polyGen.VTrack:init()
    self.phase = 0
    self.freq = 440
    self.filter = { buf0 = 0, buf1 = 0 }
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    for i = 0, smax do
        -- LFO for PWM
        lfoPhase = lfoPhase + lfoInc
        if lfoPhase > 2 * math.pi then lfoPhase = lfoPhase - 2 * math.pi end
        local pwm = 0.5 + math.sin(lfoPhase) * lfoDepth

        -- Oscillators
        local saw = math.sin(self.phase)
        local sawDetuned = math.sin(self.phase + detune)

        -- Combine oscillators
        local sample = (saw + sawDetuned) * 0.5

        -- Apply filter
        sample = resonantFilter(sample, self.filter)

        -- Output
        samples[0][i] = samples[0][i] + sample * 0.5
        samples[1][i] = samples[1][i] + sample * 0.5

        -- Increment phase
        self.phase = self.phase + 2 * math.pi * self.freq / sampleRate
        if self.phase > 2 * math.pi then self.phase = self.phase - 2 * math.pi end
    end
end

function polyGen.VTrack:noteOn(note, vel, ev)
    self.freq = 440 * 2 ^ ((note - 69) / 12)
end

function polyGen.VTrack:noteOff(note, ev)
    -- No action needed for this simple synth
end
 