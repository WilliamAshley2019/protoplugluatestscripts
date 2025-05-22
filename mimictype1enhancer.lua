--[[
name: Dolby A Trick Enhancer
description: Simulates the Dolby A encoding stage for dynamic air/presence enhancement
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local makeupGain = 1.0

-- Basic band split freqs (using simple first-order filters)
local splitFreqs = { 1000, 3000, 9000 } -- Only upper 2 bands used

-- Per-band filters (simple first-order HP/LP)
local function makeFilter()
    return { lp = 0, hp = 0 }
end

local function updateFilters(f, x, filt)
    local RC = 1.0 / (2 * math.pi * f)
    local alpha = 1.0 / (1.0 + RC * sampleRate)

    filt.lp = filt.lp + alpha * (x - filt.lp)
    filt.hp = x - filt.lp
end

-- Dynamic gain computation per band
local function computeGain(level, threshold, ratio)
    if level < threshold then
        local over = threshold - level
        return math.pow(10, over * (1 - 1/ratio) / 20)
    else
        return 1.0
    end
end

local bandFilters = { makeFilter(), makeFilter(), makeFilter() }

local levelSmooth = {0, 0, 0}
local smoothing = 0.99
local thresholdDB = -40
local ratio = 4.0

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        local input = (samples[0][i] + samples[1][i]) * 0.5

        -- Band splitting
        local b = {}
        updateFilters(splitFreqs[1], input, bandFilters[1])
        updateFilters(splitFreqs[2], bandFilters[1].hp, bandFilters[2])
        updateFilters(splitFreqs[3], bandFilters[2].hp, bandFilters[3])

        b[1] = bandFilters[1].hp        -- Mid band (skipped in final mix)
        b[2] = bandFilters[2].hp        -- Upper mids
        b[3] = bandFilters[3].hp        -- "Air" band

        -- Compute per-band dynamics
        local gains = {}
        for j = 2, 3 do -- Only apply to top 2 bands
            local level = math.abs(b[j])
            levelSmooth[j] = levelSmooth[j] * smoothing + (1 - smoothing) * level
            local levelDB = 20 * math.log(levelSmooth[j] + 1e-6) / math.log(10)
            gains[j] = computeGain(levelDB, thresholdDB, ratio)
        end

        -- Enhance
        local enhanced = input
        for j = 2, 3 do
            enhanced = enhanced + b[j] * (gains[j] - 1)
        end

        -- Final gain
        enhanced = enhanced * makeupGain

        samples[0][i] = samples[0][i] + enhanced
        samples[1][i] = samples[1][i] + enhanced
    end
end
