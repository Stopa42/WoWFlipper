local addonName = ...

local WoWFlipper = {
    pendingItemID = nil,
    opportunities = nil,
    frame = nil,
    selectedBrowseItemID = nil,
    browseSelectionHooked = false,
    maxInvestmentCopper = nil,
}

WoWFlipperDB = WoWFlipperDB or {}

local COPPER_PER_GOLD = 10000
local COPPER_PER_SILVER = 100
local DEFAULT_POST_DURATION = 2

local function formatMoney(copper)
    local sign = ""
    local value = copper
    if value < 0 then
        sign = "-"
        value = -value
    end

    local gold = math.floor(value / COPPER_PER_GOLD)
    local silver = math.floor((value % COPPER_PER_GOLD) / COPPER_PER_SILVER)
    local copperRemainder = value % COPPER_PER_SILVER
    return string.format("%s%dg %ds %dc", sign, gold, silver, copperRemainder)
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

local function calculateOpportunities(rawListings, itemID, isCommodity)
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
        local deposit = 0
        if isCommodity and itemID and C_AuctionHouse and C_AuctionHouse.CalculateCommodityDeposit then
            deposit = C_AuctionHouse.CalculateCommodityDeposit(itemID, DEFAULT_POST_DURATION, quantity) or 0
        end

        local profit = revenue - totalCost - deposit
        local roi = 0

        if totalCost > 0 then
            roi = profit / totalCost
        end

        opportunities[#opportunities + 1] = {
            quantity = quantity,
            investment = totalCost,
            relistUnitPrice = nextMarketUnitPrice,
            revenue = revenue,
            deposit = deposit,
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

local function sampleOpportunities(opportunities, maxPoints)
    if #opportunities <= maxPoints then
        return opportunities
    end

    local sampled = {}
    local lastIndex = #opportunities
    for pointIndex = 1, maxPoints do
        local interpolation = (pointIndex - 1) / (maxPoints - 1)
        local sourceIndex = math.floor((interpolation * (lastIndex - 1)) + 1.5)
        sampled[#sampled + 1] = opportunities[sourceIndex]
    end

    return sampled
end

local function maxAbsProfit(opportunities)
    local maxValue = 0
    for _, entry in ipairs(opportunities) do
        maxValue = math.max(maxValue, math.abs(entry.profit))
    end

    return maxValue
end

local function buildProfitBar(value, maxValue, width)
    if maxValue <= 0 then
        return string.rep(".", width)
    end

    local magnitude = math.floor((math.abs(value) / maxValue) * width + 0.5)
    magnitude = math.max(0, math.min(width, magnitude))

    if value >= 0 then
        return string.rep("+", magnitude) .. string.rep(".", width - magnitude)
    end

    return string.rep("-", magnitude) .. string.rep(".", width - magnitude)
end

local function buildReportLines(opportunities)
    local maxChartPoints = 40
    local barWidth = 28
    local sampled = sampleOpportunities(opportunities, maxChartPoints)
    local peakProfit = maxAbsProfit(opportunities)

    local lines = {
        string.format(
            "Profit chart (%d sampled points from %d quantities)",
            #sampled,
            #opportunities
        ),
        "Qty | Profit | ROI | Chart",
        "--------------------------",
    }

    for _, entry in ipairs(sampled) do
        lines[#lines + 1] = string.format(
            "%d | %s | %.2f%% | %s",
            entry.quantity,
            formatMoney(entry.profit),
            entry.roi * 100,
            buildProfitBar(entry.profit, peakProfit, barWidth)
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

    lines[#lines + 1] = string.format("Chart scale: +/- %s", formatMoney(peakProfit))
    if opportunities[1] and opportunities[1].deposit and opportunities[1].deposit > 0 then
        lines[#lines + 1] = "Profit includes estimated AH deposit (24h repost)."
    end

    return lines
end

local function printReport(opportunities)
    local byProfit = bestByProfit(opportunities)
    local byROI = bestByROI(opportunities)
    local includesDeposit = opportunities[1] and opportunities[1].deposit and opportunities[1].deposit > 0

    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cff00ff96WoWFlipper|r Scan complete: %d quantity points analyzed.",
        #opportunities
    ))
    if includesDeposit then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff96WoWFlipper|r Profit includes estimated AH deposit (24h repost).")
    end

    if byProfit then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff00ff96WoWFlipper|r Best profit: %d units for %s.",
            byProfit.quantity,
            formatMoney(byProfit.profit)
        ))
    end

    if byROI then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff00ff96WoWFlipper|r Best ROI: %d units at %.2f%%.",
            byROI.quantity,
            byROI.roi * 100
        ))
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

local function parseMaxInvestmentGold(input)
    if not input then
        return nil, true
    end

    local trimmed = strtrim(input)
    if trimmed == "" then
        return nil, true
    end

    local goldValue = tonumber(trimmed)
    if not goldValue or goldValue < 0 then
        return nil, false
    end

    return math.floor((goldValue * COPPER_PER_GOLD) + 0.5), true
