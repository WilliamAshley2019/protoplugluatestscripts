--[[
name: Expand FX
description: Increases gain of quiet signals to bring out transients and detail
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100

-- Expansion parameters
local thresholdDB = -40    -- Anything below this gets expanded
local ratio = 1.5          -- Expansion ratio: 1.5 = subtle, 2.0 = stronger
local attackTime = 0.005   -- seconds
local releaseTime = 0.08   -- seconds
local makeupGainDB = 3.0   -- Output boost

-- Envelope smoothing
local attackCoeff = math.exp(-1.0 / (sampleRate * attackTime))
local releaseCoeff = math.exp(-1.0 / (sampleRate * releaseTime))

-- State
local gainDB = 0

local function linearToDB(x)
    return 20 * math.log(math.max(x, 1e-6)) / math.log(10)
end

local function dBToLinear(db)
    return math.pow(10, db / 20)
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        -- Mono input for analysis
        local input = (samples[0][i] + samples[1][i]) * 0.5
        local absInput = math.abs(input)

        -- Convert level to dB
        local levelDB = linearToDB(absInput)

        -- Expansion logic
        local targetGainDB = 0
        if levelDB < thresholdDB then
            local diff = thresholdDB - levelDB
            targetGainDB = diff * (ratio - 1)
        end

        -- Envelope smoothing (fast attack, slow release)
        if targetGainDB > gainDB then
            gainDB = attackCoeff * gainDB + (1 - attackCoeff) * targetGainDB
        else
            gainDB = releaseCoeff * gainDB + (1 - releaseCoeff) * targetGainDB
        end

        local gain = dBToLinear(gainDB + makeupGainDB)

        -- Apply to stereo channels
        samples[0][i] = samples[0][i] * gain
        samples[1][i] = samples[1][i] * gain
    end
end
