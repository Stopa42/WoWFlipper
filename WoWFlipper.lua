local addonName = ...

local WoWFlipper = {
    pendingItemID = nil,
    opportunities = nil,
    frame = nil,
}

WoWFlipperDB = WoWFlipperDB or {}

local COPPER_PER_GOLD = 10000
local COPPER_PER_SILVER = 100

local function formatMoney(copper)
    local gold = math.floor(copper / COPPER_PER_GOLD)
    local silver = math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local copperRemainder = copper % COPPER_PER_SILVER
    return string.format("%dg %ds %dc", gold, silver, copperRemainder)
end

local function copyListings(rawListings)
    local copied = {}
    for _, listing in ipairs(rawListings) do
        copied[#copied + 1] = {
            unitPrice = listing.unitPrice,
            quantity = listing.quantity,
        }
    end

    table.sort(copied, function(left, right)
        if left.unitPrice == right.unitPrice then
            return left.quantity < right.quantity
        end

        return left.unitPrice < right.unitPrice
    end)

    return copied
end

local function flattenPrices(listings)
    local prices = {}
    for _, listing in ipairs(listings) do
        for _ = 1, listing.quantity do
            prices[#prices + 1] = listing.unitPrice
        end
    end

    return prices
end

local function calculateOpportunities(rawListings)
    local listings = copyListings(rawListings)
    local flattenedPrices = flattenPrices(listings)

    local opportunities = {}
    local totalCost = 0
    local maxPurchasedUnitPrice = 0

    for quantity = 1, #flattenedPrices do
        local currentUnitPrice = flattenedPrices[quantity]
        totalCost = totalCost + currentUnitPrice
        maxPurchasedUnitPrice = math.max(maxPurchasedUnitPrice, currentUnitPrice)

        local nextMarketUnitPrice = flattenedPrices[quantity + 1] or maxPurchasedUnitPrice
        local revenue = quantity * nextMarketUnitPrice
        local profit = revenue - totalCost
        local roi = 0

        if totalCost > 0 then
            roi = profit / totalCost
        end

        opportunities[#opportunities + 1] = {
            quantity = quantity,
            investment = totalCost,
            relistUnitPrice = nextMarketUnitPrice,
            revenue = revenue,
            profit = profit,
            roi = roi,
        }
    end

    return opportunities
end

local function bestByProfit(opportunities)
    local best = nil
    for _, entry in ipairs(opportunities) do
        if not best or entry.profit > best.profit then
            best = entry
        end
    end

    return best
end

local function bestByROI(opportunities)
    local best = nil
    for _, entry in ipairs(opportunities) do
        if entry.investment > 0 and (not best or entry.roi > best.roi) then
            best = entry
        end
    end

    return best
end

local function buildReportLines(opportunities)
    local lines = {
        "Qty | Investment | Relist Unit Price | Revenue | Profit | ROI",
        "---------------------------------------------------------------",
    }

    for _, entry in ipairs(opportunities) do
        lines[#lines + 1] = string.format(
            "%d | %s | %s | %s | %s | %.2f%%",
            entry.quantity,
            formatMoney(entry.investment),
            formatMoney(entry.relistUnitPrice),
            formatMoney(entry.revenue),
            formatMoney(entry.profit),
            entry.roi * 100
        )
    end

    local byProfit = bestByProfit(opportunities)
    local byROI = bestByROI(opportunities)

    if byProfit then
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format(
            "Best absolute profit: %d units for %s profit.",
            byProfit.quantity,
            formatMoney(byProfit.profit)
        )
    end

    if byROI then
        lines[#lines + 1] = string.format(
            "Best ROI: %d units at %.2f%%.",
            byROI.quantity,
            byROI.roi * 100
        )
    end

    return lines
end

local function printReport(opportunities)
    for _, line in ipairs(buildReportLines(opportunities)) do
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96WoWFlipper|r " .. line)
    end
end

local function updateFrame(opportunities)
    if not WoWFlipper.frame then
        return
    end

    local lines = buildReportLines(opportunities)
    WoWFlipper.frame.output:SetText(table.concat(lines, "\n"))
end

local function parseItemID(input)
    if not input or input == "" then
        return nil
    end

    local itemID = tonumber(input)
    if itemID then
        return itemID
    end

    local linkItemID = input:match("item:(%d+)")
    if linkItemID then
        return tonumber(linkItemID)
    end

    return nil
end

local function runScan(itemID)
    if not C_AuctionHouse then
        print("WoWFlipper: Auction House API is unavailable.")
        return
    end

    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
        print("WoWFlipper: Open the Auction House before scanning.")
        return
    end

    WoWFlipper.pendingItemID = itemID
    C_AuctionHouse.SendSearchQuery({ itemID = itemID }, {}, true)
    print(string.format("WoWFlipper: Query sent for item %d.", itemID))
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")

local function createWindow()
    if WoWFlipper.frame then
        return
    end

    local frame = CreateFrame("Frame", "WoWFlipperFrame", AuctionHouseFrame, "BackdropTemplate")
    frame:SetSize(560, 340)
    frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 20, -20)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.95)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("WoWFlipper")

    local inputLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -14)
    inputLabel:SetText("Item ID or item link")

    local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    input:SetSize(220, 24)
    input:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 0, -8)
    input:SetAutoFocus(false)

    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(100, 24)
    button:SetText("Scan")
    button:SetPoint("LEFT", input, "RIGHT", 8, 0)

    local output = CreateFrame("EditBox", nil, frame)
    output:SetMultiLine(true)
    output:SetFontObject("GameFontHighlightSmall")
    output:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -12)
    output:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    output:SetTextInsets(8, 8, 8, 8)
    output:SetAutoFocus(false)
    output:EnableMouse(true)
    output:SetScript("OnEscapePressed", output.ClearFocus)

    local outputBackground = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    outputBackground:SetPoint("TOPLEFT", output, "TOPLEFT", -4, 4)
    outputBackground:SetPoint("BOTTOMRIGHT", output, "BOTTOMRIGHT", 4, -4)
    outputBackground:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    outputBackground:SetBackdropColor(0.08, 0.08, 0.08, 0.9)

    button:SetScript("OnClick", function()
        local itemID = parseItemID(input:GetText())
        if not itemID then
            print("WoWFlipper: Enter a valid item ID or item link.")
            return
        end

        runScan(itemID)
    end)

    frame.output = output
    frame:Hide()

    WoWFlipper.frame = frame
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= addonName then
            return
        end

        SLASH_WOWFLIPPER1 = "/wowflipper"
        SlashCmdList.WOWFLIPPER = function(msg)
            local itemID = parseItemID(msg)
            if not itemID then
                print("WoWFlipper: Usage /wowflipper <itemID|itemLink>")
                return
            end

            runScan(itemID)
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        createWindow()
        WoWFlipper.frame:Show()
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local itemID = ...
        if itemID ~= WoWFlipper.pendingItemID then
            return
        end

        local resultCount = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
        local listings = {}

        for index = 1, resultCount do
            local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
            if result and result.quantity and result.unitPrice and result.quantity > 0 then
                listings[#listings + 1] = {
                    quantity = result.quantity,
                    unitPrice = result.unitPrice,
                }
            end
        end

        if #listings == 0 then
            print("WoWFlipper: No commodity listings found for that item.")
            return
        end

        local opportunities = calculateOpportunities(listings)
        WoWFlipper.opportunities = opportunities
        WoWFlipperDB.lastItemID = itemID
        WoWFlipperDB.lastScan = opportunities

        printReport(opportunities)
        updateFrame(opportunities)
    end
end)