end

local processListingsForItem

local function tryUseExistingSearchResults(itemID)
    local commodityResultCount = C_AuctionHouse.GetNumCommoditySearchResults(itemID)
    if commodityResultCount and commodityResultCount > 0 then
        local listings = {}
        for index = 1, commodityResultCount do
            local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
            if result and result.quantity and result.unitPrice and result.quantity > 0 then
                listings[#listings + 1] = {
                    quantity = result.quantity,
                    unitPrice = result.unitPrice,
                }
            end
        end

        if #listings > 0 then
            processListingsForItem(itemID, listings, "WoWFlipper: No commodity listings found for that item.", true)
            print(string.format("WoWFlipper: Using existing commodity results for item %d.", itemID))
            return true
        end
    end

    local itemKey = { itemID = itemID }
    local itemResultCount = C_AuctionHouse.GetNumItemSearchResults(itemKey)
    if itemResultCount and itemResultCount > 0 then
        local listings = {}
        for index = 1, itemResultCount do
            local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
            if result and result.buyoutAmount and result.buyoutAmount > 0 then
                local quantity = result.quantity or 1
                if quantity > 0 then
                    listings[#listings + 1] = {
                        quantity = quantity,
                        unitPrice = math.floor(result.buyoutAmount / quantity),
                    }
                end
            end
        end

        if #listings > 0 then
            processListingsForItem(itemID, listings, "WoWFlipper: No item buyout listings found for that item.", false)
            print(string.format("WoWFlipper: Using existing item results for item %d.", itemID))
            return true
        end
    end

    return false
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
    if tryUseExistingSearchResults(itemID) then
        return
    end

    C_AuctionHouse.SendSearchQuery({ itemID = itemID }, {}, true)
    print(string.format("WoWFlipper: Query sent for item %d.", itemID))
end

local function readItemIDFromItemDisplay(itemDisplay)
    if not itemDisplay then
        return nil
    end

    if itemDisplay.GetItemID then
        local itemID = itemDisplay:GetItemID()
        if itemID then
            return itemID
        end
    end

    if itemDisplay.itemKey and itemDisplay.itemKey.itemID then
        return itemDisplay.itemKey.itemID
    end

    if itemDisplay.itemID then
        return itemDisplay.itemID
    end

    return nil
end

local function itemIDFromLink(link)
    if not link then
        return nil
    end

    local itemID = link:match("item:(%d+)")
    if itemID then
        return tonumber(itemID)
    end

    return nil
end

local function getItemIDFromRetailAuctionHouseSelection()
    if not AuctionHouseFrame then
        return nil
    end

    if WoWFlipper.selectedBrowseItemID then
        return WoWFlipper.selectedBrowseItemID
    end

    local framesToCheck = {
        AuctionHouseFrame.CommoditiesBuyFrame and AuctionHouseFrame.CommoditiesBuyFrame.ItemDisplay,
        AuctionHouseFrame.ItemBuyFrame and AuctionHouseFrame.ItemBuyFrame.ItemDisplay,
        AuctionHouseFrame.CommoditiesSellFrame and AuctionHouseFrame.CommoditiesSellFrame.ItemDisplay,
        AuctionHouseFrame.ItemSellFrame and AuctionHouseFrame.ItemSellFrame.ItemDisplay,
    }

    for _, itemDisplay in ipairs(framesToCheck) do
        local itemID = readItemIDFromItemDisplay(itemDisplay)
        if itemID then
            return itemID
        end
    end

    if AuctionHouseFrame.CommoditiesSellFrame and AuctionHouseFrame.CommoditiesSellFrame.itemID then
        return AuctionHouseFrame.CommoditiesSellFrame.itemID
    end

    if AuctionHouseFrame.ItemSellFrame and AuctionHouseFrame.ItemSellFrame.itemKey and AuctionHouseFrame.ItemSellFrame.itemKey.itemID then
        return AuctionHouseFrame.ItemSellFrame.itemKey.itemID
    end

    return nil
end

local function getItemIDFromClassicAuctionHouseSelection()
    if type(GetSelectedAuctionItem) ~= "function" then
        return nil
    end

    local selectedIndex = GetSelectedAuctionItem("list")
    if selectedIndex and selectedIndex > 0 then
        if type(GetAuctionItemInfo) == "function" then
            local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", selectedIndex)
            if itemID then
                return itemID
            end
        end

        if type(GetAuctionItemLink) == "function" then
            local selectedLink = GetAuctionItemLink("list", selectedIndex)
            local selectedItemID = itemIDFromLink(selectedLink)
            if selectedItemID then
                return selectedItemID
            end
        end
    end

    if BrowseName and BrowseName.GetText then
        local browseText = BrowseName:GetText()
        local browseItemID = parseItemID(browseText)
        if browseItemID then
            return browseItemID
        end
    end

    return nil
end

