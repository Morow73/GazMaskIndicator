require "ISUI/ISPanel"

local indicatorPanel = nil
local DEBUG = false
local PANEL_WIDTH = 150
local PANEL_HEIGHT = 42
local PANEL_MARGIN = 10
local ICON_SIZE = 32
local ICON_X = 5
local BAR_X = 42
local BAR_H = 12
local BAR_MAX_W = PANEL_WIDTH - 49
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

--- @class GazMaskFilterPanel : ISPanel
GazMaskFilterPanel = ISPanel:derive("GazMaskFilterPanel")

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

function GazMaskFilterPanel:new(x, y, width, height, maskTexture)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.maskTexture = maskTexture
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.5 }
    o.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.7 }
    o.filterPct = 0
    return o
end

function GazMaskFilterPanel:render()
    if self.maskTexture then
        local tex = self.maskTexture
        local y = math.floor((self.height - ICON_SIZE) / 2)
        self:drawTextureScaledAspect(tex, ICON_X, y, ICON_SIZE, ICON_SIZE, 1, 1, 1, 1)
    end

    ISPanel.render(self)

    local pct = math.max(0, math.min(100, self.filterPct or 0)) / 100
    local barY = math.floor((self.height - BAR_H) / 2)

    self:drawRect(BAR_X, barY, BAR_MAX_W, BAR_H, 1, 0, 0, 0)

    local fillW = math.max(0, BAR_MAX_W * pct)

    if fillW > 0 then
        local r, g, b = 0.2, 1, 0.3
        if pct < 0.2 then
            r, g, b = 1, 0, 0
        elseif pct < 0.5 then
            r, g, b = 1, 0.6, 0
        end
        self:drawRect(BAR_X + 1, barY + 1, fillW, BAR_H - 2, 1, r, g, b)
    end
end

function GazMaskFilterPanel:onMouseDown(x, y)
    self.dragging = true
    self.dragStartX = x
    self.dragStartY = y
    self:setCapture(true)
end

function GazMaskFilterPanel:onMouseMove(dx, dy)
    if self.dragging then
        self:setX(self:getX() + dx)
        self:setY(self:getY() + dy)
    end
end

function GazMaskFilterPanel:onMouseUp(x, y)
    self.dragging = false
    self:setCapture(false)
    self:savePosition()
end

function GazMaskFilterPanel:onMouseUpOutside(x, y)
    self.dragging = false
    self:setCapture(false)
    self:savePosition()
end

function GazMaskFilterPanel:destroy()
    self:removeFromUIManager()
    self:setCapture(false)
end

function GazMaskFilterPanel:savePosition()
    local localPlayer = getPlayer()
    if not localPlayer then return end
    local player = getSpecificPlayer(localPlayer:getPlayerNum())
    if not player then return end
    local modData = player:getModData()

    modData.GazMaskIndicator = {
        x = self:getX(),
        y = self:getY()
    }
end

function GazMaskFilterPanel:getSavedPosition()
    local localPlayer = getPlayer()
    if not localPlayer then return nil end
    local player = getSpecificPlayer(localPlayer:getPlayerNum())
    if not player then return nil end
    local modData = player:getModData()
    if type(modData.GazMaskIndicator) ~= "table" then return nil end
    return modData.GazMaskIndicator.x, modData.GazMaskIndicator.y
end

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

local function GMI_OnPlayerUpdate(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local mask = nil

    for _, mt in ipairs(BODY_LOCATION) do
        local worn = player:getWornItem(mt)
        if worn and ITEM_RESTRICTED[worn:getFullType()] then
            mask = worn
            break
        end
    end

    if not mask then
        if indicatorPanel then
            indicatorPanel.filterPct = 0
            indicatorPanel:destroy()
            indicatorPanel = nil
        end
        return
    end

    local maskData = {}
    local modData = mask:getModData()

    if type(modData) == "table" then
        for key, value in pairs(modData) do
            maskData[key] = value
        end
    end

    local rawPct = nil

    if maskData['usedDelta'] and (maskData['filterType'] or maskData['tankType']) then
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

Events.OnTick.Add(GMI_OnGameTick)
Events.OnPlayerDeath.Add(GMI_OnPlayerSpawn)
