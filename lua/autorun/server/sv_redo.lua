-- TODO: Split this script into multiple files in this directory (lua/autorun/server/)

--[[------------------------------------------------
Setup the script
------------------------------------------------]]--

-- Add the network message names
util.AddNetworkString( "redoNotification" )
util.AddNetworkString( "onPlayerCleanup" )

-- Create a table to store everyone's undo history
local undoHistory = {}

--[[------------------------------------------------
Create the hook functions
------------------------------------------------]]--

-- Called when a player attempts to undo something (this is called even when there's nothing to undo)
local function trackUndoHistory( player, undoTable )

	-- Don't continue if this isn't a real entity undo
	-- TODO: Check for constraint-only undo's too!
	if undoTable.Entities == nil then return end

	-- Table to hold the custom entity structures for this undo
	local undoEntities = {}

	-- Loop through all entities in the undo
	for index = 1, #undoTable.Entities do
	
		-- Fetch this iteration's entity
		local entity = undoTable.Entities[ index ]

		-- Skip if the entity isn't valid
		if entity == NULL then continue end
		
		-- Fetch this entity's physics object
		local physicsObject = entity:GetPhysicsObject()

		-- Store information about the entity in a custom structure
		-- We need to do this since after this hook, the reference to the entity (undoTable.Entities[ index ]) becomes NULL!
		local entityStructure = {

			-- Information
			className = entity:GetClass(),

			-- Owner
			owner = undoTable.Owner,

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
			bodygroups = entity:GetBodyGroups(), -- This probably isn't needed?
			color = entity:GetColor(),
			material = entity:GetMaterial(),

			-- Physics
			collisionGroup = entity:GetCollisionGroup(),
			moveType = entity:GetMoveType(),
			solidType = entity:GetSolid(),
			solidFlags = entity:GetSolidFlags(),
			physicsObject = {

				-- Velocity
				velocity = physicsObject:GetVelocity(),

				-- Mass
				mass = physicsObject:GetMass(),

				-- Frozen
				motionEnabled = physicsObject:IsMotionEnabled()

			}

		}

		-- Add this entity to the custom undo structure's entities
		undoEntities[ index ] = entityStructure

	end

	-- Store the player's session ID
	local userID = player:UserID()

	-- Check if the player doesn't have a table in the undo history
	if undoHistory[ userID ] == nil then

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

end

-- Runs when a player disconnects
local function deleteUndoHistory( player )

	-- Remove all of the player's undo history
	table.remove( undoHistory, player:UserID() )

end

-- Runs after an admin cleanup
local function wipeUndoHistory()

	-- Reset the undo history to an empty array
	undoHistory = {}

end

--[[------------------------------------------------
Create the network message functions
------------------------------------------------]]--

-- Runs when a player cleans up their props (this also runs when an admin cleanup happens)
local function onPlayerCleanup( length, player )

	-- Receive the name of the cleanup
	local name = net.ReadString()

	-- Don't continue if we're not cleaning up everything
	if name ~= "all" then return end

	-- Store the player's session ID
	local userID = player:UserID()

	-- Clear the undo history for this player
	undoHistory[ userID ] = {}

end

--[[------------------------------------------------
Create the action functions
------------------------------------------------]]--

-- Redo an undo
local function redoAction( player, undoHistoryIndex )

	-- Store the player's session ID
	local userID = player:UserID()

	-- Fetch the table for this undo from the player's history
	local undoTable = undoHistory[ userID ][ undoHistoryIndex ]

	-- Easy access to details about this undo
	local undoName = undoTable.Name
	local undoCustomText = undoTable.CustomUndoText
	local undoEntities = undoTable.Entities

	-- Begin the creation of the undo for this redo
	undo.Create( undoName )

	-- Set this undo to the player
	undo.SetPlayer( player )

	-- The default redo notification text
	local redoCustomText = "Redone " .. undoName

	-- Do we have valid custom undo text?
	if undoCustomText ~= nil then

		-- Set the redo custom text to the undo custom text, but with the starting 'Undone ' replaced with 'Redone '
		redoCustomText = string.gsub( undoCustomText, "Undone ", "Redone ", 1 )

		-- Set the custom undo text
		undo.SetCustomUndoText( undoCustomText )

	end

	-- Loop through each custom entity structure that should be redone
	for index = 1, #undoEntities do

		-- Fetch this iteration's custom entity structure
		local entityStructure = undoEntities[ index ]

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
		-- TODO: bodygroups -- This probably isn't needed
		entity:SetColor( entityStructure.color )
		entity:SetMaterial( entityStructure.material )

		-- Physics
		entity:PhysicsInit( entityStructure.solidType ) -- Initalise the entity's physics object
		entity:SetCollisionGroup( entityStructure.collisionGroup )
		entity:SetMoveType( entityStructure.moveType )
		entity:SetSolid( entityStructure.solidType ) -- This isn't really needed, since Entity:PhysicsInit() calls this automatically - but maybe it has a custom type?
		entity:SetSolidFlags( entityStructure.solidFlags ) -- This isn't really needed, since Entity:PhysicsInit() calls this automatically - but maybe it has custom flags?

		-- Spawn and activate the entity
		entity:Spawn()
		entity:Activate()

		local physicsObject = entity:GetPhysicsObject()
		physicsObject:SetMass( entityStructure.physicsObject.mass )
		physicsObject:SetVelocity( entityStructure.physicsObject.velocity )
		physicsObject:EnableMotion( entityStructure.physicsObject.motionEnabled )
		physicsObject:RecheckCollisionFilter()
		physicsObject:Wake()

		-- Add this entity to the undo
		undo.AddEntity( entity )

		-- Add this entity to the player's cleanup for it's type
		-- TODO: cleanup.Add( player, undoName, entity ) -- undoName is probably wrong for this!

	end

	-- Finish this undo creation
	undo.Finish()

	-- Start the network message that tells the player about their successful redo
	net.Start( "redoNotification" )

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
	if player == nil then return end

	-- Store the player's session ID
	local userID = player:UserID()

	-- The player wants to redo a specific history entry
	if command == "gmod_redonum" then

		-- Check if the argument that specifies the index has been provided
		if ( not ( #arguments == 1 and tonumber( arguments[ 1 ] ) ~= nil ) ) then

			-- Give them a console message
			print( "You're using this command wrong! You're supposed to use it like this: gmod_redonum <number>." )

			-- Prevent further execution
			return

		end

		-- Store the requested history index
		local undoHistoryIndex = tonumber( arguments[ 1 ] )

		-- Check if the player has the requested index in their undo history
		if ( not ( undoHistory[ userID ] ~= nil and undoHistory[ userID ][ undoHistoryIndex ] ~= nil ) ) then

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
		if ( not ( undoHistory[ userID ] ~= nil and table.maxn( undoHistory[ userID ] ) > 0 ) ) then return end

		-- Redo it!
		redoAction( player, table.maxn( undoHistory[ userID ] ) )

	end

end

--[[------------------------------------------------
Register the hooks
------------------------------------------------]]--

-- When a player undoes something
hook.Add( "CanUndo", "trackUndoHistory", trackUndoHistory ) -- Lmao this isn't even documented on the wiki

-- When a player disconnects
hook.Add( "PlayerDisconnect", "deleteUndoHistory", deleteUndoHistory )

-- After the map is cleaned up
hook.Add( "PostCleanupMap", "wipeUndoHistory", wipeUndoHistory )

--[[------------------------------------------------
Register the network message receiver
------------------------------------------------]]--

-- When a player cleans up their stuff
net.Receive( "onPlayerCleanup", onPlayerCleanup )

--[[------------------------------------------------
Register the console commands
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
