local Blitbuffer = require("ffi/blitbuffer")
local TextWidget = require("ui/widget/textwidget")
local CenterContainer = require("ui/widget/container/centercontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local NetworkMgr = require("ui/network/manager")
local BD = require("ui/bidi")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local Device = require("device")
local Font = require("ui/font")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local util = require("util")
local datetime = require("datetime")
local Screen = Device.screen
local _ = require("gettext")
local T = require("ffi/util").template
local ReaderView = require("apps/reader/modules/readerview")
local ReaderMenu = require("apps/reader/modules/readermenu")

-- Available header items
local HEADER_ITEMS = {
    time = { name = _("Current time"), generator = nil, is_spacer = false },
    battery = { name = T(_("Battery percentage (%1)"), ""), generator = nil, is_spacer = false },
    wifi = { name = T(_("Wi-Fi status (%1)"), ""), generator = nil, is_spacer = false },
    percentage = { name = T(_("Progress percentage (%1)"), "%"), generator = nil, is_spacer = false },
    page_progress = { name = T(_("Current page (%1)"), "/"), generator = nil, is_spacer = false },
    pages_left_book = { name = T(_("Pages left in book (%1)"), "→"), generator = nil, is_spacer = false },
    pages_left = { name = T(_("Pages left in chapter (%1)"), "⇒"), generator = nil, is_spacer = false },
    chapter_progress = { name = T(_("Current page in chapter (%1)"), "//"), generator = nil, is_spacer = false },
-- CRASH ZONE --    
   -- book_time_to_read = { name = T(_("Time left to finish book (%1)"), "⌚"), generator = nil, is_spacer = false },
   -- chapter_time_to_read = { name = T(_("Time left to finish chapter (%1)"), "⤻"), generator = nil, is_spacer = false },
-- END OF CRASH ZONE --
    title = { name = _("Book title"), generator = nil, is_spacer = false },
    author = { name = _("Book author"), generator = nil, is_spacer = false },
    chapter = { name = _("Chapter title"), generator = nil, is_spacer = false },
    frontlight = { name = T(_("Brightness level (%1)"), "☼"), generator = nil, is_spacer = false },
    frontlight_warmth = { name = T(_("Warmth level (%1)"), "⊛"), generator = nil, is_spacer = false },
    mem_usage = { name = T(_("KOReader memory usage (%1)"), ""), generator = nil, is_spacer = false },
    bookmark_count = { name = T(_("Bookmark count (%1)"), "\u{F097}"), generator = nil, is_spacer = false },
    spacer = { name = _("Dynamic filler"), generator = nil, is_spacer = true },
}

-- Menu order
local ITEMS_ORDER = {
    "time", "battery", "wifi", "percentage", "page_progress", "chapter_progress",
    "pages_left_book", "pages_left",
   -- "book_time_to_read", "chapter_time_to_read",
    "title", "author", "chapter",
    "frontlight", "frontlight_warmth", "mem_usage", "bookmark_count",
    "spacer"
}

-- Default header items
local header_defaults = {
    enabled = true,
    items = {"time", "battery", "spacer", "percentage"},
    item_separator = "  ",
}

local function getHeaderSettings()
    local settings = G_reader_settings:readSetting("custom_header")
    if not settings then
        settings = util.tableDeepCopy(header_defaults)
        G_reader_settings:saveSetting("custom_header", settings)
    end
    if not settings.items then settings.items = {"time", "battery", "spacer", "percentage"} end
    if not settings.item_separator then settings.item_separator = "  " end
    if settings.enabled == nil then settings.enabled = true end
    return settings
end

local function saveHeaderSettings(settings)
    G_reader_settings:saveSetting("custom_header", settings)
end

local function isHeaderEnabled()
    return getHeaderSettings().enabled
end

local function hasItem(items_list, item_key)
    for _, key in ipairs(items_list) do
        if key == item_key then return true end
    end
    return false
end

local function toggleItem(items_list, item_key)
    for i, key in ipairs(items_list) do
        if key == item_key then
            table.remove(items_list, i)
            return
        end
    end
    table.insert(items_list, item_key)
end

local _ReaderView_paintTo_orig = ReaderView.paintTo
local _ReaderView_onSetDimensions_orig = nil
local header_settings = G_reader_settings:readSetting("footer")
local screen_width = Screen:getWidth()

-- Touch zones
local function setupHeaderTouchZone(reader_ui)
    if not Device:isTouchDevice() then return end
    
    local header_height = Size.item.height_default -- touch zone height
    local header_zone = {
        ratio_x = 0, 
        ratio_y = 0,
        ratio_w = 1, 
        ratio_h = header_height / Screen:getHeight(),
    }
    
    reader_ui:registerTouchZones({
        {
            id = "reader_header_tap",
            ges = "tap",
            screen_zone = header_zone,
            handler = function(ges)
                local h_settings = getHeaderSettings()
                h_settings.enabled = not h_settings.enabled
                saveHeaderSettings(h_settings)
                UIManager:setDirty(reader_ui.dialog, "ui")
                return true
            end,
            overrides = {
                "readerconfigmenu_ext_tap",
                "readerconfigmenu_tap",
            },
        },
    })
end

-- Main function
ReaderView.paintTo = function(self, bb, x, y)
    _ReaderView_paintTo_orig(self, bb, x, y)
    if self.render_mode ~= nil then return end -- Show only for epub-likes
    if not isHeaderEnabled() then return end -- Exit if disabled
    
    local h_settings = getHeaderSettings()
    
    -- ===========================!!!!!!!!!!!!!!!=========================== -
    -- Configure formatting options for header here, if desired (defaults to footer options)
    local header_font_face = "ffont"
    local header_font_size = header_settings and header_settings.text_font_size or 14
    local header_font_bold = header_settings and header_settings.text_font_bold or false
    local header_font_color = Blitbuffer.COLOR_BLACK
    local header_top_padding = Size.padding.small
    local header_use_book_margins = true
    local header_margin = Size.padding.large
    local left_max_width_pct = 48
    local right_max_width_pct = 48
    -- ===========================!!!!!!!!!!!!!!!=========================== -

    -- Item generators
    HEADER_ITEMS.time.generator = function()
        return datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock")) or ""
    end
    
    HEADER_ITEMS.battery.generator = function()
        local battery = ""
        if Device:hasBattery() then
            local power_dev = Device:getPowerDevice()
            local batt_lvl = power_dev:getCapacity() or 0
            local is_charging = power_dev:isCharging() or false
            local batt_prefix = power_dev:getBatterySymbol(power_dev:isCharged(), is_charging, batt_lvl) or ""
            battery = batt_prefix .. batt_lvl .. "%"
        end
        return battery
    end
    
    HEADER_ITEMS.wifi.generator = function()
        if NetworkMgr:isWifiOn() then
            return ""
        else
            return ""
        end
    end
    
    HEADER_ITEMS.percentage.generator = function()
        local pageno = self.state.page or 1
        local pages = self.ui.doc_settings.data.doc_pages or 1
        local percentage = (pageno / pages) * 100
        return string.format("%.0f", percentage) .. "%"
    end
    
    HEADER_ITEMS.page_progress.generator = function()
        local pageno = self.state.page or 1
        local pages = self.ui.doc_settings.data.doc_pages or 1
        return ("%d / %d"):format(pageno, pages)
    end
    
    HEADER_ITEMS.pages_left_book.generator = function()
        local pageno = self.state.page or 1
        local pages = self.ui.doc_settings.data.doc_pages or 1
        local remaining = pages - pageno
        return ("→ %d / %d"):format(remaining, pages)
    end
    
    HEADER_ITEMS.pages_left.generator = function()
        local pageno = self.state.page or 1
        if self.ui.toc then
            local left = self.ui.toc:getChapterPagesLeft(pageno) or 0
            return ("⇒ %d"):format(left)
        end
        return ""
    end
    
    HEADER_ITEMS.chapter_progress.generator = function()
        local pageno = self.state.page or 1
        if self.ui.toc then
            local pages_done = self.ui.toc:getChapterPagesDone(pageno) or 0
            pages_done = pages_done + 1
            local pages_chapter = self.ui.toc:getChapterPageCount(pageno) or 0
            if pages_chapter > 0 then
                return ("%d // %d"):format(pages_done, pages_chapter)
            end
        end
        return ""
    end

-- CRASH ZONE --
    
    -- HEADER_ITEMS.book_time_to_read.generator = function()
    --     local pageno = self.state.page or 1
    --         local left = self.ui.document:getTotalPagesLeft(pageno)
    --         local time_str = self.ui.statistics:getTimeForPages(left)
    --     return time_str
    -- end
    
    -- HEADER_ITEMS.chapter_time_to_read.generator = function()
    --     local pageno = self.state.page or 1
    --         local left = self.ui.toc:getChapterPagesLeft(pageno) or self.ui.document:getTotalPagesLeft(pageno)
    --         local time_str = self.ui.statistics:getTimeForPages(left)
    --     return time_str
    -- end

-- END OF CRASH ZONE --
    
    HEADER_ITEMS.title.generator = function()
        if self.ui.doc_props then
            return self.ui.doc_props.display_title or ""
        end
        return ""
    end
    
    HEADER_ITEMS.author.generator = function()
        if self.ui.doc_props then
            local author = self.ui.doc_props.authors or ""
            if author:find("\n") then
                author = T(_("%1 et al."), util.splitToArray(author, "\n")[1])
            end
            return author
        end
        return ""
    end
    
    HEADER_ITEMS.chapter.generator = function()
        local pageno = self.state.page or 1
        if self.ui.toc then
            return self.ui.toc:getTocTitleByPage(pageno) or ""
        end
        return ""
    end
    
    HEADER_ITEMS.frontlight.generator = function()
        if Device:hasFrontlight() then
            local powerd = Device:getPowerDevice()
            if powerd:isFrontlightOn() then
                local level = powerd:frontlightIntensity()
                if Device:isCervantes() or Device:isKobo() then
                    return "☼" .. ("%d%%"):format(level)
                else
                    return "☼" .. ("%d"):format(level)
                end
            else
                return "☼" .. _("Off")
            end
        end
        return ""
    end
    
    HEADER_ITEMS.frontlight_warmth.generator = function()
        if Device:hasNaturalLight() then
            local powerd = Device:getPowerDevice()
            if powerd:isFrontlightOn() then
                local warmth = powerd:frontlightWarmth()
                if warmth then
                    return "⊛" .. ("%d%%"):format(warmth)
                end
            else
                return "⊛" .. _("Off")
            end
        end
        return ""
    end
    
    HEADER_ITEMS.mem_usage.generator = function()
        local statm = io.open("/proc/self/statm", "r")
        if statm then
            local dummy, rss = statm:read("*number", "*number")
            statm:close()
            rss = math.floor(rss * (4096 / 1024 / 1024))
            return "" .. ("%d MiB"):format(rss)
        end
        return ""
    end
    
    HEADER_ITEMS.bookmark_count.generator = function()
        if self.ui.annotation then
            local count = self.ui.annotation:getNumberOfAnnotations()
            return "\u{F097}" .. ("%d"):format(count)
        end
        return ""
    end

    -- Spacer 
    local function buildHeaderWidgets()
        local groups = {}
        local current_group = {}
        
        for _, item_key in ipairs(h_settings.items) do
            local item = HEADER_ITEMS[item_key]
            if item then
                if item.is_spacer then
                   
                    if #current_group > 0 then
                        table.insert(groups, current_group)
                        current_group = {}
                    end
                    table.insert(groups, "spacer")
                elseif item.generator then
                    local text = item.generator()
                    if text and text ~= "" then
                        table.insert(current_group, text)
                    end
                end
            end
        end

        if #current_group > 0 then
            table.insert(groups, current_group)
        end
        
        local text_groups = {}
        for _, group in ipairs(groups) do
            if type(group) == "table" then
                table.insert(text_groups, table.concat(group, h_settings.item_separator))
            else
                table.insert(text_groups, group)
            end
        end
        
        return text_groups
    end
    
    local text_groups = buildHeaderWidgets()

    -- Calculate margins
    local margins = 0
    local left_margin = header_margin
    local right_margin = header_margin
    if header_use_book_margins then
        left_margin = self.document:getPageMargins().left or header_margin
        right_margin = self.document:getPageMargins().right or header_margin
    end
    margins = left_margin + right_margin
    local avail_width = screen_width - margins

    -- Helper function to fit text
    local function getFittedText(text, max_width_pct)
        if text == nil or text == "" then
            return ""
        end
        local text_widget = TextWidget:new{
            text = text:gsub(" ", "\u{00A0}"),
            max_width = avail_width,
            face = Font:getFace(header_font_face, header_font_size),
            bold = header_font_bold,
            padding = 0,
        }
        local fitted_text, add_ellipsis = text_widget:getFittedText()
        text_widget:free()
        if add_ellipsis then
            fitted_text = fitted_text .. "…"
        end
        return BD.auto(fitted_text)
    end

    -- Build header widgets from text groups
    local header_widgets = {}
    local total_text_width = 0
    local spacer_count = 0
    
    for _, group in ipairs(text_groups) do
        if group == "spacer" then
            spacer_count = spacer_count + 1
            table.insert(header_widgets, "spacer")
        else
            local fitted = getFittedText(group, 48)
            local text_widget = TextWidget:new {
                text = fitted,
                face = Font:getFace(header_font_face, header_font_size),
                bold = header_font_bold,
                fgcolor = header_font_color,
                padding = 0,
            }
            total_text_width = total_text_width + text_widget:getSize().w
            table.insert(header_widgets, text_widget)
        end
    end
    
    -- Calculate spacer width
    local spacer_width = 0
    if spacer_count > 0 then
        spacer_width = math.max(0, (avail_width - total_text_width) / spacer_count)
    end
    
    -- Build horizontal group with spacers
    local horizontal_items = {}
    for _, widget in ipairs(header_widgets) do
        if widget == "spacer" then
            table.insert(horizontal_items, HorizontalSpan:new { width = spacer_width })
        else
            table.insert(horizontal_items, widget)
        end
    end
    
    -- If no spacers, align everything to the left (add spacer at the end)
    if spacer_count == 0 then
        local remaining_space = avail_width - total_text_width
        if remaining_space > 0 then
            table.insert(horizontal_items, HorizontalSpan:new { width = remaining_space })
        end
    end
    
    -- Calculate header height
    local max_height = 0
    for _, widget in ipairs(header_widgets) do
        if widget ~= "spacer" then
            max_height = math.max(max_height, widget:getSize().h)
        end
    end

    -- Build header widget
    local header = CenterContainer:new {
        dimen = Geom:new{ 
            w = screen_width, 
            h = max_height + header_top_padding 
        },
        VerticalGroup:new {
            VerticalSpan:new { width = header_top_padding },
            HorizontalGroup:new(horizontal_items)
        },
    }
    header:paintTo(bb, x, y)
end

-- Menu
local ReaderUI = require("apps/reader/readerui")
local orig_ReaderUI_init = ReaderUI.init

function ReaderUI:init()
    orig_ReaderUI_init(self)
    setupHeaderTouchZone(self)
end

local orig_ReaderMenu_setUpdateItemTable = ReaderMenu.setUpdateItemTable

function ReaderMenu:setUpdateItemTable()
    local menu_order = require("ui/elements/reader_menu_order")
    local SortWidget = require("ui/widget/sortwidget")
    
    -- Helper function to create multi-select item list
    local function createItemsSelector()
        return {
            text_func = function()
                local h_settings = getHeaderSettings()
                local count = #h_settings.items
                return T(_("Header items (%1)"), count)
            end,
            sub_item_table = (function()
                local items = {}
                for _, key in ipairs(ITEMS_ORDER) do
                    local item = HEADER_ITEMS[key]
                    table.insert(items, {
                        text = item.name,
                        checked_func = function()
                            local h_settings = getHeaderSettings()
                            return hasItem(h_settings.items, key)
                        end,
                        callback = function(touchmenu_instance)
                            local h_settings = getHeaderSettings()
                            toggleItem(h_settings.items, key)
                            saveHeaderSettings(h_settings)
                            touchmenu_instance:updateItems()
                            if self.ui and self.ui.document then
                                UIManager:setDirty(self.ui.dialog, "ui")
                            end
                        end,
                    })
                end
                return items
            end)(),
        }
    end
    
    -- Helper function to create reorder using SortWidget
    local function createReorderMenu()
        return {
            text = _("Arrange items"),
            keep_menu_open = true,
            enabled_func = function()
                local h_settings = getHeaderSettings()
                return #h_settings.items > 1
            end,
            callback = function()
                local h_settings = getHeaderSettings()
                local item_table = {}
                
                for i, key in ipairs(h_settings.items) do
                    local item = HEADER_ITEMS[key]
                    if item then
                        table.insert(item_table, {
                            text = item.name,
                            label = key,
                        })
                    end
                end
                
                UIManager:show(SortWidget:new{
                    title = _("Arrange header items"),
                    item_table = item_table,
                    callback = function()
                        local new_items = {}
                        for i, item in ipairs(item_table) do
                            table.insert(new_items, item.label)
                        end
                        h_settings.items = new_items
                        saveHeaderSettings(h_settings)
                        if self.ui and self.ui.document then
                            UIManager:setDirty(self.ui.dialog, "ui")
                        end
                    end,
                })
            end,
        }
    end
    
    -- Main Header submenu
    table.insert(menu_order.setting, "----------------------------")
    table.insert(menu_order.setting, "header_toggle")
    table.insert(menu_order.setting, "header_settings")
    
    self.menu_items.header_toggle = {
        text = _("Show header"),
        checked_func = isHeaderEnabled,
        callback = function(touchmenu_instance)
            local h_settings = getHeaderSettings()
            h_settings.enabled = not h_settings.enabled
            saveHeaderSettings(h_settings)
            touchmenu_instance:updateItems()
            if self.ui and self.ui.document then
                UIManager:setDirty(self.ui.dialog, "ui")
            end
        end,
    }
    
    self.menu_items.header_settings = {
        text = _("Header"),
        sub_item_table = {
            createItemsSelector(),
            createReorderMenu(),
        },
    }
    
    orig_ReaderMenu_setUpdateItemTable(self)
end