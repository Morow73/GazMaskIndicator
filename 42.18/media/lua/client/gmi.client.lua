local indicatorPanel = nil
local DEBUG = false
local PANEL_WIDTH = 150
local PANEL_HEIGHT = 42
local PANEL_MARGIN = 10
local BODY_LOCATION = {
    ItemBodyLocation.FULL_HAT,
    ItemBodyLocation.MASK_EYES,
    ItemBodyLocation.MASK_FULL,
    ItemBodyLocation.MASK,
    ItemBodyLocation.FULL_SUIT_HEAD_SCBA,
    ItemBodyLocation.SCBA
}
local ITEM_RESTRICTED = {
    ["Base.Hat_NBCmask"] = true,
    ["Base.Hat_GasMask"] = true,
    ["Base.SCBA"] = true,
    ["Base.Hat_BuildersRespirator"] = true,
    ["Base.Hat_ImprovisedGasMask"] = true
}

local function GMI_round(num, dec)
    local mult = 10 ^ (dec or 2)
    return math.floor(num * mult + 0.5) / mult
end

if DEBUG then
    function DUMP(o)
        if type(o) == 'table' then
            local s = '{ '
            for k, v in pairs(o) do
                if type(k) ~= 'number' then k = '"' .. k .. '"' end
                s = s .. '[' .. k .. '] = ' .. DUMP(v) .. ','
            end
            return s .. '} '
        else
            return tostring(o)
        end
    end
end

---@param texture Texture
---@return ISPanel
local function GMI_CreateIndicatorPanel(texture)
    if indicatorPanel then return indicatorPanel end

    local screenW = getCore() and getCore():getScreenWidth() or 1920
    local screenH = getCore() and getCore():getScreenHeight() or 1080
    local x = screenW - PANEL_WIDTH - PANEL_MARGIN
    local y = screenH - PANEL_HEIGHT - 80
    local savedX, savedY = GazMaskFilterPanel:getSavedPosition()

    if type(savedX) == "number" and type(savedY) == "number" then
        x = savedX
        y = savedY
    end

    indicatorPanel = GazMaskFilterPanel:new(x, y, PANEL_WIDTH, PANEL_HEIGHT, texture)
    indicatorPanel:initialise()
    indicatorPanel:setVisible(true)
    indicatorPanel:addToUIManager()

    return indicatorPanel
end

---return player inventory
---@param player IsoPlayer
---@return ItemContainer|nil
local function GMI_GetPlayerInventory(player)
    if not player then return nil end

    local inventory = player:getInventory()
    if not inventory then return nil end

    return inventory
end

---return if player worn a mask
---@param player IsoPlayer
---@return InventoryItem|nil
local function GMI_GetPlayerMaskUsed(player)
    for _, mt in ipairs(BODY_LOCATION) do
        local worn = player:getWornItem(mt)
        local fullType = worn:getFullType()

        if worn and ITEM_RESTRICTED[fullType] then
            return worn
        end
    end
    return nil
end

---return mask item data
---@param mask InventoryItem
---@return table|nil
function GMI_GetMaskData(mask)
    if not mask then return nil end

    local modData = mask:getModData()
    local maskData = {}

    if type(modData) == "table" then
        for key, value in pairs(modData) do
            maskData[key] = value
        end
    end

    return maskData
end

---player update
---@param playerNum integer
local function GMI_OnPlayerUpdate(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local mask = GMI_GetPlayerMaskUsed(player)

    if not mask then
        if indicatorPanel then
            indicatorPanel.filterPct = 0
            indicatorPanel:destroy()
            indicatorPanel = nil
        end
        return
    end

    local maskData = GMI_GetMaskData(mask)
    local rawPct = nil

    if maskData and maskData['usedDelta'] and (maskData['filterType'] or maskData['tankType']) then
        rawPct = GMI_round(maskData['usedDelta'] * 100)

        if rawPct <= 0 then
            rawPct = nil
        else
            rawPct = math.min(100, rawPct)
        end
    end

    if DEBUG then
        print("[GazMaskIndicator] mask=" .. mask:getFullType())
        print(DUMP(maskData))
    end

    local texture = mask:getTexture()

    if indicatorPanel and indicatorPanel.maskTexture ~= texture then
        indicatorPanel.maskTexture = texture
    end

    if not indicatorPanel then
        GMI_CreateIndicatorPanel(texture)
    end

    if rawPct and indicatorPanel then
        indicatorPanel:setVisible(true)
        indicatorPanel.filterPct = rawPct
        return
    end

    if indicatorPanel then
        indicatorPanel.filterPct = 0
        indicatorPanel:setVisible(false)
    end
end

local function GMI_OnPlayerSpawn()
    if indicatorPanel then
        indicatorPanel:destroy()
        indicatorPanel = nil
    end
end

local function GMI_OnGameTick()
    local localPlayer = getPlayer()
    if localPlayer then
        GMI_OnPlayerUpdate(localPlayer:getPlayerNum())
    end
end

local function GMI_OnKeyPressed(key)
    if key == Keyboard.KEY_NONE or key ~= GMI_GetOptions() then return end

    local player = getSpecificPlayer(0)

    if not player or player:isDead() then return end

    local maskItem, equiped = nil, false

    local mask = GMI_GetPlayerMaskUsed(player)

    if mask then
        maskItem = mask
        equiped = true
    end

    if not maskItem then
        local inventory = GMI_GetPlayerInventory(player)

        if not inventory or not inventory.getItems then return end

        local items = inventory:getItems()
        local low = math.huge
        if not items then return end

        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local fullType = item:getFullType()

            if ITEM_RESTRICTED[fullType] then
                local modData = GMI_GetMaskData(item)

                if modData and modData['usedDelta'] and (modData['filterType'] or modData['tankType']) then
                    local rawPct = GMI_round(modData['usedDelta'] * 100)

                    if rawPct > 0 and rawPct < low then
                        low = rawPct
                        maskItem = item
                    end
                end
            end
        end
    end

    if maskItem then
        if not equiped then
            ISInventoryPaneContextMenu.wearItem(maskItem, player:getPlayerNum())
        else
            ISTimedActionQueue.add(ISUnequipAction:new(player, maskItem, 50))
        end
    end

    if indicatorPanel then
        indicatorPanel:setVisible(equiped)
    end
end

Events.OnTick.Add(GMI_OnGameTick)
Events.OnPlayerDeath.Add(GMI_OnPlayerSpawn)
Events.OnKeyPressed.Add(GMI_OnKeyPressed)
