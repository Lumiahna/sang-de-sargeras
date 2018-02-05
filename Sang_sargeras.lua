-- Condition vendeur/money etc
local NPCID_BLOODTRADER = 115264
local NPCID_PRIMALTRADER = 129674
local ITEMID_BLOOD = 124124
local ITEMID_PRIMAL = 151568
local INDEX_BLOODTRADER_CACHE = 1
local INDEX_BLOODTRADER_BIGCACHE = 2
local CURRENCYID_RESOURCES = 1220

-- bloquer l'interraction avec le vendeur de sang de sargeras.
local function IsBloodTrader()
  local guid = UnitGUID("npc")
  if not guid then return end
  local _, _, _, _, _, npcid = strsplit("-", guid)
  if not npcid then return end
  npcid = tonumber(npcid)
  if npcid == NPCID_BLOODTRADER or npcid == NPCID_PRIMALTRADER then return npcid end
end

-- aide sur cache
local function IsCache(index)
   if index == INDEX_BLOODTRADER_CACHE or index == INDEX_BLOODTRADER_BIGCACHE then return true end
end


-- affichage ressources

MerchantFrame_UpdateCurrencies = function()
  local currencies = { GetMerchantCurrencies() }
  if IsBloodTrader() == NPCID_BLOODTRADER then
    currencies = { -ITEMID_BLOOD, CURRENCYID_RESOURCES }
  elseif IsBloodTrader() == NPCID_PRIMALTRADER then
    currencies = { -ITEMID_PRIMAL }
  end
  
  if ( #currencies == 0 ) then  
    MerchantFrame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
    MerchantFrame:UnregisterEvent("BAG_UPDATE") 
    MerchantMoneyFrame:SetPoint("BOTTOMRIGHT", -4, 8)
    MerchantMoneyFrame:Show()
    MerchantExtraCurrencyInset:Hide()
    MerchantExtraCurrencyBg:Hide()
  else
    MerchantFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    MerchantFrame:RegisterEvent("BAG_UPDATE")
    MerchantExtraCurrencyInset:Show()
    MerchantExtraCurrencyBg:Show()
    local numCurrencies = #currencies
    if ( numCurrencies > 3 ) then
      MerchantMoneyFrame:Hide()
    else
      MerchantMoneyFrame:SetPoint("BOTTOMRIGHT", -169, 8)
      MerchantMoneyFrame:Show()
    end
    for index = 1, numCurrencies do
      local tokenButton = _G["MerchantToken"..index]
      -- bouton a creer si n existe pas
      if ( not tokenButton ) then
        tokenButton = CreateFrame("BUTTON", "MerchantToken"..index, MerchantFrame, "BackpackTokenTemplate")
       -- affichage en 6/5/4;3/2/1
        if ( index == 1 ) then
          tokenButton:SetPoint("BOTTOMRIGHT", -16, 8)
        elseif ( index == 4 ) then
          tokenButton:SetPoint("BOTTOMLEFT", 89, 8)
        else
          tokenButton:SetPoint("RIGHT", _G["MerchantToken"..index - 1], "LEFT", 0, 0)
        end
        tokenButton:SetScript("OnEnter", MerchantFrame_ShowCurrencyTooltip)
      end

      tokenButton.itemID = nil
      tokenButton.currencyID = nil
      
      local name, count, icon
      if currencies[index] < 0 then
        currencies[index] = -currencies[index]
        name = GetItemInfo(currencies[index]) or RETRIEVING_ITEM_INFO
        count = GetItemCount(currencies[index], true)
        icon = GetItemIcon(currencies[index])
        tokenButton.itemID = currencies[index]
      else
        name, count, icon = GetCurrencyInfo(currencies[index])
        tokenButton.currencyID = currencies[index]
      end
      if ( name and name ~= "" ) then
        if ( count <= 99999 ) then
          tokenButton.count:SetText(count)
        else
          tokenButton.count:SetText("*")
        end
        tokenButton.icon:SetTexture(icon)
        tokenButton:Show()
      else
        tokenButton.currencyID = nil
        tokenButton.itemID = nil
        tokenButton:Hide()
      end
    end
  end
  
  for i = #currencies + 1, MAX_MERCHANT_CURRENCIES do
    local tokenButton = _G["MerchantToken"..i]
    if ( tokenButton ) then
      tokenButton.currencyID = nil
      tokenButton.itemID = nil
      tokenButton:Hide()
    else
      break
    end
  end
end

-- cache update
MerchantFrame_UpdateCurrencyAmounts = function()
  for i = 1, MAX_MERCHANT_CURRENCIES do
    local tokenButton = _G["MerchantToken"..i]
    if not tokenButton then return end
    
    local _, count
    if (tokenButton.itemID) then
      count = GetItemCount(tokenButton.itemID, true)
    elseif (tokenButton.currencyID) then
      _, count = GetCurrencyInfo(tokenButton.currencyID)
    end
    if not count then return end
    
    if ( count <= 99999 ) then
      tokenButton.count:SetText(count)
    else
      tokenButton.count:SetText("*")
    end
  end
end

-- affichage tooltip
MerchantFrame_ShowCurrencyTooltip = function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if self.itemID then
    GameTooltip:SetItemByID(self.itemID)
  elseif self.currencyID then
    GameTooltip:SetCurrencyByID(self.currencyID)
  end
end

-- MAJ du sac
MerchantFrame:HookScript("OnEvent", function(self,event,...)
  if event == "BAG_UPDATE" then
    MerchantFrame_OnEvent(self, "CURRENCY_DISPLAY_UPDATE")
  end
end)



-- click sans confirmer

local oldMerchantItemButton_OnClick = MerchantItemButton_OnClick
MerchantItemButton_OnClick = function(self, button, ...)
  -- ignore si ce ne sont pas les vendeurs requis
  if not IsBloodTrader() or MerchantFrame.selectedTab ~= 1 then return oldMerchantItemButton_OnClick(self, button, ...) end

  MerchantFrame.extendedCost = nil
  MerchantFrame.highPrice = nil
  
  if ( button == "LeftButton" ) then
    if ( MerchantFrame.refundItem ) then
      if ( ContainerFrame_GetExtendedPriceString(MerchantFrame.refundItem, MerchantFrame.refundItemEquipped)) then
        -- fenetre de confirm
        return
      end
    end

    PickupMerchantItem(self:GetID())
  else
    BuyMerchantItem(self:GetID())
  end
end

-- ajout du shift + quantite .... inclus sur le vanilla.
local oldMerchantItemButton_OnModifiedClick = MerchantItemButton_OnModifiedClick
MerchantItemButton_OnModifiedClick = function(self, button, ...)
  -- rachat ou non vendeur requis, ignore
  if IsBloodTrader() ~= NPCID_BLOODTRADER or MerchantFrame.selectedTab ~= 1 then return oldMerchantItemButton_OnModifiedClick(self, button, ...) end

  if ( HandleModifiedItemClick(GetMerchantItemLink(self:GetID())) ) then
    return
  end
  if ( IsModifiedClick("SPLITSTACK")) then
    local maxStack = GetMerchantItemMaxStack(self:GetID())
    -- condition
    if IsCache(self:GetID()) then
      maxStack = min(10, MainMenuBarBackpackButton.freeSlots)
      OpenStackSplitFrame(maxStack, self, "BOTTOMLEFT", "TOPLEFT")
    else
      return oldMerchantItemButton_OnModifiedClick(self, button, ...)
    end
  end
end

-- simplification d'achat
local oldBuyMerchantItem = BuyMerchantItem
BuyMerchantItem = function(index, amount, ...)
  if IsBloodTrader() ~= NPCID_BLOODTRADER or not IsCache(index) or amount == 1 or not amount then return oldBuyMerchantItem(index, amount, ...) end
  
  amount = min(amount, min(10, MainMenuBarBackpackButton.freeSlots))
  while amount > 0 do
    oldBuyMerchantItem(index, 1)
    oldBuyMerchantItem(0, 0) -- delai
    oldBuyMerchantItem(0, 0)
    amount = amount - 1
  end
end
