require "include/protoplug"

local sampleRate = 44100
local env = 0

plugin.parameters = {
  { name = "Input Gain", min = 0, max = 10, default = 4 },
  { name = "Output Gain", min = 0.1, max = 2.0, default = 1 }
}

local attackCoeff
local releaseCoeff

function plugin.init()
  sampleRate = plugin.sampleRate or 44100
  -- 4:1 ratio typical attack/release values
  attackCoeff = math.exp(-1.0 / (sampleRate * 0.0007))   -- 700 μs attack
  releaseCoeff = math.exp(-1.0 / (sampleRate * 0.8))     -- 800 ms release
end

function plugin.processBlock(samples, smax)
  local inputGain = plugin.getParameter(1)
  local outputGain = plugin.getParameter(2)

  local ratio = 4

  for i = 0, smax do
    local inL = samples[0][i] * inputGain
    local inR = samples[1][i] * inputGain

    local level = 0.5 * (math.abs(inL) + math.abs(inR))

    if level > env then
      env = attackCoeff * env + (1 - attackCoeff) * level
    else
      env = releaseCoeff * env + (1 - releaseCoeff) * level
    end

    local gainReduction = 1 / (1 + env * (ratio - 1))

    samples[0][i] = inL * gainReduction * outputGain
    samples[1][i] = inR * gainReduction * outputGain
  end
end
