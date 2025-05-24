--[[
name: CMOS 1176 RevA Amplifier
description: Emulates 1176 Rev A transistor amp tone with FET-like dynamic resistance and CMOS coloration
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100

-- Parameters
local gain = 4.0                 -- Input gain
local cmosShape = 1.5            -- CMOS soft clip shaping
local fetCompressRatio = 0.8     -- FET dynamic gain reduction
local postGain = 0.5             -- Output attenuation

-- Envelope for level-following
local env = 0
local attack = math.exp(-1.0 / (sampleRate * 0.001))  -- fast attack
local release = math.exp(-1.0 / (sampleRate * 0.1))   -- slow release

-- CMOS-style nonlinearity (soft asymmetric saturation)
local function cmosSaturate(x)
    return math.tanh(x * cmosShape)
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        local inputL = samples[0][i] * gain
        local inputR = samples[1][i] * gain

        -- Mono level follower
        local level = 0.5 * (math.abs(inputL) + math.abs(inputR))
        if level > env then
            env = attack * env + (1 - attack) * level
        else
            env = release * env + (1 - release) * level
        end

        -- FET-style gain reduction: lower gain as input gets louder
        local fetGain = 1.0 / (1.0 + env * fetCompressRatio)

        -- CMOS saturation applied after gain control
        local outL = cmosSaturate(inputL * fetGain) * postGain
        local outR = cmosSaturate(inputR * fetGain) * postGain

        samples[0][i] = outL
        samples[1][i] = outR
    end
end
