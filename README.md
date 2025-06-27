# DCS-UAV-JTAC

A simple script to setup JTAC for an UAV-like unit.
Requires [MIST](https://github.com/mrSkortch/MissionScriptingTools)

## How to Use

Place a trigger zone (must be round) in the ME as the area to scan targets.

Place a airborne unit (such as a UAV) near the trigger zone and set it to orbit.

Load both MIST script and this script in order at mission start.

Use example:

```lua
local jtac = UavJtac:New(coalition.side.BLUE, "jtac-unit-name", "jtac-zone-name", 1688, "menu-item-name", "menu-sub-branch-name")
```

## How It Works



## F10 Menu Option

1. Show Target Info
2. Smoke Target
3. Change to Next Target
4. Change to Previous Target
5. Refresh Target List

## Document

### `UavJtac:New(side, jtacUnitName, targetZoneName, laserCode, commandName, subMenuName)`

UavJtac constructor.
All functionality will automatically start after the call.

**Parameters:**
<table>
  <tr>
    <td>#table/enum <b>side</b></td>
    <td>Coalition of this jtac belongs to. Either coalition.side.RED or coalition.side.BLUE</td>
  </tr>
  <tr>
    <td>#string <b>jtacUnitName</b></td>
    <td>Unit name of the jtac unit in ME.</td>
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
    <td>#string <b>commandName</b></td>
    <td>(optional)Name displayed in the f10 menu. Default is the same as jtacUnitName.</td>
  </tr>
  <tr>
    <td>#string <b>subMenuName</b></td>
    <td>(optional)Sub menu branch name for the f10 menu to located in. Default is "JTAC".</td>
  </tr>
</table>

**Return values:**
<table>
  <tr>
    <td>#UavJtac</td>
    <td>self</td>
  </tr>
</table>
