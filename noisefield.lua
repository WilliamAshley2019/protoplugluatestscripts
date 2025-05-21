--[[
name: UK Hard House Space Delay
description: Analog-style delay + chorus with controlled feedback, phase inversion, and saturation
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local maxDelayTime = 1.5 -- seconds
local delayBufferSamples = math.floor(sampleRate * maxDelayTime)
local delayBufferL = {}
local delayBufferR = {}
for i = 1, delayBufferSamples do
    delayBufferL[i] = 0
    delayBufferR[i] = 0
end

local writePos = 1

-- Parameters
local delayTime = 0.38 -- seconds
local delaySamples = math.floor(delayTime * sampleRate)
local feedback = 0.35
local feedbackGrowthRate = 0.00001
local maxFeedback = 0.75
local filterCutoff = 1400
local resonance = 0.7
local lfoRate = 0.3
local lfoDepth = 0.003
local phaseFlipThreshold = 0.65

-- Filter state
local function makeFilter()
    return { buf0 = 0, buf1 = 0 }
end
local filterL = makeFilter()
local filterR = makeFilter()

-- LFO
local lfoPhase = 0
local lfoInc = 2 * math.pi * lfoRate / sampleRate

local function resonantFilter(input, state)
    local f = 2 * math.sin(math.pi * filterCutoff / sampleRate)
    local fb = resonance + resonance / (1 - f)
    state.buf0 = state.buf0 + f * (input - state.buf0 + fb * (state.buf0 - state.buf1))
    state.buf1 = state.buf1 + f * (state.buf0 - state.buf1)
    return state.buf1
end

-- Soft clip
local function saturate(x)
    return math.tanh(x * 1.5)
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        -- LFO modulation for subtle chorus
        lfoPhase = lfoPhase + lfoInc
        if lfoPhase > 2 * math.pi then lfoPhase = lfoPhase - 2 * math.pi end
        local mod = math.sin(lfoPhase) * lfoDepth
        local delayOffset = math.floor(mod * sampleRate)

        local readPos = writePos - delaySamples + delayOffset
        if readPos < 1 then readPos = readPos + delayBufferSamples end

        local dl = delayBufferL[readPos] or 0
        local dr = delayBufferR[readPos] or 0

        -- Feedback phase inversion near entropy threshold
        local feedbackSign = 1
        if math.abs(dl) > phaseFlipThreshold or math.abs(dr) > phaseFlipThreshold then
            feedbackSign = -1
        end

        -- Filter and saturate
        local filteredL = resonantFilter(dl, filterL)
        local filteredR = resonantFilter(dr, filterR)
        filteredL = saturate(filteredL)
        filteredR = saturate(filteredR)

        -- Mix into output
        local inputL = samples[0][i]
        local inputR = samples[1][i]
        samples[0][i] = inputL + filteredL * 0.7
        samples[1][i] = inputR + filteredR * 0.7

        -- Write into delay buffer
        local nextFeedbackL = saturate(inputL + filteredL * feedback * feedbackSign)
        local nextFeedbackR = saturate(inputR + filteredR * feedback * feedbackSign)

        delayBufferL[writePos] = nextFeedbackL
        delayBufferR[writePos] = nextFeedbackR

        -- Increment feedback slowly (organic swell)
        feedback = math.min(feedback + feedbackGrowthRate, maxFeedback)

        -- Wrap write position
        writePos = writePos + 1
        if writePos > delayBufferSamples then writePos = 1 end
    end
end
