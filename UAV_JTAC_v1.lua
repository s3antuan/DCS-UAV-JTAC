--[[
UAV JTAC Script

dependencies: Mist
version: v1
author: Nyako 2-1 | ginmokusei
date: Jun. 2025

example:

local jtac = UavJtac:New(coalition.side.BLUE, "jtac-group-name", "jtac-zone-name", 1688, subMenuPath, "menu-item-name")

]]

UavJtac = {}

do
	-- Config (user customizable)
	UavJtac.LASE_NEXT_TARGET_DELAY = 30 -- time (sec.) for the delay of lasing the next target


	-- @param #table/enum coalition.side Coalition of this jtac belongs to
	-- @param #string Group name of the jtac unit in ME
	-- @param #string Zone name of the target trigger zone in ME, must be round
	-- @param #number	Desired laser code for this jtac (1111~1788)
	-- @param #table Sub menu branch path for the f10 menu (return value of missionCommands.addSubMenu)
	-- @param #string (optional)Name displayed in the f10 menu
	-- @return #table UavJtac object.
	function UavJtac:New(side, jtacGroupName, targetZoneName, laserCode, subMenuPath, commandName)
		local obj = {}
		obj.side = side
		obj.name = jtacGroupName
		obj.jtac = Group.getByName(jtacGroupName):getUnit(1)
		obj.zone = trigger.misc.getZone(targetZoneName)
		obj.code = laserCode
		obj.subMenuPath = subMenuPath
		obj.commandName = commandName or jtacGroupName

		if obj.side == coalition.side.NEUTRAL then
			env.error(string.format("[UAV JTAC] Side cannot be set as NEUTRAL:", obj.name), true)
			return
		end
		
		if not obj.jtac then
			env.error(string.format("[UAV JTAC] Jtac unit not found:", obj.name), true)
			return
		end

		if not obj.zone then
			env.error(string.format("[UAV JTAC] Target zone not found:", targetZoneName), true)
			return
		end

		if not obj.zone.type == 0 then
			env.error(string.format("[UAV JTAC] Target zone must be round:", targetZoneName), true)
			return
		end

		if obj.code > 1788 or obj.code < 1111 then
			env.error(string.format("[UAV JTAC] Invalid laser code: %d", obj.code), true)
			return
		end

		obj.targetList = {}
		obj.currentTargetIndex = 0
		obj.currentTargetInfo = nil
		obj.ray = nil
		obj.scheduleFunctionId = nil
		obj.isMenuBlocked = false
		obj.smokeCooldownTimer = 0
		
		setmetatable(obj, self)
		self.__index = self

		-- init
		obj:RefreshTargetList()
		obj.currentTargetIndex = obj:LaseTarget(obj.currentTargetIndex)
		obj.eventHandler = obj:initEventHandler()

		-- f10 menu
		obj.menuPath = obj:createMenu()

		return obj
	end


	-- @param #table Trigger zone
	-- @param #table/enum Object.Category
	-- @return #table List of found objects/targets
	function UavJtac:SearchTargetInZone(zone, category)
		if not (category == Object.Category.UNIT or category == Object.Category.STATIC) then
			return {}
		end

		local foundObjects = {}
		local volS = {
			id = world.VolumeType.SPHERE,
			params = {
				point = zone.point,
				radius = zone.radius
			}
		}

		local ifFound = function(foundItem, val)
			if foundItem:getCoalition() ~= self.side then
				foundObjects[#foundObjects + 1] = foundItem:getName()
				return true
			end
		end

		world.searchObjects(category, volS, ifFound)
		return foundObjects
	end


	function UavJtac:RefreshTargetList()
		local unitTargets = self:SearchTargetInZone(self.zone, Object.Category.UNIT)
		local staticTargets = self:SearchTargetInZone(self.zone, Object.Category.STATIC)
		
		self.targetList = {}
		for k, v in pairs(unitTargets) do
			table.insert(self.targetList, {name = v, category = Object.Category.UNIT})
		end
		for k, v in pairs(staticTargets) do
			table.insert(self.targetList, {name = v, category = Object.Category.STATIC})
		end
		env.info(string.format("[UAV JTAC] %s: Target list refreshed. %d units and %d statics found.", self.name, #unitTargets, #staticTargets))
		trigger.action.outTextForCoalition(self.side, string.format("[UAV JTAC] %s: Target list refreshed.", self.name), 10)
		
		if #self.targetList > 0 then
			self.currentTargetIndex = math.random(#self.targetList)
		end
	end


	-- @param #string Name of the object
	-- @param #table/enum Object.Category
	-- @return #boolean Whether the object is still alive and in zone
	function UavJtac:isTargetValid(name, category)
		if category == Object.Category.UNIT then
			local unit = Unit.getByName(name)
			if unit and unit:isActive() then
				if not (unit:getDesc().category == Unit.Category.GROUND_UNIT or unit:getDesc().category == Unit.Category.STRUCTURE) then
					return false
				else
					return unit:getLife() ~= 0 and mist.utils.get2DDist(unit:getPoint(), self.zone.point) < self.zone.radius
				end
			else
				return false
			end
		elseif category == Object.Category.STATIC then
			local static = StaticObject.getByName(name)
			if static then
				-- static won't move but search is square not circle, exclude 4 corners
				return static:getLife() ~= 0 and mist.utils.get2DDist(static:getPoint(), self.zone.point) < self.zone.radius
			else
				return false
			end
		else
			return false
		end
	end


	-- @param #number Index to target list
	-- @return #number New index
	function UavJtac:LaseTarget(index)
		local listLength = #self.targetList

		-- debug
		env.info(string.format("[UAV JTAC debug] %s: idx = %d, length = %d", self.name, index, listLength))

		-- check list is not empty
		if listLength == 0 then
			env.info(string.format("[UAV JTAC] %s: Target list is empty.", self.name))
			trigger.action.outTextForCoalition(self.side, string.format("JTAC %s: Target list is empty.", self.name), 10)
			return 0
		end

		-- check index is in range: if not, shift around index, recursive call
		if listLength < index then
			local newIndex = index - listLength
			return self:LaseTarget(newIndex)
		elseif index == 0 then
			local newIndex = listLength
			return self:LaseTarget(newIndex)
		end

		local target = self.targetList[index]

		-- check target is valid: if not, remove element, recursive call
		if not self:isTargetValid(target.name, target.category) then
			table.remove(self.targetList, index)
			return self:LaseTarget(index)
		end

		-- store target info and lase target
		local info = {name = target.name, category = target.category}
		if target.category == Object.Category.UNIT then
			local unit = Unit.getByName(target.name)
			info.type = unit:getTypeName()
			info.point = unit:getPoint()
		elseif target.category == Object.Category.STATIC then
			local static = StaticObject.getByName(target.name)
			info.type = static:getTypeName()
			info.point = static:getPoint()
		end
		self.currentTargetInfo = info

		self.ray = Spot.createLaser(self.jtac, {x = 0, y = -1, z = 0}, self.currentTargetInfo.point, self.code)
		env.info(string.format("[UAV JTAC] %s: Lasing target: %s", self.name, self.currentTargetInfo.type))
		trigger.action.outTextForCoalition(self.side, self:getTargetInfoMsg(self.currentTargetInfo), 30)

		self.smokeCooldownTimer = timer.getTime()

		return index
	end


	-- @return #table The event handler object.
	function UavJtac:initEventHandler()
		local eventHandler = {}
		eventHandler.context = self
		function eventHandler:onEvent(event)
			if event.id == world.event.S_EVENT_DEAD and event.initiator then
				local name = event.initiator:getName()
				env.info(string.format("[UAV JTAC] %s: [Event Dead] %s", self.context.name, name))
				if name == self.context.currentTargetInfo.name then
					self.context.ray:destroy()
					self.context.ray = nil
					env.info(string.format("[UAV JTAC] %s: Stop lasing target: %s", self.context.name, self.context.currentTargetInfo.type))
					trigger.action.outTextForCoalition(self.context.side, self.context:getTargetDestroyedMsg(self.context.currentTargetInfo), 10)
					self.context.isMenuBlocked = true

					-- call itself again after delay
					self.context.scheduleFunctionId = timer.scheduleFunction(function()
						table.remove(self.context.targetList, self.context.currentTargetIndex)
						self.context.currentTargetInfo = nil
						self.context.currentTargetIndex = self.context:LaseTarget(self.context.currentTargetIndex)
						self.context.scheduleFunctionId = nil
						self.context.isMenuBlocked = false
					end, {}, timer.getTime() + UavJtac.LASE_NEXT_TARGET_DELAY)
				end
			end
		end
		world.addEventHandler(eventHandler)
		return eventHandler
end


	-- @param #table Target info
	-- @return #string Message for display
	function UavJtac:getTargetInfoMsg(info)
		local msg = string.format("JTAC %s is now lasing target at:\n\n", self.name)
		msg = msg .. string.format("Type: %s\n", info.type)
		msg = msg .. string.format("Code: %d\n\n", self.code)

		local lat, lon, alt = coord.LOtoLL(info.point)
		msg = msg .. string.format("Coord:\n")
		msg = msg .. string.format("  Lat/Lon(DDM): %s  %d ft.\n", mist.tostringLL(lat, lon, 3), mist.utils.metersToFeet(alt))
		msg = msg .. string.format("  Lat/Lon(DMS): %s  %d ft.\n", mist.tostringLL(lat, lon, 0, true), mist.utils.metersToFeet(alt))
		msg = msg .. string.format("  MGRS: %s\n", mist.tostringMGRS(coord.LLtoMGRS(lat, lon), 5))

		return msg
	end


	-- @param #table Target info
	-- @return #string Message for display
	function UavJtac:getTargetDestroyedMsg(info)
		local msg = string.format("JTAC %s: target destroed.\n", self.name)
		msg = msg .. string.format("Type: %s\n", info.type)

		return msg
	end


	-- @return #table Menu path.
	function UavJtac:createMenu()
		local function showInfo()
			if self.isMenuBlocked then
				trigger.action.outTextForCoalition(self.side, "Acquiring new target. Please standby...", 10)
				return
			end
			if self.currentTargetIndex == 0 then
				trigger.action.outTextForCoalition(self.side, "Target list is empty. Try refreshing the list.", 10)
			else
				trigger.action.outTextForCoalition(self.side, self:getTargetInfoMsg(self.currentTargetInfo), 30)
			end
		end

		local function smokeTarget()
			if self.isMenuBlocked then
				trigger.action.outTextForCoalition(self.side, "Acquiring new target. Please standby...", 10)
				return
			end
			if self.currentTargetIndex == 0 then
				trigger.action.outTextForCoalition(self.side, "Target list is empty. Try refreshing the list.", 10)
			else
				if timer.getTime() > self.smokeCooldownTimer then
					trigger.action.smoke(self.currentTargetInfo.point, trigger.smokeColor.Orange)
					trigger.action.outTextForCoalition(self.side, "Target marked with smoke.", 10)
					self.smokeCooldownTimer = timer.getTime() + 300
				else
					trigger.action.outTextForCoalition(self.side, "Smoke is on cooldown.", 10)
				end
			end
		end

		local function nextTarget()
			if self.isMenuBlocked then
				trigger.action.outTextForCoalition(self.side, "Acquiring new target. Please standby...", 10)
				return
			end
			self.currentTargetIndex = self.currentTargetIndex + 1
			self.currentTargetIndex = self:LaseTarget(self.currentTargetIndex)
		end

		local function previousTarget()
			if self.isMenuBlocked then
				trigger.action.outTextForCoalition(self.side, "Acquiring new target. Please standby...", 10)
				return
			end
			self.currentTargetIndex = self.currentTargetIndex - 1
			self.currentTargetIndex = self:LaseTarget(self.currentTargetIndex)
		end

		local function refreshList()
			if self.isMenuBlocked then
				trigger.action.outTextForCoalition(self.side, "Acquiring new target. Please standby...", 10)
				return
			end
			self:RefreshTargetList()
			self.currentTargetIndex = self:LaseTarget(self.currentTargetIndex)
		end

		local menu = missionCommands.addSubMenuForCoalition(self.side, self.commandName, self.subMenuPath)
		missionCommands.addCommandForCoalition(self.side, "Show Target Info", menu, showInfo, {})
		missionCommands.addCommandForCoalition(self.side, "Smoke Target", menu, smokeTarget, {})
		missionCommands.addCommandForCoalition(self.side, "Change to Next Target", menu, nextTarget, {})
		missionCommands.addCommandForCoalition(self.side, "Change to Previous Target", menu, previousTarget, {})
		missionCommands.addCommandForCoalition(self.side, "Refresh Target List", menu, refreshList, {})

		return menu
	end


	function UavJtac:Destroy()
		world.removeEventHandler(self.eventHandler)
		if self.scheduleFunctionId then
			timer.removeFunction(self.scheduleFunctionId)
		end
		if self.ray then
			self.ray:destroy()
		end
		missionCommands.removeItemForCoalition(self.side, self.menuPath)
		env.info(string.format("[UAV JTAC] %s: Destroy() called.", self.name))
	end
end
