class 'MapEditorClient'

local Shared = require '__shared/MapEditorShared'
local JSONentities = require '__shared/JSONentities'
local Freecam = require 'Freecam'
local json = require "__shared/json"


function MapEditorClient:__init()
	print("Initializing MapEditorClient")
	self:RegisterVars()
	self:RegisterEvents()
	Shared:__init()
	Freecam:__init()
end

function MapEditorClient:RegisterVars()
	self.spawnEntity = nil
	self.spawnedEntities = {}
	self.selectedEntityID = ""
	self.isFreecam = false
	self.raycastTransform = nil
	self.pendingMoveWithRaycast = nil

	self.castDistance = 100
	self.fallbackDistance = 5
end

function MapEditorClient:RegisterEvents()
	--Game events
	self.m_OnUpdateInputEvent = Events:Subscribe('Client:UpdateInput', self, self.OnUpdateInput)
	self.m_ExtensionLoadedEvent = Events:Subscribe('ExtensionLoaded', self, self.OnLoaded)
	self.m_EngineMessageEvent = Events:Subscribe('Engine:Message', self, self.OnEngineMessage)
	self.m_EngineUpdateEvent = Events:Subscribe("Engine:Update", self, self.OnUpdate)

	--WebUI events
	Events:Subscribe('MapEditor:SpawnInstanceWithRaycast', self, self.OnSpawnInstanceWithRaycast)
	Events:Subscribe('MapEditor:SpawnInstance', self, self.OnSpawnInstance)
	Events:Subscribe('MapEditor:SelectEntity', self, self.OnSelectEntity)
	Events:Subscribe('MapEditor:DeselectEntity', self, self.OnDeselectEntity)
	Events:Subscribe('MapEditor:SetEntityMatrix', self, self.OnSetEntityMatrix)
	Events:Subscribe('MapEditor:DeleteEntity', self, self.OnDeleteEntity)
	Events:Subscribe('MapEditor:SetViewmode', self, self.OnSetViewmode)
	Events:Subscribe('MapEditor:MoveObjectWithRaycast', self, self.OnMoveObjectWithRaycast)
	Events:Subscribe('MapEditor:LoadProject', self, self.OnLoadProject)

	-- Controls
	-- Events:Subscribe('MapEditor:EnableKeyboard', self, self.OnEnableKeyboard)
	-- Events:Subscribe('MapEditor:DisableKeyboard', self, self.OnDisableKeyboard)

	Events:Subscribe('MapEditor:EnableFreecam', self, self.OnEnableFreecam)

	--NetEvents
	NetEvents:Subscribe('MapEditor:RoundReset', self, self.OnRoundReset)
end

----------- Game functions----------------

function MapEditorClient:OnUpdate(p_Delta, p_SimulationDelta)
	-- TODO: Move this to controls

	if self.selectedEntityID == "" then
		return
	end

	local s_Transform = ClientUtils:GetCameraTransform()
	local pos = s_Transform.trans

	local left = s_Transform.left
	local up = s_Transform.up
	local forward = s_Transform.forward

	WebUI:ExecuteJS(string.format('editor.webGL.UpdateCameraPos(%s, %s, %s);', pos.x, pos.y, pos.z))
	WebUI:ExecuteJS(string.format('editor.webGL.UpdateCameraAngle(%s, %s, %s,%s, %s, %s,%s, %s, %s);', left.x, left.y, left.z,up.x, up.y, up.z,forward.x, forward.y, forward.z))
end

function MapEditorClient:OnLoaded()
	WebUI:Init()
	WebUI:Show()
end

function MapEditorClient:OnRoundReset()
	self.spawnedEntities = {}
	self.selectedEntityID = ""
	WebUI:ExecuteJS('OnRoundReset()')
end

function MapEditorClient:OnEngineMessage(p_Message) 

	if p_Message.type == MessageType.ClientLevelFinalizedMessage then
		print("MessageType.ClientLevelFinalizedMessage")
		Shared:FillVariations()
	
		WebUI:ExecuteJS(string.format("editor.OnRegisterInstances('%s')", json.encode(Shared.m_Blueprints)))
		self:LoadJSONEntities(JSONentities) --Might be better to call this after a bit, so we are sure that all the blueprints are stored in js
	end
end

