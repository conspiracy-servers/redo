--[[------------------------------------------------
Receive notification network message
------------------------------------------------]]--

net.Receive( "Redo", function( length )

	-- Store the received details about the successful redo
	local undoName = net.ReadString()
	local redoCustomText = net.ReadString()

	-- If we don't have any custom redo text
	if ( redoCustomText == "" ) then

		-- Set the custom redo text to nil, so it behaves like GM:OnUndo
		redoCustomText = nil

	end

	-- First try to call the hook to see if anyone is overriding it
	local shouldSuppress = hook.Run( "OnRedo", undoName, redoCustomText )

	-- If we haven't been overridden
	if ( shouldSuppress != false ) then

		-- Work out which text to display in the notification
		local text = ( redoCustomText != nil and redoCustomText or "Redone " .. undoName )

		-- Show a notification in the same style as the undo notification
		notification.AddLegacy( text, NOTIFY_UNDO, 2 )

		-- Play the same sound as the undo notification
		surface.PlaySound( "buttons/button15.wav" )

	end

end )
