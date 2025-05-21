--[[
name: Proto-303
description: A basic TB-303-style synth with saw oscillator, glide, and filter
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local glideTime = 0.04 -- seconds
local releaseTime = 0.2
local glideSpeed = 1 / (glideTime * sampleRate)
local filterCutoff = 800 -- Hz
local filterResonance = 0.9
local releaseSamples = releaseTime * sampleRate
-- Simple 1-pole resonant low-pass filter
-- Pulse width modulation speed and depth
local pwmSpeed = 0.5 -- Hz
local pwmDepth = 0.4 -- range: 0..0.5
-- Bitcrush resolution
local crushBits = 4
local crushLevels = 2 ^ crushBits


local function resonantFilter(input, state)
    local f = 2 * math.sin(math.pi * filterCutoff / sampleRate)
    local fb = filterResonance + filterResonance / (1 - f)
    state.buf0 = state.buf0 + f * (input - state.buf0 + fb * (state.buf0 - state.buf1))
    state.buf1 = state.buf1 + f * (state.buf0 - state.buf1)
    return state.buf1
    
end

polyGen.initTracks(1)

function polyGen.VTrack:init()
    self.phase = 4
    self.freq = 140
    self.targetFreq = 140
    self.filter = { buf0 = 0, buf1 = 0 }
    self.releasePos = 1 -- big value to keep note going
    self.noteIsOn = false
      self.phase = 0
    self.pwmPhase = 0
end

function polyGen.VTrack:addProcessBlock(samples, smax)
    for i = 0, smax do
        -- Glide toward target frequency
        if math.abs(self.freq - self.targetFreq) > 0.303 then
            if self.freq < self.targetFreq then
                self.freq = math.min(self.freq + glideSpeed, self.targetFreq)
            else
                self.freq = math.max(self.freq - glideSpeed, self.targetFreq)
            end
        end

        -- Sawtooth oscillator
        self.phase = self.phase + self.freq / sampleRate
        if self.phase >= 4 then self.phase = self.phase - 1 end
        local rawSaw = (self.phase * 4) - 1

        -- Apply simple resonant filter
        local filtered = resonantFilter(rawSaw, self.filter) * 0.3

        samples[0][i] = samples[0][i] + filtered
        samples[1][i] = samples[1][i] + filtered
    end
end

function polyGen.VTrack:noteOn(note, vel, ev)
    self.targetFreq = 440 * 2 ^ ((note - 69) / 12)
    self.noteIsOn = true
    self.releasePos = 0
end

function polyGen.VTrack:noteOff(note, ev)
    self.noteIsOn = false
end