function MapEditorClient:OnUpdateInput(p_Delta)
	--We need to do the raycast in a physics update apparently.

	if(self.isFreecam == true) then 

		local s_Transform = ClientUtils:GetCameraTransform()

		if(s_Transform.trans == Vec3(0,0,0)) then -- Camera is below the ground. Creating an entity here would be useless.
			self.raycastTransform = nil
			return
		end

		-- The freecam transform is inverted. Invert it back

		local s_CameraForward = Vec3(s_Transform.forward.x * -1, s_Transform.forward.y * -1, s_Transform.forward.z * -1)

		local s_CastPosition = Vec3(s_Transform.trans.x + (s_CameraForward.x*self.castDistance),
									s_Transform.trans.y + (s_CameraForward.y*self.castDistance),
									s_Transform.trans.z + (s_CameraForward.z*self.castDistance))

		local s_Raycast = RaycastManager:Raycast(s_Transform.trans, s_CastPosition, 2)

		local s_Transform = LinearTransform(
			Vec3(1,0,0),
			Vec3(0,1,0),
			Vec3(0,0,1),
			s_Transform.trans
		)

		if(s_Raycast ~= nil) then
			s_Transform.trans = s_Raycast.position
		else
			-- Raycast didn't hit anything. Spawn it in front of the player instead.
			s_Transform.trans = Vec3(s_Transform.trans.x + (s_CameraForward.x*self.fallbackDistance),
								s_Transform.trans.y + (s_CameraForward.y*self.fallbackDistance),
								s_Transform.trans.z + (s_CameraForward.z*self.fallbackDistance))
		end

		self.raycastTransform = s_Transform

	end

	-- This also crashes if we do it outside of Update.
	if(self.spawnEntity ~= nil and self.raycastTransform ~= nil) then

		local s_SpawnTransform = LinearTransform()
		s_SpawnTransform.trans = self.raycastTransform.trans


		Events:Dispatch('BlueprintManager:SpawnBlueprintFromClient', self.spawnEntity.entityID, Guid(self.spawnEntity.partitionGuid), Guid(self.spawnEntity.instanceGuid), tostring(s_SpawnTransform), self.spawnEntity.variation)

		self:RegisterEntity(self.spawnEntity.blueprintID, self.spawnEntity.entityID, s_SpawnTransform, self.spawnEntity.variation)
		self.spawnEntity = nil

	end

	if self.pendingMoveWithRaycast ~= nil then
		self:MoveWithRaycast()
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F1) then
		WebUI:BringToFront()
		WebUI:EnableMouse()
		WebUI:Show()
		self.isFreecam = true;
		Freecam:Enable();
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F2) then
		--WebUI:BringToFront()
		WebUI:DisableMouse()
		-- WebUI:Hide()
		Freecam:Disable();
		self.isFreecam = false;
	end

	if InputManager:WentKeyDown(InputDeviceKeys.IDK_F3) then

	end

	-- We let go of right mouse button. Activate the UI again.
	if(self.isFreecam and InputManager:WentMouseButtonUp(InputDeviceMouseButtons.IDB_Button_1)) then
		WebUI:EnableMouse()
		WebUI:EnableKeyboard()
	end
end

----------- WebUI functions----------------


function MapEditorClient:OnEnableFreecam()
	WebUI:DisableKeyboard()
	WebUI:DisableMouse()
end

function MapEditorClient:OnMoveObjectWithRaycast(p_Args)
	print(p_Args)
	if p_Args == nil then
		print("p_Args is nil")
		return
	end

	local p_ArgsArray = split(p_Args, ",")

	if p_ArgsArray == nil then
		print("p_ArgsArray is nil")
		return
	end

	local s_Id = p_ArgsArray[1]
	local s_RaycastDirection = Vec3( tonumber(p_ArgsArray[2]), tonumber(p_ArgsArray[3]), tonumber(p_ArgsArray[4]) )

	self.pendingMoveWithRaycast = {id = s_Id, raycastDirection = s_RaycastDirection}
end


function MapEditorClient:OnSetViewmode(p_ViewMode)
	local p_WorldRenderSettings = ResourceManager:GetSettings("WorldRenderSettings")
	if p_WorldRenderSettings ~= nil then
		local s_WorldRenderSettings = WorldRenderSettings(p_WorldRenderSettings)
		s_WorldRenderSettings.viewMode = p_ViewMode
	else 
		print("Failed to get WorldRenderSettings")
	end
end

function MapEditorClient:OnDeleteEntity(p_ID)
	-- if p_ID ~= self.selectedEntityID then 
	-- 	error("Trying to delete an entity that's not selected. Parameter: "..p_ID..", selected ID: ".. self.selectedEntityID)
	-- end

	Events:Dispatch('BlueprintManager:DeleteBlueprintFromClient', p_ID)

	self.spawnedEntities[p_ID] = nil
	-- WebUI:ExecuteJS("editor.OnRemoveEntity("..p_ID..")")

