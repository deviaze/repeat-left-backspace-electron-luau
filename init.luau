--!strict
local process = require("@lune/process")
local task = require("@lune/task")

local REPEAT_AFTER = 0.5 -- seconds to hold down left backspace before starts repeating
local REPEAT_DELAY = 0.025 -- seconds between each repeat

local CAPSLOCK_KEYCODE = 58
local BACKSPACE_KEYCODE = 14

local function shell(cmd: string): { ok: true, out: string } | { ok: false,  err: string }
	local result = process.exec(cmd, nil, { shell = true })
	if result.ok then
		return {
			ok = true,
			out = result.stdout,
		}
	else
		return {
			ok = false,
			err = result.stderr
		}
	end
end

if not shell("ydotool --help").ok then
	error("Missing ydotool; please install it from your package manager!")
elseif not shell("libinput --help").ok then
	error("Missing libinput; please install it from your package manager!")
end

process.create("ydotoold", nil, { shell = true })

local is_pressed = false
local press_down_time = os.clock()
local send_time = os.clock()
local release_time = os.clock()

local listener_handle = process.create("libinput debug-events --show-keycodes", nil, { shell = true })
task.spawn(function()
	while true do 
		local now = os.clock()
		local line: string? = listener_handle.stdout:read(124)
		if line then
			if not is_pressed and line:match("CAPSLOCK") and line:match("pressed") then
				if now - send_time > 0.05 then -- try not to intercept our own keystrokes 
					press_down_time = now
					send_time = now
					is_pressed = true
				end
			elseif is_pressed and line:match("CAPSLOCK") and line:match("released") then
				if now - send_time > 0.05 then
					release_time = now
					is_pressed = false
				end
			elseif line:match("CAPS") then
				print("weird buffer size cutoff thing")
			end
		else
			error(listener_handle.stderr:read())
		end
	
	end
end)

while task.wait(REPEAT_DELAY) do
	if is_pressed then
		local now = os.clock()
		if (now - press_down_time) > REPEAT_AFTER then
			shell(`ydotool key {BACKSPACE_KEYCODE}:1 {BACKSPACE_KEYCODE}:0`)
		end
	end
end