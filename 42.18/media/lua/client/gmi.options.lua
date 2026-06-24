local Options = {
    { id = "gmi_toggle_mask", description = "Toggle mask keybind.", key = Keyboard.KEY_NONE},
}

local PZ_Options = PZAPI.ModOptions:create("gmi_options", "Gaz Mask Indicator")
local GMI_Options_KeyBind = PZ_Options:addKeyBind(
    Options[1].id,
    Options[1].description,
    Options[1].key
)

function GMI_GetOptions()
    return GMI_Options_KeyBind:getValue()
end

PZ_Options.apply = function(self) end
