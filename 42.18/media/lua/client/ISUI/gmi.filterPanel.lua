require("ISUI/ISPanel")

---@diagnostic disable: inject-field
--- @class GazMaskFilterPanel : ISPanel
--- @field maskTexture any
--- @field iconSize number
--- @field iconX number
--- @field barX number
--- @field barH number
--- @field barMaxW number
--- @field borderColor table
--- @field backgroundColor table
--- @field filterPct number
GazMaskFilterPanel = ISPanel:derive("GazMaskFilterPanel")

function GazMaskFilterPanel:new(x, y, width, height, maskTexture)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.maskTexture = maskTexture
    o.iconSize = 32
    o.iconX = 5
    o.barX = 42
    o.barH = 12
    o.barMaxW = width - 49
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.5 }
    o.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.7 }
    o.filterPct = 0
    return o
end

function GazMaskFilterPanel:render()
    if self.maskTexture then
        local tex = self.maskTexture
        local y = math.floor((self.height - self.iconSize) / 2)
        self:drawTextureScaledAspect(tex, self.iconX, y, self.iconSize, self.iconSize, 1, 1, 1, 1)
    end

    ISPanel.render(self)

    local pct = math.max(0, math.min(100, self.filterPct or 0)) / 100
    local barY = math.floor((self.height - self.barH) / 2)

    self:drawRect(self.barX, barY, self.barMaxW, self.barH, 1, 0, 0, 0)

    local fillW = math.max(0, self.barMaxW * pct)

    if fillW > 0 then
        local r, g, b = 0.2, 1, 0.3
        if pct < 0.2 then
            r, g, b = 1, 0, 0
        elseif pct < 0.5 then
            r, g, b = 1, 0.6, 0
        end
        self:drawRect(self.barX + 1, barY + 1, fillW, self.barH - 2, 1, r, g, b)
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

function GazMaskFilterPanel:onMouseUp()
    self.dragging = false
    self:setCapture(false)
    self:savePosition()
end

function GazMaskFilterPanel:onMouseUpOutside()
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