end

function MapEditorClient:OnSelectEntity(p_ID) 
	if self.selectedEntityID == "" then
		WebUI:ExecuteJS("editor.webGL.ShowGizmo()")
	end

	self.selectedEntityID = p_ID
end

function MapEditorClient:OnDeselectEntity(p_ID)
	WebUI:ExecuteJS("editor.webGL.HideGizmo()")
	self.selectedEntityID = ""
end

function MapEditorClient:OnSetEntityMatrix(p_Args) 
	print("OnSetEntityMatrix "..p_Args)
	if p_Args == nil then
		print("p_Args is nil")
		return
	end

	local p_ArgsArray = split(p_Args, ":")

	if p_ArgsArray == nil then
		print("p_ArgsArray is nil")
		return
	end

	local s_Transform = StringToLinearTransform(p_ArgsArray[2])
	
	Events:Dispatch('BlueprintManager:MoveBlueprintFromClient', p_ArgsArray[1], tostring(s_Transform))
end

function MapEditorClient:OnSpawnInstanceWithRaycast(p_ParamsCombined) 
	print(p_ParamsCombined)
	local s_Parameters = split(p_ParamsCombined, ":")
	local s_EntityID = s_Parameters[1]
	local s_PartitionGuid = s_Parameters[2]
	local s_InstanceGuid = s_Parameters[3]
	local s_Variation = tonumber(s_Parameters[4])

	if s_Variation == -1 then
		print("Variation not passed! Defaulting to 0")
		s_Variation = 0
	end
	-- This entity will be spawned in Update. We can't create entities outside it. (Or maybe because it's started from an event?)
	self.spawnEntity = {blueprintID = s_InstanceGuid, entityID = s_EntityID, partitionGuid = s_PartitionGuid, instanceGuid = s_InstanceGuid, variation = s_Variation}
	
end

function MapEditorClient:OnSpawnInstance(p_ParamsCombined) 
	-- print(p_ParamsCombined)
	local s_Parameters = split(p_ParamsCombined, ":")
	local s_EntityID = s_Parameters[1]
	local s_PartitionGuid = s_Parameters[2]
	local s_InstanceGuid = s_Parameters[3]
	local s_Variation = tonumber(s_Parameters[4])
	local s_TransformString = s_Parameters[5]
	local s_ParentID = s_Parameters[6]

	if s_Variation == -1 or s_Variation == nil then
		print("Variation not passed! Defaulting to 0")
		s_Variation = 0
	end
	local s_Transform = StringToLinearTransform(s_TransformString)

	Events:Dispatch('BlueprintManager:SpawnBlueprintFromClient', s_EntityID, Guid(s_PartitionGuid), Guid(s_InstanceGuid), s_TransformString, s_Variation )
	self:RegisterEntity(s_InstanceGuid, s_EntityID, s_Transform, s_Variation, s_ParentID)
end

function MapEditorClient:OnLoadProject(p_JSONstring) 
	self:LoadJSONEntities(p_JSONstring)
end

--------------- Class functions ---------------

function MapEditorClient:MoveWithRaycast() 
	if self.pendingMoveWithRaycast == nil then
		return
	end

	local s_Transform = ClientUtils:GetCameraTransform()

	if s_Transform.trans == Vec3(0,0,0) then
		self.pendingMoveWithRaycast = nil
		return
	end

	local s_CastPosition = Vec3(s_Transform.trans.x + (self.pendingMoveWithRaycast.raycastDirection.x*self.castDistance),
								s_Transform.trans.y + (self.pendingMoveWithRaycast.raycastDirection.y*self.castDistance),
								s_Transform.trans.z + (self.pendingMoveWithRaycast.raycastDirection.z*self.castDistance))

	local s_Raycast = RaycastManager:Raycast(s_Transform.trans, s_CastPosition, 2)

	local s_Transform = LinearTransform(
		Vec3(1,0,0),
		Vec3(0,1,0),
		Vec3(0,0,1),
		s_Transform.trans
	)

	if s_Raycast ~= nil then
		WebUI:ExecuteJS(string.format('editor.OnMoveEntityWithRaycast( \"%s\", %s, %s, %s)', self.pendingMoveWithRaycast.id, s_Raycast.position.x, s_Raycast.position.y, s_Raycast.position.z ))
	else
		print("MoveWithRaycast: raycast failed")
	end

	self.pendingMoveWithRaycast = nil
