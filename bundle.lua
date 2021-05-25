local shell = function(command)
  return os.execute(command .. ' 2> /dev/null')
end

local quirks = {
  ['adafruit_busdevice'] = 'adafruit_bus_device',
  ['adafruit_adafruitio'] = 'adafruit_io',
  ['Adafruit_CircuitPython_ESP32SPI'] = 'adafruit_esp32spi',
  ['adafruit_pypixelbuf200'] = 'adafruit_pypixelbuf',
  ['adafruit_bitmap-font'] = 'adafruit_bitmap_font',
  ['adafruit_display-text'] = 'adafruit_display_text'
}

local config = arg[1]
local bundle_path = arg[2]
local output_path = arg[3]

if not (config and bundle_path and output_path) then
  print('usage: lua bundle.lua <config> <bundle_path> <output_path>')
  os.exit(-1)
end

local done = {}
local todo = {}
local requirements = {}

local libs = loadfile(config)().libs

for _, lib in ipairs(libs) do
  table.insert(todo, lib)
  table.insert(requirements, lib)
end

while #todo > 0 do
  local current = table.remove(todo)
  done[current] = true

  local ok, lines = pcall(function()
    return io.lines(bundle_path .. '/requirements/' .. current .. '/requirements.txt')
  end)

  if ok then
    for line in lines do
      if not line:lower():match('blinka') and line:match('^[^#].+$') then
        local dependency = line:gsub('%-circuitpython%-', '_'):gsub('[^a-zA-Z0-9%-_]', '')
        dependency = quirks[dependency] or dependency

        if not done[dependency] then
          if dependency:match('busdevice') then print('000000000000000000000000000000000000000000000000') end
          table.insert(todo, dependency)
          table.insert(requirements, dependency)
        end
      end
    end
  end
end

assert(shell('rm -rf ' .. output_path))
assert(shell('mkdir -p ' .. output_path))

local bundled = {}
local skipped = {}

for _, requirement in ipairs(requirements) do
  local copy_lib_dir = shell('cp -r ' .. bundle_path .. '/lib/' .. requirement .. ' ' .. output_path)
  local copy_lib = shell('cp ' .. bundle_path .. '/lib/' .. requirement .. '.mpy ' .. output_path)
  local copy_reduced_lib = shell('cp ' .. bundle_path .. '/lib/' .. requirement:gsub('adafruit_', '') .. '.mpy ' .. output_path)

  if copy_lib_dir or copy_lib or copy_reduced_lib then
    table.insert(bundled, requirement)
  else
    table.insert(skipped, requirement)
  end
end

if #bundled > 0 then
  print('\nBundled:')
  for _, v in ipairs(bundled) do print('- ' .. v) end
end

if #skipped > 0 then
  print('\nSkipped:')
  for _, v in ipairs(skipped) do print('- ' .. v) end
end
