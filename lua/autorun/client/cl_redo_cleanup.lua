--[[------------------------------------------------
Network a player's cleanup event
------------------------------------------------]]--

-- Create the function
local function onPlayerCleanup( name )

	-- Start the network message
	net.Start( "onPlayerCleanup" )

	-- Write the cleanup name
	net.WriteString( name )

	-- Send it to the server
	net.SendToServer()

end

-- Register the hook
hook.Add( "OnCleanup", "onPlayerCleanup", onPlayerCleanup ) -- Lmao this isn't even documented on the wiki