local function getItemIDFromAuctionHouseSelection()
    local retailItemID = getItemIDFromRetailAuctionHouseSelection()
    if retailItemID then
        return retailItemID
    end

    return getItemIDFromClassicAuctionHouseSelection()
end

local function hookBrowseSelection()
    if WoWFlipper.browseSelectionHooked or not AuctionHouseFrame then
        return
    end

    if type(AuctionHouseFrame.SelectBrowseResult) ~= "function" then
        return
    end

    hooksecurefunc(AuctionHouseFrame, "SelectBrowseResult", function(_, rowData)
        if rowData and rowData.itemKey and rowData.itemKey.itemID then
            WoWFlipper.selectedBrowseItemID = rowData.itemKey.itemID
        end
    end)

    WoWFlipper.browseSelectionHooked = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")

processListingsForItem = function(itemID, listings, noResultsMessage, isCommodity)
    if #listings == 0 then
        print(noResultsMessage)
        return
    end

    local opportunities = calculateOpportunities(listings, itemID, isCommodity)
    if WoWFlipper.maxInvestmentCopper and WoWFlipper.maxInvestmentCopper > 0 then
        local filtered = {}
        for _, entry in ipairs(opportunities) do
            if entry.investment <= WoWFlipper.maxInvestmentCopper then
                filtered[#filtered + 1] = entry
            end
        end
        opportunities = filtered
    end

    if #opportunities == 0 then
        if WoWFlipper.maxInvestmentCopper and WoWFlipper.maxInvestmentCopper > 0 then
            print(string.format(
                "WoWFlipper: No opportunities found within max investment of %s.",
                formatMoney(WoWFlipper.maxInvestmentCopper)
            ))
        else
            print(noResultsMessage)
        end
        return
    end

    WoWFlipper.opportunities = opportunities
    WoWFlipperDB.lastItemID = itemID
    WoWFlipperDB.lastScan = opportunities

    printReport(opportunities)
    updateFrame(opportunities)
end

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

    local useSelectedButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    useSelectedButton:SetSize(120, 24)
    useSelectedButton:SetText("Use Selected")
    useSelectedButton:SetPoint("LEFT", button, "RIGHT", 8, 0)

    local maxInvestmentLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxInvestmentLabel:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -10)
    maxInvestmentLabel:SetText("Max investment (gold, optional)")

    local maxInvestmentInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    maxInvestmentInput:SetSize(140, 24)
    maxInvestmentInput:SetPoint("TOPLEFT", maxInvestmentLabel, "BOTTOMLEFT", 0, -8)
    maxInvestmentInput:SetAutoFocus(false)

    if WoWFlipper.maxInvestmentCopper and WoWFlipper.maxInvestmentCopper > 0 then
        maxInvestmentInput:SetText(tostring(WoWFlipper.maxInvestmentCopper / COPPER_PER_GOLD))
    end

    local output = CreateFrame("EditBox", nil, frame)
    output:SetMultiLine(true)
    output:SetFontObject("GameFontHighlightSmall")
    output:SetPoint("TOPLEFT", maxInvestmentInput, "BOTTOMLEFT", 0, -12)
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

        local maxInvestmentCopper, ok = parseMaxInvestmentGold(maxInvestmentInput:GetText())
        if not ok then
            print("WoWFlipper: Enter a valid max investment amount in gold (for example: 2500 or 2500.5).")
            return
        end

        WoWFlipper.maxInvestmentCopper = maxInvestmentCopper
        WoWFlipperDB.maxInvestmentCopper = maxInvestmentCopper
        runScan(itemID)
    end)

    useSelectedButton:SetScript("OnClick", function()
        local itemID = getItemIDFromAuctionHouseSelection()
        if not itemID then
            print("WoWFlipper: Could not detect a selected item. Click a browse result first.")
            return
        end

        input:SetText(tostring(itemID))
        print(string.format("WoWFlipper: Selected item %d loaded.", itemID))
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

        WoWFlipper.maxInvestmentCopper = WoWFlipperDB.maxInvestmentCopper

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
        WoWFlipper.selectedBrowseItemID = nil
        hookBrowseSelection()
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

        processListingsForItem(itemID, listings, "WoWFlipper: No commodity listings found for that item.", true)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local itemKey = ...
        if not itemKey or not itemKey.itemID or itemKey.itemID ~= WoWFlipper.pendingItemID then
            return
        end

        local resultCount = C_AuctionHouse.GetNumItemSearchResults(itemKey)
        local listings = {}

        for index = 1, resultCount do
            local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
            if result and result.buyoutAmount and result.buyoutAmount > 0 then
                local quantity = result.quantity or 1
                if quantity > 0 then
                    listings[#listings + 1] = {
                        quantity = quantity,
                        unitPrice = math.floor(result.buyoutAmount / quantity),
                    }
                end
            end
        end

        processListingsForItem(itemKey.itemID, listings, "WoWFlipper: No item buyout listings found for that item.", false)
    end
end)