end


function MapEditorClient:RegisterEntity(p_BlueprintID, p_EntityID, p_EntityTransform, p_Variation, p_ParentID) 
	self.spawnedEntities[p_EntityID] = true

	local s_Left = p_EntityTransform.left
	local s_Up = p_EntityTransform.up
	local s_Forward = p_EntityTransform.forward
	local s_Pos = p_EntityTransform.trans

	local s_LinearTransformString = string.format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s', 
		s_Left.x, s_Left.y, s_Left.z, s_Up.x, s_Up.y, s_Up.z, s_Forward.x, s_Forward.y, s_Forward.z, s_Pos.x, s_Pos.y, s_Pos.z )

	WebUI:ExecuteJS(string.format('editor.OnSpawnedEntity( \"%s\", \"%s\", \"%s\", %s, \"%s\")', p_EntityID, p_BlueprintID, s_LinearTransformString, p_Variation, tostring(p_ParentID)))
end

function MapEditorClient:LoadJSONEntities(p_JSONstring) 
	if p_JSONstring == nil or p_JSONstring == true then
		print("No entities saved in JSON")
		return
	end

	print("Found JSON table, applying..")

-- print(p_JSONstring)
	local entitiesTable = json.decode(p_JSONstring)
-- print(entitiesTable)
	if entitiesTable == '' then
		print("JSON string is empty")
		return
	end

	if entitiesTable == nil then
		print("JSON string is not valid")
		return
	end

	self:ParseSavedEntities(entitiesTable)
	
end

function MapEditorClient:ParseSavedEntities(p_Entities)
	for k, entityInfo in pairs(p_Entities) do

		if entityInfo.type == "Blueprint" then
			local s_LinearTransform = LinearTransform(
				Vec3(entityInfo.transform.left.x, entityInfo.transform.left.y, entityInfo.transform.left.z),
				Vec3(entityInfo.transform.up.x, entityInfo.transform.up.y, entityInfo.transform.up.z),
				Vec3(entityInfo.transform.forward.x, entityInfo.transform.forward.y, entityInfo.transform.forward.z),
				Vec3(entityInfo.transform.trans.x, entityInfo.transform.trans.y, entityInfo.transform.trans.z))
			if entityInfo.variation == nil then
				entityInfo.variation = 0
			end
			Events:Dispatch('BlueprintManager:SpawnBlueprintFromClient', entityInfo.id, Guid(entityInfo.instance.partitionGuid), Guid(entityInfo.instance.instanceGuid), tostring(s_LinearTransform), entityInfo.variation )
			


			self:RegisterEntity(entityInfo.instance.instanceGuid, entityInfo.id, s_LinearTransform, entityInfo.variation, entityInfo.parent)

		elseif entityInfo.type == "group" then
			local s_Left = entityInfo.transform.left
			local s_Up = entityInfo.transform.up
			local s_Forward = entityInfo.transform.forward
			local s_Pos = entityInfo.transform.trans

			local s_LinearTransformString = string.format('%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s', 
				s_Left.x, s_Left.y, s_Left.z, s_Up.x, s_Up.y, s_Up.z, s_Forward.x, s_Forward.y, s_Forward.z, s_Pos.x, s_Pos.y, s_Pos.z )

			WebUI:ExecuteJS(string.format("editor.OnCreateGroup('%s','%s','%s', '%s')", entityInfo.id, entityInfo.name, s_LinearTransformString, tostring(entityInfo.parent)))

			self:ParseSavedEntities(entityInfo.children)

			-- print("group")
		end

		::continue::
	end

end

function StringToLinearTransform(p_String)
	local a = split(p_String, ",")
	return LinearTransform(
			Vec3(tonumber(a[1]),tonumber(a[2]),tonumber(a[3])),
			Vec3(tonumber(a[4]),tonumber(a[5]),tonumber(a[6])),
			Vec3(tonumber(a[7]),tonumber(a[8]),tonumber(a[9])),
			Vec3(tonumber(a[10]),tonumber(a[11]),tonumber(a[12]))
		)
end

function split(pString, pPattern)
	local Table = {}  -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = pString:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(Table,cap)
		end
		last_end = e+1
		s, e, cap = pString:find(fpat, last_end)
	end
	if last_end <= #pString then
		cap = pString:sub(last_end)
		table.insert(Table, cap)
	end
	return Table
end

g_MapEditorClient = MapEditorClient()

