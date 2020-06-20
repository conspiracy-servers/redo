-- TODO: Split this script into multiple files in this directory

--[[------------------------------------------------
Setup the script
------------------------------------------------]]--

-- Add the network message name
util.AddNetworkString( "Redo" )

-- Setup global table to store undo history
local undoHistory = {}

--[[------------------------------------------------
Add our hooks
------------------------------------------------]]--

-- Called when a player attempts to undo something (this is called even when there's nothing to undo)
hook.Add( "CanUndo", "trackUndoHistory", function( player, undoTable )

	-- Don't continue if this isn't a real entity undo
	-- TODO: Check for constraint-only undoes too!
	if ( undoTable.Entities == nil ) then return end

	-- Table to hold our custom entity structures for this undo
	local undoEntities = {}

	-- Loop through all entities in the undo
	for index, entity in ipairs( undoTable.Entities ) do -- IDEA: Is a normal for loop faster than ipairs?

		-- Store information about the entity in a custom structure
		-- We need to do this since after this hook, the reference to the entity (undoTable.Entities[ index ]) becomes NULL!
		local entityStructure = {

			-- Information
			className = entity:GetClass(),

			-- Owner
			owner = ( entity:GetOwner() != NULL and entity:GetOwner() or undoTable.Owner ),

			-- Placement
			position = entity:GetPos(),
			angles = entity:GetAngles(),

			-- Constraints
			entityConstraints = entity:GetConstrainedEntities(),
			physicsConstraints = entity:GetConstrainedPhysObjects(),

			-- Relatives
			parent = entity:GetParent(),
			children = entity:GetChildren(),

			-- TODO: Bones

			-- Visual
			model = entity:GetModel(),
			skin = entity:GetSkin(),
			bodygroups = entity:GetBodyGroups(),
			color = entity:GetColor(),

			-- Physics
			collisionGroup = entity:GetCollisionGroup(),
			moveType = entity:GetMoveType(),
			solidType = entity:GetSolid(),
			solidFlags = entity:GetSolidFlags(),
			physicsObject = {

				-- Velocity
				velocity = entity:GetPhysicsObject():GetVelocity(),

				-- Mass
				mass = entity:GetPhysicsObject():GetMass()

			}

		}
		
		-- Add this entity to our custom undo structure's entities
		undoEntities[ index ] = entityStructure

	end

	-- Store the player's session ID
	local userID = player:UserID()

	-- Check if the player doesn't have a table in the undo history
	if ( undoHistory[ userID ] == nil ) then

		-- Create an empty table for the player in the undo history
		undoHistory[ userID ] = {}

	end

	-- Insert this undo at the end of the player's history
	table.insert( undoHistory[ userID ], {

		-- The name of this undo action
		Name = undoTable.Name,

		-- Custom message associated with this undo action
		CustomUndoText = undoTable.CustomUndoText,

		-- A list of information about the entities involved in the undo
		Entities = undoEntities

	} )

end )

-- Runs when a player disconnects
hook.Add( "PlayerDisconnect", "deleteUndoHistory", function( player )

	-- Remove all of the player's undo history
	table.remove( undoHistory, player:UserID() )

end )

-- TODO: Clear all history for every player when admin cleanup is called
-- TODO: Clear all history for specific player when user cleanup is called

--[[------------------------------------------------
Create our functions
------------------------------------------------]]--

-- Redo an undo
local function redoAction( player, undoHistoryIndex )

	-- Store the player's session ID
	local userID = player:UserID()

	-- Fetch the table for this undo from the player's history
	local undoTable = undoHistory[ userID ][ undoHistoryIndex ]

	-- Easy access to details about this undo
	local undoName = undoTable.Name
	local undoCustomText = undoTable.CustomUndoText or ""
	local undoEntities = undoTable.Entities

	-- Replace 'Undone ' with 'Redone ' in the custom undo text only once
	local redoCustomText = string.gsub( undoCustomText, "Undone ", "Redone ", 1 )

	-- Loop through each custom entity structure that should be redone
	for index, entityStructure in ipairs( undoEntities ) do -- IDEA: Is a normal for loop faster than ipairs?

		-- Create the entity
		local entity = ents.Create( entityStructure.className )

		-- Owner (this disables physics interaction :/)
		-- FIX: entity:SetOwner( entityStructure.owner )

		-- Placement
		entity:SetPos( entityStructure.position )
		entity:SetAngles( entityStructure.angles )

		-- Constraints
		-- TODO: entityConstraints
		-- TODO: physicsConstraints

		-- Relatives
		entity:SetParent( entityStructure.parent )
		-- TODO: children

		-- TODO: Bones

		-- Visual
		entity:SetModel( entityStructure.model )
		entity:SetSkin( entityStructure.skin )
		-- TODO: bodygroups

		-- Physics
		-- TODO: Remove things from here that aren't needed
		entity:SetMoveType( entityStructure.moveType )
		entity:PhysicsInit( entityStructure.solidType )
		entity:SetSolid( entityStructure.solidType ) -- This isn't really needed, since Entity:PhysicsInit() calls this automatically
		entity:SetSolidFlags( entityStructure.solidFlags ) -- This isn't really needed, since Entity:PhysicsInit() calls this automatically
		entity:GetPhysicsObject():Wake()
		entity:GetPhysicsObject():EnableMotion( true )
		entity:GetPhysicsObject():EnableCollisions( true )
		entity:GetPhysicsObject():SetVelocity( entityStructure.physicsObject.velocity )
		entity:GetPhysicsObject():SetMass( entityStructure.physicsObject.mass )
		entity:SetCollisionGroup( entityStructure.collisionGroup )
		entity:GetPhysicsObject():RecheckCollisionFilter()

		-- Spawn and activate the entity
		entity:Spawn()
		entity:Activate()

		-- TODO: Create the undo entry that matches the original undo

		-- TODO: Add this entity to the cleanup for it's type

	end

	-- Start the network message that tells the player about their successful redo
	net.Start( "Redo" )

		-- The name of the undo action
		net.WriteString( undoName )

		-- The custom text of the redo action
		net.WriteString( redoCustomText )

	-- Send the network message to the player
	net.Send( player )

	-- Remove this undo from the player's history
	table.remove( undoHistory[ userID ], undoHistoryIndex )

end

-- The callback for the various console commands
local function redoConsoleCommand( player, command, arguments )

	-- Prevent the server from executing this
	if ( player == nil ) then return end

	-- Store the player's session ID
	local userID = player:UserID()

	-- The player wants to redo a specific history entry
	if ( command == "gmod_redonum" ) then

		-- Check if the argument that specifies the index has been provided
		if ( not ( #arguments == 1 and tonumber( arguments[ 1 ] ) != nil ) ) then

			-- Give them a console message
			print( "You're using this command wrong! You're supposed to use it like this: gmod_redonum <number>." )

			-- Prevent further execution
			return

		end

		-- Store the requested history index
		local undoHistoryIndex = tonumber( arguments[ 1 ] )

		-- Check if the player has the requested index in their undo history
		if ( not ( undoHistory[ userID ] != nil and undoHistory[ userID ][ undoHistoryIndex ] != nil ) ) then

			-- Give them a console message
			print( "Entry " .. undoHistoryIndex .. " doesn't exist in your undo history.\nRemember the history starts at 1 (the oldest undo) and counts up as you undo more things." )

			-- Prevent further execution
			return

		end

		-- Redo it!
		redoAction( player, undoHistoryIndex )

	-- The player wants to redo the latest undo
	else

		-- Prevent further execution if the player doesn't have anything left to redo
		if ( not ( undoHistory[ userID ] != nil and table.maxn( undoHistory[ userID ] ) > 0 ) ) then return end

		-- Redo it!
		redoAction( player, table.maxn( undoHistory[ userID ] ) )

	end

end

--[[------------------------------------------------
Add the console commands
------------------------------------------------]]--

--[[ The default undo console commands:
* 'gmod_undonum' (Undoes a specific undo entry index)
* 'gmod_undo' (Undoes the latest in the undo entries)
* 'undo' (Same as above)
]]

-- Redoes a specific undo
concommand.Add( "gmod_redonum", redoConsoleCommand, nil, "Redoes a specific undo.", FCVAR_CLIENTCMD_CAN_EXECUTE )

-- Redoes the latest undo
concommand.Add( "gmod_redo", redoConsoleCommand, nil, "Redoes the latest undo.", FCVAR_CLIENTCMD_CAN_EXECUTE )
concommand.Add( "redo", redoConsoleCommand, nil, "Redoes the latest undo.", FCVAR_CLIENTCMD_CAN_EXECUTE )
