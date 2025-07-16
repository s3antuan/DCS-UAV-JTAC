local menu = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "JTAC")
local jtac1 = UavJtac:New(coalition.side.BLUE, "UAV test A", "Target Zone 1", 1688, menu, nil)
local jtac2 = UavJtac:New(coalition.side.BLUE, "UAV test B", "Target Zone 2", 1688, menu, nil)

timer.scheduleFunction(function()
	jtac2:Destroy()
	trigger.action.outText("!", 30)
end, {}, timer.getTime() + 300)