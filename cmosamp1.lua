--[[
name: CMOS Wasp Amp
description: Emulates the distorted CMOS amplifier sound from the EDP Wasp synth
author: William Ashley + ChatGPT
--]]

require "include/protoplug"

-- Configurable "CMOS-ish" distortion shaping parameters
local gain = 6.0       -- Pre-distortion gain
local shape = 1.4      -- Nonlinearity factor (higher = squarer)
local postGain = 0.4   -- Output gain compensation

-- Transfer function emulating inverter distortion
local function cmosCurve(x)
    -- A squashed tanh shape to emulate soft clipping, then logic flattening
    local y = math.tanh(x * shape)
    -- Optional: simulate logic level "snap"
    if y > 0.8 then return 1
    elseif y < -0.8 then return -1
    else return y end
end

function plugin.processBlock(samples, smax)
    for i = 0, smax do
        for ch = 0, 1 do
            local input = samples[ch][i]
            -- CMOS-like nonlinearity
            local out = cmosCurve(input * gain) * postGain
            samples[ch][i] = out
        end
    end
end
 