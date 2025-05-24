require "include/protoplug"

local sampleRate = 44100
local env = 0
local attack = 0
local release = 0

plugin.parameters = {
    { name = "Input Gain", min = 1, max = 10, default = 4 },
    { name = "Saturation", min = 0.1, max = 5.0, default = 1.5 },
    { name = "FET Compress", min = 0.1, max = 2.0, default = 0.8 },
    { name = "Output Gain", min = 0.1, max = 2.0, default = 0.5 }
}

function plugin.init()
    sampleRate = plugin.sampleRate or 44100
    attack = math.exp(-1.0 / (sampleRate * 0.001))   -- 1 ms attack
    release = math.exp(-1.0 / (sampleRate * 0.1))    -- 100 ms release
end

local function pushPullCMOS(x, shape)
    local vPos = 1.0
    local vNeg = -0.8
    return math.max(vNeg, math.min(vPos, x - (x^3) / (3 * shape)))
end


function plugin.processBlock(samples, smax)
    local inGain = plugin.getParameter(1)
    local shape = plugin.getParameter(2)
    local compRatio = plugin.getParameter(3)
    local outGain = plugin.getParameter(4)

    -- Debug print
    print(string.format("InGain=%.2f Saturation=%.2f FET=%.2f OutGain=%.2f", inGain, shape, compRatio, outGain))

    for i = 0, smax do
        local inputL = samples[0][i] * inGain
        local inputR = samples[1][i] * inGain

        local level = 0.5 * (math.abs(inputL) + math.abs(inputR))
        if level > env then
            env = attack * env + (1 - attack) * level
        else
            env = release * env + (1 - release) * level
        end

        local fetGain = 1.0 / (1.0 + env * compRatio)

        local outL = pushPullCMOS(inputL * fetGain, shape)
        local outR = pushPullCMOS(inputR * fetGain, shape)

        samples[0][i] = outL * outGain
        samples[1][i] = outR * outGain
    end
end








