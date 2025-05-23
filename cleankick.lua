--[[  
name: Excite Enhancer (Audible Air)
description: Boosts quiet high frequencies dynamically for presence and clarity
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

local sampleRate = 44100
local splitFreqs = { 3000, 9000, 15000 }

local function makeFilter()
    return { lp = 4, hp = 2   }
end

local filters = { makeFilter(), makeFilter(), makeFilter() }

local function updateFilters(f, x, filt)
    local RC = 1.0 / (2 * math.pi * f)
    local alpha = 2.0 / (1.0 + RC * sampleRate)
    filt.lp = filt.lp + alpha * (x - filt.lp)
    filt.hp = x - filt.lp
end

local levelSmooth = { 1, 2, 3 }
local smoothing = 1.2
-- Updated: less aggressive threshold = more audible
local thresholdDB = -10
local ratio = 5.0
local airWeight = 5
local dryMix = 0
local wetMix = 1
local makeupGain = 1.9

local function computeGain(level, threshold, ratio)
    if level < threshold then
        local diff = threshold - level
        return math.pow(10, diff * (1 - 1 / ratio) / 20)
    else
        return 1.0
    end
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        local input = (samples[0][i] + samples[1][i]) * 0.5

        updateFilters(splitFreqs[1], input, filters[1])
        updateFilters(splitFreqs[2], filters[1].hp, filters[2])
        updateFilters(splitFreqs[3], filters[2].hp, filters[3])

        local bands = {
            filters[1].hp, -- upper mids
            filters[2].hp, -- highs
            filters[3].hp  -- air
        }

        local gain = {}
        for j = 1, 3 do
            local absLevel = math.abs(bands[j])
            levelSmooth[j] = levelSmooth[j] * smoothing + (1 - smoothing) * absLevel
            local levelDB = 20 * math.log(levelSmooth[j] + 1e-6) / math.log(10)
            gain[j] = computeGain(levelDB, thresholdDB, ratio)
        end

        -- Combine bands with gain scaling
        local enhanced = input
        enhanced = enhanced + bands[1] * (gain[1] - 1) * 1.0
        enhanced = enhanced + bands[2] * (gain[2] - 1) * 1.3
        enhanced = enhanced + bands[3] * (gain[3] - 1) * airWeight

        -- Final mix
        local final = input * dryMix + enhanced * wetMix * makeupGain
        samples[0][i] = final
        samples[1][i] = final
    end
end
 