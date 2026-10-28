local log = { enabled = true, path = nil, fh = nil }

function log.init(root, enabled)
	log.enabled = enabled
	if not enabled then return end
	os.execute('mkdir "' .. root .. 'logs" 2>nul')
	log.path = root .. "logs\\" .. (os.getenv("CIPHER_LOGNAME") or "cipher") .. ".log"
	log.fh = io.open(log.path, "w")
end

function log.write(fmt, ...)
	if not log.fh then return end
	local ok, msg = pcall(string.format, fmt, ...)
	log.fh:write(string.format("[%07d] %s\n", emu.framecount(), ok and msg or tostring(fmt)))
	log.fh:flush()
end

function log.close()
	if log.fh then log.fh:close() log.fh = nil end
end

return log
