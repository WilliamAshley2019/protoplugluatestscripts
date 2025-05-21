--[[
name: Drum Enhancer FX
description: Adds punch, warmth, and stereo width to drum loops
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100

-- Parameters
local preGain = 1.2
local saturationAmount = 1.8
local attackBoost = 1.5
local envelopeDecay = 0.9995
local stereoWidth = 1.3
local lowpassCutoff = 14000 -- Hz
local lfoRate = 0.1
local lfoDepth = 3000

local envL = 0
local envR = 0

local lfoPhase = 0
local lfoInc = 2 * math.pi * lfoRate / sampleRate

-- Simple one-pole lowpass filter
local function makeFilter()
    return { last = 0 }
end
local filterL = makeFilter()
local filterR = makeFilter()

local function lowpass(input, cutoff, state)
    local rc = 1.0 / (cutoff * 2 * math.pi)
    local dt = 1.0 / sampleRate
    local alpha = dt / (rc + dt)
    state.last = state.last + alpha * (input - state.last)
    return state.last
end

-- Soft saturation
local function saturate(x)
    return math.tanh(x * saturationAmount)
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        local l = samples[0][i] * preGain
        local r = samples[1][i] * preGain

        -- Envelope follower
        local absL = math.abs(l)
        local absR = math.abs(r)
        envL = math.max(absL, envL * envelopeDecay)
        envR = math.max(absR, envR * envelopeDecay)

        -- Transient boost
        local transL = l * (1 + (envL * attackBoost))
        local transR = r * (1 + (envR * attackBoost))

        -- Saturation
        local satL = saturate(transL)
        local satR = saturate(transR)

        -- LFO for lowpass filter cutoff modulation
        lfoPhase = lfoPhase + lfoInc
        if lfoPhase > 2 * math.pi then lfoPhase = lfoPhase - 2 * math.pi end
        local cutoff = lowpassCutoff - math.sin(lfoPhase) * lfoDepth
        if cutoff < 2000 then cutoff = 2000 end

        -- Apply filter
        local fltL = lowpass(satL, cutoff, filterL)
        local fltR = lowpass(satR, cutoff, filterR)

        -- Stereo widen (mid/side trick)
        local mid = (fltL + fltR) * 0.5
        local side = (fltL - fltR) * 0.5 * stereoWidth
        local outL = mid + side
        local outR = mid - side

        -- Blend dry + processed
        samples[0][i] = (samples[0][i] + outL) * 0.5
        samples[1][i] = (samples[1][i] + outR) * 0.5
    end
end
