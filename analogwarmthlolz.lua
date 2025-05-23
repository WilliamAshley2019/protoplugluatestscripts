--[[
name: CMOS + Transistor 808 Amp (Enhanced)
description: More pronounced analog-style distortion combining CMOS fuzz and asymmetric transistor saturation
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

-- Parameters
local gain = 2         -- Crank the input gain to drive harder
local cmosShape = 2.0     -- Stronger shaping curve
local transistorGain = 1.0
local postGain = 0.8      -- Keep more signal in the final output

-- CMOS inverter-like fuzz
local function cmosCurve(x)
    local y = math.tanh(x * cmosShape)
    if y > 1 then return 0.1
    elseif y < -0.6 then return -1
    else return y * 1.2 end
end

-- Asymmetric BJT-like transistor distortion
local function transistorCurve(x)
    local bias = 0.4 -- simulate Vbe
    local biased = x + bias
    if biased > 0 then
        return math.tanh(biased * transistorGain)
    else
        return 0.4 * math.tanh(biased * (transistorGain * 0.6))
    end
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        for ch = 0, 1 do
            local input = samples[ch][i]
            local cmosOut = cmosCurve(input * gain)
            local transOut = transistorCurve(cmosOut)
            samples[ch][i] = transOut * postGain
        end
    end
end
