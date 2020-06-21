--[[------------------------------------------------
Notifications for successful redo's
------------------------------------------------]]--

-- Create the function
local function redoNotification( length )

	-- Store the received details about the successful redo
	local undoName = net.ReadString()
	local redoCustomText = net.ReadString()

	-- First try to call the hook to see if anyone is overriding it
	local shouldSuppress = hook.Run( "OnRedo", undoName, redoCustomText )

	-- If we haven't been overridden
	if shouldSuppress ~= false then

		-- Show a notification in the same style as the undo notification
		notification.AddLegacy( redoCustomText, NOTIFY_UNDO, 2 )

		-- Play the same sound as the undo notification
		surface.PlaySound( "buttons/button15.wav" )

	end

end

-- Register the network message receiver
net.Receive( "redoNotification", redoNotification )
