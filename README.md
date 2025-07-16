# DCS-UAV-JTAC

A simple script to setup JTAC for an UAV-like unit.
Requires [MIST](https://github.com/mrSkortch/MissionScriptingTools)

## How to Use

Place a trigger zone (must be round) in the ME as the area to scan targets.

Place a airborne unit (such as a UAV) near the trigger zone and set it to orbit.

Load both MIST script and this script in order at mission start.

Use example:

```lua
local subMenuPath = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "JTAC")
local jtac = UavJtac:New(coalition.side.BLUE, "jtac-group-name", "jtac-zone-name", 1688, subMenuPath, "menu-item-name")
```

## How It Works

This script will first scan the area defined by the trigger zone for enemy targets (unit (ground and fortification) and static object) and store them in a list. 
Then it will lase the target with defined laser code via the defined jtac airborne unit. 
Once the target is destroyed by any means it will move on to lase the next target in the list until the list becomes empty. 

Only target staying in the trigger zone at the moment being lased will be considered a vaild target.

You can command jtac to rescan the area at any moment via F10 menu option.

*This script DOES NOT WORK with moving targets.*

## F10 Menu Option

1. Show Target Info
2. Smoke Target
3. Change to Next Target
4. Change to Previous Target
5. Refresh Target List

## Document

### `UavJtac:New(side, jtacGroupName, targetZoneName, laserCode, subMenuPath, commandName)`

UavJtac constructor. 
All functionality will automatically start after the call.

**Parameters:**
<table>
  <tr>
    <td>#table/enum <b>side</b></td>
    <td>Coalition of this jtac belongs to. Either coalition.side.RED or coalition.side.BLUE</td>
  </tr>
  <tr>
    <td>#string <b>jtacGroupName</b></td>
    <td>Group name of the jtac unit in ME.</td>
  </tr>
  <tr>
    <td>#string <b>targetZoneName</b></td>
    <td>Zone name of the target trigger zone in ME, must be round.</td>
  </tr>
  <tr>
    <td>#number <b>laserCode</b></td>
    <td>Desired laser code for this jtac (1111~1788).</td>
  </tr>
  <tr>
    <td>#table <b>subMenuPath</b></td>
    <td>Sub menu branch path for the f10 menu (return value of missionCommands.addSubMenu).</td>
  </tr>
  <tr>
    <td>#string <b>commandName</b></td>
    <td>(optional)Name displayed in the f10 menu. Default is the same as jtacGroupName</td>
  </tr>
</table>

**Return values:**
<table>
  <tr>
    <td>#UavJtac</td>
    <td>self</td>
  </tr>
</table>

### `UavJtac:Destroy()`

UavJtac deconstructor. 
Call this function when the JTAC is no longer needed.
