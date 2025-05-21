--[[
name: Broadcast Vocal Compressor
description: Voice compressor modeled on classic radio chain behavior
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local threshold = -12.0  -- dB
local ratio = 6.0
local attack = 0.005     -- seconds
local release = 0.05     -- seconds
local makeupGain = 8.0   -- dB
local sampleRate = 44100

local attackCoeff = math.exp(-1.0 / (sampleRate * attack))
local releaseCoeff = math.exp(-1.0 / (sampleRate * release))

local gainReduction = 0

local function dBToLinear(db)
    return math.pow(10, db / 20)
end

local function linearToDB(linear)
    return 20 * math.log(linear) / math.log(10)
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        local input = (samples[0][i] + samples[1][i]) * 0.5

        local inputLevel = math.abs(input)
        if inputLevel < 1e-6 then inputLevel = 1e-6 end

        local inputDB = linearToDB(inputLevel)

        local overThreshold = inputDB - threshold
        local desiredReduction = 0
        if overThreshold > 0 then
            desiredReduction = overThreshold - (overThreshold / ratio)
        end

        -- smooth gain change
        if desiredReduction > gainReduction then
            gainReduction = gainReduction * attackCoeff + desiredReduction * (1 - attackCoeff)
        else
            gainReduction = gainReduction * releaseCoeff + desiredReduction * (1 - releaseCoeff)
        end

        local gain = dBToLinear(-gainReduction + makeupGain)

        -- Apply gain
        samples[0][i] = samples[0][i] * gain
        samples[1][i] = samples[1][i] * gain
    end
end
