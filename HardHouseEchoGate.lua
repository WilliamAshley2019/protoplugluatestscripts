--[[
name: HardHouse Echo Gate
description: Rhythmic analog-style delay with gated feedback and chorus motion for UK Hard House
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local maxDelayTime = 1.0
local delayBufferSamples = math.floor(sampleRate * maxDelayTime)
local delayBufferL = {}
local delayBufferR = {}
for i = 1, delayBufferSamples do
    delayBufferL[i] = 0
    delayBufferR[i] = 0
end

local writePos = 1

-- Parameters
local delayTime = 0.375 -- seconds (~1/4 note at 160bpm)
local delaySamples = math.floor(delayTime * sampleRate)
local feedback = 0.45
local filterCutoff = 1200
local resonance = 0.6
local lfoRate = 0.25
local lfoDepth = 0.002
local amplitudeThreshold = 0.02 -- Gating threshold

-- Filter state
local function makeFilter()
    return { buf0 = 0, buf1 = 0 }
end
local filterL = makeFilter()
local filterR = makeFilter()

-- LFO
local lfoPhase = 0
local lfoInc = 2 * math.pi * lfoRate / sampleRate

-- Simple resonant LPF
local function resonantFilter(input, state)
    local f = 2 * math.sin(math.pi * filterCutoff / sampleRate)
    local fb = resonance + resonance / (1 - f)
    state.buf0 = state.buf0 + f * (input - state.buf0 + fb * (state.buf0 - state.buf1))
    state.buf1 = state.buf1 + f * (state.buf0 - state.buf1)
    return state.buf1
end

-- Soft clip
local function saturate(x)
    return math.tanh(x * 1.8)
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        -- Input
        local inputL = samples[0][i]
        local inputR = samples[1][i]
        local amp = math.max(math.abs(inputL), math.abs(inputR))

        -- LFO modulation
        lfoPhase = lfoPhase + lfoInc
        if lfoPhase > 2 * math.pi then lfoPhase = lfoPhase - 2 * math.pi end
        local mod = math.sin(lfoPhase) * lfoDepth
        local delayOffset = math.floor(mod * sampleRate)

        -- Read from delay
        local readPos = writePos - delaySamples + delayOffset
        if readPos < 1 then readPos = readPos + delayBufferSamples end

        local dl = delayBufferL[readPos] or 0
        local dr = delayBufferR[readPos] or 0

        -- Process delay output through filters
        local outL = resonantFilter(dl, filterL)
        local outR = resonantFilter(dr, filterR)

        -- Mix with dry signal
        samples[0][i] = inputL + outL * 0.7
        samples[1][i] = inputR + outR * 0.7

        -- Only feed into delay buffer if input is above threshold
        local feedL = 0
        local feedR = 0
        if amp > amplitudeThreshold then
            feedL = saturate(inputL + outL * feedback)
            feedR = saturate(inputR + outR * feedback)
        end

        delayBufferL[writePos] = feedL
        delayBufferR[writePos] = feedR

        -- Increment write position
        writePos = writePos + 1
        if writePos > delayBufferSamples then writePos = 1 end
    end
end
