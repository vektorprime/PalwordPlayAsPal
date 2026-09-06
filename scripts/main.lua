-- PalAttack: F7 triggers the possessed Pal's own waza action.
-- Pawn -> PalActionComponent.PlayAction(nearest enemy, waza action instance).
local UEHelpers = require("UEHelpers")

print("[PalAttack] loaded\n")

local function get_comp(pawn, shortname)
    local inst = FindFirstOf(shortname)
    if not inst or not inst:IsValid() then return nil end
    local c = pawn:GetComponentByClass(inst:GetClass())
    if c and c:IsValid() then return c end
    return nil
end

local function nearest_enemy(pawn, maxdist)
    local best, bestd = nil, maxdist
    local all = FindAllOf("Character")
    if not all then return nil end
    local pl = pawn:K2_GetActorLocation()
    for _, cand in ipairs(all) do
        if cand:IsValid() and cand:GetAddress() ~= pawn:GetAddress() then
            local ok, cl = pcall(function() return cand:K2_GetActorLocation() end)
            if ok and cl then
                local dx, dy, dz = cl.X - pl.X, cl.Y - pl.Y, cl.Z - pl.Z
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d < bestd then best, bestd = cand, d end
            end
        end
    end
    return best, bestd
end

local function possessed_pal_pawn()
    local pc = UEHelpers:GetPlayerController()
    if not pc or not pc:IsValid() then return nil end
    -- mouse cursor up means UI/menu is being used, not combat
    local okc, cursor = pcall(function() return pc.bShowMouseCursor end)
    if okc and cursor then return nil end
    local pawn = pc.Pawn
    if not pawn or not pawn:IsValid() then return nil end
    if string.find(pawn:GetFullName(), "BP_Player_Female") then return nil end
    return pawn
end

local function do_attack()
    local pawn = possessed_pal_pawn()
    if not pawn then return end
    print(string.format("[PalAttack] pawn: %s\n", pawn:GetFullName()))
    local actcomp = get_comp(pawn, "PalActionComponent")
    if not actcomp then print("[PalAttack] no PalActionComponent\n") return end
    local param = get_comp(pawn, "PalStaticCharacterParameterComponent")
    if not param then print("[PalAttack] no param component\n") return end
    local map = param:GetPropertyValue("WazaActionInstancedMap")
    if not map then print("[PalAttack] no waza map\n") return end
    local action = nil
    map:ForEach(function(key, value)
        local okv, vobj = pcall(function() return value:get() end)
        if okv and vobj ~= nil then
            local oko, vok = pcall(function() return vobj:IsValid() end)
            if oko and vok then
                action = vobj
                print(string.format("[PalAttack] action: %s\n", vobj:GetFullName()))
                return true
            end
        end
    end)
    if not action then print("[PalAttack] no action instance found\n") return end
    local target = nearest_enemy(pawn, 1500.0)
    print(string.format("[PalAttack] target: %s\n",
        target and target:GetFullName() or "none"))
    if not target then print("[PalAttack] no enemy in range\n") return end
    local okr, r = pcall(function() return actcomp:PlayAction(target, action) end)
    print(string.format("[PalAttack] PlayAction ok=%s ret=%s\n", tostring(okr), tostring(r)))
end

local function on_attack_key()
    ExecuteInGameThread(function()
        local ok, err = pcall(do_attack)
        if not ok then print(string.format("[PalAttack] ERROR: %s\n", err)) end
    end)
end

RegisterKeyBind(Key.F7, on_attack_key)
RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, on_attack_key)

-- Gamepad right trigger is not in this build's Key enum, so catch it at the
-- engine input funnel instead: every button press flows through InputKey.
local function key_name_str(k)
    local ok, fname = pcall(function() return k.KeyName end)
    if ok and fname ~= nil then
        local ok2, s = pcall(function() return fname:ToString() end)
        if ok2 then return s end
    end
    local okt, s = pcall(function() return tostring(k) end)
    return (okt and s) or ""
end

RegisterHook("/Script/Engine.PlayerInput:InputKey", function(self, Key, EventType)
    local name = key_name_str(Key)
    if string.find(name, "Gamepad_RightTrigger", 1, true) and EventType == 0 then
        on_attack_key()
    end
end)

-- PlayAsPals shows its TUT welcome widget at launch AND again on world entry.
-- Leave the first one alone; hide repeats (its own 30s timer still cleans up).
local tut_count = 0
RegisterHook("/Script/UMG.UserWidget:AddToViewport", function(self)
    local okc, cls = pcall(function() return self:GetClass():GetName() end)
    if not okc or cls ~= "TUT_C" then return end
    tut_count = tut_count + 1
    print(string.format("[PalAttack] TUT welcome #%d\n", tut_count))
    if tut_count < 2 then return end
    local ok, err = pcall(function()
        self:SetVisibility(1) -- Collapsed; widget's own timer removes it later
        local pc = UEHelpers:GetPlayerController()
        if pc and pc:IsValid() then
            local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
            if wbl then wbl:SetInputMode_GameOnly(pc) end
            pc.bShowMouseCursor = false
        end
    end)
    print(string.format("[PalAttack] TUT repeat hidden ok=%s %s\n", tostring(ok), ok and "" or tostring(err)))
end)
