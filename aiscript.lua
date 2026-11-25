-- ═══════════════════════════════════════════════════════════════════
-- H3X CORE — motor do hub (chat reader + P2P + funções)
-- Cole este PRIMEIRO. Os painéis dependem dele.
-- ═══════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(0.5)

    local Players           = game:GetService("Players")
    local LocalPlayer       = Players.LocalPlayer
    local TweenService      = game:GetService("TweenService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Lighting          = game:GetService("Lighting")
    local CoreGui           = game:GetService("CoreGui")
    local Debris            = game:GetService("Debris")
    local RunService        = game:GetService("RunService")
    local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

    -- ============================================================
    -- CONFIG
    -- ============================================================
    local ADMIN_CONFIG = {
        owners = {
            ["julainorei"]   = true,
            ["lancenickel5"] = true,
        },
        compradores = {
            ["ztxx_senna2"]         = { expira = "2027-11-21", tipo = "1 ano" },
            ["ztxx_senna"]          = { expira = "2027-11-21", tipo = "1 ano" },
            ["jshdjjavekdnsowowo9"] = { expira = "2027-05-21", tipo = "6 meses" },
            ["lancenickel5"]        = { expira = "99999-12-31", tipo = "permanente" },
            ["enzoemanuel5000"]     = { expira = "2026-11-27", tipo = "teste" },
        },
    }
    local POSICAO_POSTE = Vector3.new(37, 28, -22)
    local BACKROOMS_POS = Vector3.new(59, 9996, 19)
    local BACKROOMS_MAP_ID = 10581711055

    local function getInfoAcesso(nome)
        nome = tostring(nome or ""):lower()
        if ADMIN_CONFIG.owners[nome] then return "👑 H3X Admin | Dono", "permanente", "∞", 999999, true end
        local c = ADMIN_CONFIG.compradores[nome]
        if c then
            local a,m,d = c.expira:match("(%d+)-(%d+)-(%d+)")
            if a then
                local exp = os.time({year=tonumber(a),month=tonumber(m),day=tonumber(d),hour=23,min=59,sec=59})
                local diff = exp - os.time()
                return "⭐ H3X User", c.tipo, c.expira, math.floor(math.max(diff,0)/86400), diff >= 0
            end
        end
        return "❌ Sem acesso", "—", "—", 0, false
    end

    _G.H3X = {
        getInfoAcesso = getInfoAcesso,
        ADMIN_CONFIG = ADMIN_CONFIG,
        POSICAO_POSTE = POSICAO_POSTE,
        enviarChat = nil,
        EnviarComando = nil,
        WriteBoard = nil,
    }

    -- ============================================================
    -- CHAT HELPER
    -- ============================================================
    local function enviarChat(msg)
        local ok = false
        pcall(function()
            local tcs = game:GetService("TextChatService")
            if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
                local ch = tcs.TextChannels:FindFirstChild("RBXGeneral")
                if ch then ch:SendAsync(msg); ok = true end
            end
        end)
        if not ok then
            pcall(function()
                local ev = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                if ev and ev:FindFirstChild("SayMessageRequest") then
                    ev.SayMessageRequest:FireServer(msg, "All"); ok = true
                end
            end)
        end
        return ok
    end
    _G.H3X.enviarChat = enviarChat

    -- ============================================================
    -- COMANDOS VÁLIDOS + PARSER
    -- ============================================================
    local COMANDOS_VALIDOS = {
        kill=true,reset=true,kick=true,loopkill=true,unloopkill=true,
        fling=true,freeze=true,unfreeze=true,sit=true,loopsit=true,
        unloopsit=true,fire=true,loopfire=true,unloopfire=true,explode=true,
        bring=true,loopbring=true,unloopbring=true,jail=true,unjail=true,
        castigo=true,descastigo=true,poste=true,soltar=true,chute=true,
        esmagar=true,backrooms=true,tptroll=true,float=true,lag=true,
        verifique=true,jumps1=true,jumps2=true,jumps3=true,jumps4=true,
        goner=true,flopparain=true,unfloppa=true,domainexpansion=true,
        therakejumpscare=true,animejumpscare=true,pararjumpscare=true,
        aviso=true,ch=true,chall=true,noop=true,ack=true,
    }
    local SUB_CMDS = { invisible = true }
    local function parseCmd(texto)
        if type(texto) ~= "string" then return nil end
        local raw = texto:gsub("^%s+",""):gsub("%s+$","")
        if raw:sub(1,1) ~= ";" then return nil end
        if raw:match("^;noop") then return nil end
        local base = raw:match("^;(%a+)")
        if not base then return nil end
        base = base:lower()
        if not COMANDOS_VALIDOS[base] then return nil end
        local resto = raw:sub(#base+2):gsub("^%s+",""):gsub("%s+$","")
        local sub, after = nil, resto
        local firstWord = resto:match("^(%a+)")
        if firstWord and SUB_CMDS[firstWord:lower()] then
            sub = firstWord:lower()
            after = resto:sub(#firstWord+1):gsub("^%s+","")
        end
        return base, sub, after
    end
    _G.H3X.parseCmd = parseCmd

    -- ============================================================
    -- DEDUPE
    -- ============================================================
    _G.__H3XUltimoCmd = nil
    _G.__H3XUltimoTempo = 0
    _G.__H3XExecutar = function(texto)
        if not texto or texto=="" or texto==" " then return end
        local agora = tick()
        if texto == _G.__H3XUltimoCmd and (agora - _G.__H3XUltimoTempo) < 2 then return end
        _G.__H3XUltimoCmd = texto
        _G.__H3XUltimoTempo = agora
        if _G.__H3XProcessar then pcall(_G.__H3XProcessar, texto) end
    end

    -- ============================================================
    -- TAGS COMPACTAS
    -- ============================================================
    local ActiveTags = {}
    local function RemoveTag(n)
        if ActiveTags[n] then pcall(function() ActiveTags[n]:Destroy() end); ActiveTags[n]=nil end
    end
    local function CreateTag(playerName)
        local p = Players:FindFirstChild(playerName)
        if not p or not p.Character then return end
        local head = p.Character:FindFirstChild("Head"); if not head then return end
        RemoveTag(playerName)
        local _,_,_,_,ok = getInfoAcesso(p.Name); if not ok then return end
        local isDono = ADMIN_CONFIG.owners[p.Name:lower()] ~= nil
        local cor = isDono and Color3.fromRGB(255,200,0) or Color3.fromRGB(60,180,255)
        local icone = isDono and "👑" or "⭐"
        local bb = Instance.new("BillboardGui")
        bb.Name="H3XTag"; bb.Adornee=head; bb.Size=UDim2.new(0,90,0,22)
        bb.StudsOffset=Vector3.new(0,2.6,0); bb.AlwaysOnTop=true
        bb.MaxDistance=100; bb.LightInfluence=0; bb.Parent=head
        local fr = Instance.new("Frame", bb)
        fr.Size=UDim2.fromScale(1,1); fr.BackgroundColor3=Color3.fromRGB(15,15,20)
        fr.BackgroundTransparency=0.15; fr.BorderSizePixel=0
        Instance.new("UICorner", fr).CornerRadius=UDim.new(0,6)
        local st = Instance.new("UIStroke", fr)
        st.Color=cor; st.Thickness=1.5; st.Transparency=0.1
        local lbl = Instance.new("TextLabel", fr)
        lbl.Size=UDim2.fromScale(1,1); lbl.BackgroundTransparency=1
        lbl.Text=icone.." H3X"; lbl.TextColor3=cor
        lbl.TextScaled=true; lbl.Font=Enum.Font.GothamBold
        ActiveTags[playerName]=bb
    end
    local function setupTagPlayer(p)
        if not p then return end
        local function apply()
            local _,_,_,_,ok = getInfoAcesso(p.Name)
            if ok then CreateTag(p.Name) end
        end
        pcall(apply)
        p.CharacterAdded:Connect(function() task.wait(0.6); pcall(apply) end)
    end
    for _,p in ipairs(Players:GetPlayers()) do setupTagPlayer(p) end
    Players.PlayerAdded:Connect(setupTagPlayer)
    Players.PlayerRemoving:Connect(function(p) RemoveTag(p.Name) end)
    task.spawn(function()
        while true do
            task.wait(15)
            for _,p in ipairs(Players:GetPlayers()) do
                local _,_,_,_,ok = getInfoAcesso(p.Name)
                if ok and p.Character then
                    local head = p.Character:FindFirstChild("Head")
                    if head and not head:FindFirstChild("H3XTag") then pcall(CreateTag,p.Name) end
                end
            end
        end
    end)

    -- ============================================================
    -- LISTENER P2P + FUNÇÕES
    -- ============================================================
    _G.__H3XWriteBoard = nil
    _G.__H3XProcessar = nil

    task.spawn(function()
        local Board = {count=nil,label=nil,remote=nil,pronto=false}
        local function tentarBoard()
            local ok,res = pcall(function()
                local wc = workspace:FindFirstChild("WorkspaceCom"); if not wc then return end
                local school = wc:FindFirstChild("001_School"); if not school then return end
                local board = school:FindFirstChild("SchoolDryBoard"); if not board then return end
                local words = board:FindFirstChild("Words"); if not words then return end
                local count = words:FindFirstChild("Count")
                local label = words:FindFirstChildWhichIsA("TextLabel", true)
                local RE = ReplicatedStorage:FindFirstChild("RE")
                local remote = RE and RE:FindFirstChild("1Schoo1lDr1yBoard1s")
                if count and label and remote then return {count=count,label=label,remote=remote} end
            end)
            if ok and res then Board.count=res.count;Board.label=res.label;Board.remote=res.remote;Board.pronto=true; return true end
            return false
        end
        if not tentarBoard() then task.spawn(function() while not Board.pronto do task.wait(1); tentarBoard() end end) end
        local seq = 0
        local function WriteBoard(t)
            if not Board.pronto or not Board.count or not Board.remote then return false end
            seq = seq + 1
            pcall(function() Board.count.Value=seq end)
            pcall(function() Board.remote:FireServer("ReturningBoardName", Board.count, tostring(t or "")) end)
            return true
        end
        _G.__H3XWriteBoard = WriteBoard
        _G.H3X.WriteBoard = WriteBoard

        -- Anuncio
        local function anuncio(rem, txt)
            local sg = Instance.new("ScreenGui", PlayerGui)
            sg.Name="H3X_Announce"; sg.DisplayOrder=999; sg.IgnoreGuiInset=true
            local blur = Instance.new("BlurEffect", Lighting); blur.Size=0
            local ov = Instance.new("Frame", sg)
            ov.Size=UDim2.fromScale(1,1); ov.BackgroundColor3=Color3.new(0,0,0)
            ov.BackgroundTransparency=1; ov.BorderSizePixel=0
            local fr = Instance.new("Frame", sg)
            fr.Size=UDim2.new(0,700,0,220); fr.Position=UDim2.new(0.5,0,-0.5,0)
            fr.AnchorPoint=Vector2.new(0.5,0.5); fr.BackgroundColor3=Color3.fromRGB(10,10,15)
            Instance.new("UICorner", fr).CornerRadius=UDim.new(0,24)
            local st=Instance.new("UIStroke",fr); st.Color=Color3.fromRGB(255,0,0); st.Thickness=4
            local t=Instance.new("TextLabel",fr)
            t.Size=UDim2.new(1,-30,0,40); t.Position=UDim2.new(0,15,0,15)
            t.BackgroundTransparency=1; t.Text="⚡ AVISO DE "..tostring(rem):upper().." ⚡"
            t.Font=Enum.Font.GothamBold; t.TextSize=26; t.TextColor3=Color3.new(1,1,1)
            t.TextXAlignment=Enum.TextXAlignment.Left
            local c=Instance.new("TextLabel",fr)
            c.Size=UDim2.new(1,-30,1,-80); c.Position=UDim2.new(0,15,0,65)
            c.BackgroundTransparency=1; c.Text=txt; c.Font=Enum.Font.Gotham; c.TextSize=20
            c.TextColor3=Color3.new(1,1,1); c.TextXAlignment=Enum.TextXAlignment.Left
            c.TextYAlignment=Enum.TextYAlignment.Top; c.TextWrapped=true
            TweenService:Create(blur,TweenInfo.new(0.5),{Size=18}):Play()
            TweenService:Create(ov,TweenInfo.new(0.5),{BackgroundTransparency=0.4}):Play()
            TweenService:Create(fr,TweenInfo.new(0.9,Enum.EasingStyle.Back),{Position=UDim2.new(0.5,0,0.5,0)}):Play()
            task.delay(7, function()
                TweenService:Create(fr,TweenInfo.new(0.7,Enum.EasingStyle.Back,Enum.EasingDirection.In),{
                    Position=UDim2.new(0.5,0,-0.5,0), Size=UDim2.new(0,700,0,0)
                }):Play()
                TweenService:Create(blur,TweenInfo.new(0.7),{Size=0}):Play()
                TweenService:Create(ov,TweenInfo.new(0.7),{BackgroundTransparency=1}):Play()
                task.wait(0.8); pcall(function() sg:Destroy(); blur:Destroy() end)
            end)
        end

        local function jumpscare(imgId, audId)
            local sg = Instance.new("ScreenGui", PlayerGui)
            sg.Name="H3X_Jumpscare"; sg.DisplayOrder=2147483647
            sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
            local fr = Instance.new("Frame", sg)
            fr.Size=UDim2.fromScale(1,1); fr.BackgroundColor3=Color3.new(0,0,0); fr.BorderSizePixel=0
            local im = Instance.new("ImageLabel", fr)
            im.Size=UDim2.fromScale(1,1); im.BackgroundTransparency=1
            im.Image=imgId; im.ScaleType=Enum.ScaleType.Fit
            local flash = Instance.new("Frame", fr)
            flash.Size=UDim2.fromScale(1,1); flash.BackgroundColor3=Color3.new(1,1,1)
            flash.BorderSizePixel=0; flash.BackgroundTransparency=1
            local s = Instance.new("Sound", fr); s.SoundId=audId; s.Volume=3; s:Play()
            flash.BackgroundTransparency=0
            TweenService:Create(flash, TweenInfo.new(0.3), {BackgroundTransparency=1}):Play()
            task.spawn(function()
                for i=1,15 do
                    if not sg.Parent then break end
                    im.ImageTransparency=(i%2==0) and 0.1 or 0
                    fr.BackgroundColor3=(i%2==0) and Color3.fromRGB(50,0,0) or Color3.new(0,0,0)
                    task.wait(0.15)
                end
                im.ImageTransparency=0; task.wait(0.8)
                TweenService:Create(im,TweenInfo.new(1.5),{ImageTransparency=1}):Play()
                TweenService:Create(fr,TweenInfo.new(1.5),{BackgroundTransparency=1}):Play()
                task.wait(2); pcall(function() sg:Destroy() end)
            end)
        end

        local jaulas, jailLoops, jailStates = {}, {}, {}
        local function criarJail(pos)
            if jaulas["_"] then for _,p in ipairs(jaulas["_"]) do pcall(function() p:Destroy() end) end end
            if jailLoops["_"] then pcall(function() task.cancel(jailLoops["_"]) end) end
            local char=LocalPlayer.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp then return end
            if not jailStates["_"] then jailStates["_"]={walk=hum.WalkSpeed,jump=hum.JumpPower,jumpHeight=hum.JumpHeight} end
            hum.WalkSpeed=0;hum.JumpPower=0;hum.JumpHeight=0
            hum.PlatformStand=false;hum.AutoRotate=false
            hrp.CFrame=CFrame.new(pos);hrp.Velocity=Vector3.zero;hrp.RotVelocity=Vector3.zero
            jaulas["_"]={}
            local function criar(cf,s)
                local p=Instance.new("Part")
                p.Anchored=true;p.CanCollide=true
                p.Material=Enum.Material.ForceField;p.Transparency=0.3
                p.Color=Color3.fromRGB(255,0,0);p.Size=s;p.CFrame=cf;p.Parent=workspace
                local pl=Instance.new("PointLight",p)
                pl.Color=Color3.fromRGB(255,0,0);pl.Brightness=2;pl.Range=15
                table.insert(jaulas["_"],p)
            end
            criar(CFrame.new(pos+Vector3.new(5,0,0)),Vector3.new(1,10,10))
            criar(CFrame.new(pos+Vector3.new(-5,0,0)),Vector3.new(1,10,10))
            criar(CFrame.new(pos+Vector3.new(0,0,5)),Vector3.new(10,10,1))
            criar(CFrame.new(pos+Vector3.new(0,0,-5)),Vector3.new(10,10,1))
            criar(CFrame.new(pos+Vector3.new(0,5,0)),Vector3.new(10,1,10))
            criar(CFrame.new(pos+Vector3.new(0,-5,0)),Vector3.new(10,1,10))
            jailLoops["_"]=task.spawn(function()
                while jaulas["_"] do
                    local c=LocalPlayer.Character
                    local h=c and c:FindFirstChildOfClass("Humanoid")
                    local r=c and c:FindFirstChild("HumanoidRootPart")
                    if h and r then
                        if h.WalkSpeed~=0 then h.WalkSpeed=0 end
                        if h.JumpPower~=0 then h.JumpPower=0 end
                        if (r.Position-pos).Magnitude>2 then r.CFrame=CFrame.new(pos) end
                        r.Velocity=Vector3.zero;r.RotVelocity=Vector3.zero
                    end
                    task.wait(0.05)
                end
            end)
        end
        local function removerJail()
            if jaulas["_"] then for _,p in ipairs(jaulas["_"]) do pcall(function() p:Destroy() end) end;jaulas["_"]=nil end
            if jailLoops["_"] then pcall(function() task.cancel(jailLoops["_"]) end);jailLoops["_"]=nil end
            local char=LocalPlayer.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum and jailStates["_"] then
                hum.WalkSpeed=jailStates["_"].walk or 16
                hum.JumpPower=jailStates["_"].jump or 50
                hum.JumpHeight=jailStates["_"].jumpHeight or 7.2
                hum.AutoRotate=true
            end
            jailStates["_"]=nil
        end

        local invisJail, invisState = {}, nil
        local function jailInvisivel()
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then return end
            if invisJail.model then invisJail.model:Destroy() end
            if invisJail.loop then task.cancel(invisJail.loop) end
            if not invisState then invisState={walk=hum.WalkSpeed,jump=hum.JumpPower,jumpHeight=hum.JumpHeight} end
            hum.WalkSpeed=0;hum.JumpPower=0;hum.JumpHeight=0;hum.AutoRotate=false
            local pos=hrp.Position;local size=8
            local model=Instance.new("Model",workspace);model.Name="InvisibleJail"
            local base=Instance.new("Part",model)
            base.Size=Vector3.new(size,0.5,size);base.Position=pos-Vector3.new(0,3,0)
            base.Anchored=true;base.CanCollide=true;base.Transparency=1
            local roof=base:Clone();roof.Position=base.Position+Vector3.new(0,size,0);roof.Parent=model
            for _,cfg in ipairs({
                {size=Vector3.new(0.5,size,size),pos=base.Position+Vector3.new(size/2,size/2,0)},
                {size=Vector3.new(0.5,size,size),pos=base.Position+Vector3.new(-size/2,size/2,0)},
                {size=Vector3.new(size,size,0.5),pos=base.Position+Vector3.new(0,size/2,size/2)},
                {size=Vector3.new(size,size,0.5),pos=base.Position+Vector3.new(0,size/2,-size/2)},
            }) do
                local w=Instance.new("Part",model)
                w.Size=cfg.size;w.Position=cfg.pos
                w.Anchored=true;w.CanCollide=true;w.Transparency=1
            end
            local center=base.Position+Vector3.new(0,size/2,0)
            hrp.CFrame=CFrame.new(center)
            invisJail.model=model
            invisJail.loop=task.spawn(function()
                while invisJail.model and invisJail.model.Parent do
                    local c=LocalPlayer.Character
                    local h=c and c:FindFirstChildOfClass("Humanoid")
                    local r=c and c:FindFirstChild("HumanoidRootPart")
                    if h and r then
                        if h.WalkSpeed~=0 then h.WalkSpeed=0 end
                        if h.JumpPower~=0 then h.JumpPower=0 end
                        if (r.Position-center).Magnitude>2 then r.CFrame=CFrame.new(center) end
                        r.Velocity=Vector3.zero;r.RotVelocity=Vector3.zero
                    end
                    task.wait(0.05)
                end
            end)
        end
        local function desjailInvisivel()
            if invisJail.model then invisJail.model:Destroy();invisJail.model=nil end
            if invisJail.loop then task.cancel(invisJail.loop);invisJail.loop=nil end
            local char=LocalPlayer.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum and invisState then
                hum.WalkSpeed=invisState.walk or 16
                hum.JumpPower=invisState.jump or 50
                hum.JumpHeight=invisState.jumpHeight or 7.2
                hum.AutoRotate=true
            end
            invisState=nil
        end

        local castigoData,castigoState={},nil
        local function castigo()
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then return end
            if castigoData.model then castigoData.model:Destroy() end
            if castigoData.loop then task.cancel(castigoData.loop) end
            if not castigoState then castigoState={walk=hum.WalkSpeed,jump=hum.JumpPower,jumpHeight=hum.JumpHeight} end
            hum.WalkSpeed=0;hum.JumpPower=0;hum.JumpHeight=0;hum.AutoRotate=false
            local pos=Vector3.new(1159,1727,421);local size=12
            local model=Instance.new("Model",workspace);model.Name="Castigo"
            local function criar(cf,s)
                local p=Instance.new("Part")
                p.Anchored=true;p.CanCollide=true
                p.Material=Enum.Material.Neon;p.Transparency=0.15
                p.Color=Color3.fromRGB(255,0,0);p.Size=s;p.CFrame=cf;p.Parent=model
                local pl=Instance.new("PointLight",p)
                pl.Color=Color3.fromRGB(255,0,0);pl.Brightness=5;pl.Range=25
            end
            criar(CFrame.new(pos+Vector3.new(size/2,0,0)),Vector3.new(0.5,size*2,size))
            criar(CFrame.new(pos+Vector3.new(-size/2,0,0)),Vector3.new(0.5,size*2,size))
            criar(CFrame.new(pos+Vector3.new(0,0,size/2)),Vector3.new(size,size*2,0.5))
            criar(CFrame.new(pos+Vector3.new(0,0,-size/2)),Vector3.new(size,size*2,0.5))
            criar(CFrame.new(pos+Vector3.new(0,size,0)),Vector3.new(size,0.5,size))
            criar(CFrame.new(pos+Vector3.new(0,-size,0)),Vector3.new(size,0.5,size))
            hrp.CFrame=CFrame.new(pos)
            castigoData.model=model
            castigoData.loop=task.spawn(function()
                while castigoData.model and castigoData.model.Parent do
                    local c=LocalPlayer.Character
                    local h=c and c:FindFirstChildOfClass("Humanoid")
                    local r=c and c:FindFirstChild("HumanoidRootPart")
                    if h and r then
                        if h.WalkSpeed~=0 then h.WalkSpeed=0 end
                        if h.JumpPower~=0 then h.JumpPower=0 end
                        if (r.Position-pos).Magnitude>3 then r.CFrame=CFrame.new(pos) end
                        r.Velocity=Vector3.zero;r.RotVelocity=Vector3.zero
                    end
                    task.wait(0.05)
                end
            end)
        end
        local function descastigo()
            if castigoData.model then castigoData.model:Destroy();castigoData.model=nil end
            if castigoData.loop then task.cancel(castigoData.loop);castigoData.loop=nil end
            local char=LocalPlayer.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum and castigoState then
                hum.WalkSpeed=castigoState.walk or 16
                hum.JumpPower=castigoState.jump or 50
                hum.JumpHeight=castigoState.jumpHeight or 7.2
                hum.AutoRotate=true
            end
            castigoState=nil
        end

        local posteData={ancora=nil,corda=nil,loop=nil,rs=nil,ls=nil,rh=nil,lh=nil}
        local function limparPoste()
            if posteData.loop then pcall(function() task.cancel(posteData.loop) end);posteData.loop=nil end
            if posteData.corda then pcall(function() posteData.corda:Destroy() end);posteData.corda=nil end
            if posteData.ancora then pcall(function() posteData.ancora:Destroy() end);posteData.ancora=nil end
            local char=LocalPlayer.Character
            if char then
                local hum=char:FindFirstChildOfClass("Humanoid")
                local hrp=char:FindFirstChild("HumanoidRootPart")
                local animateScript=char:FindFirstChild("Animate")
                if animateScript then animateScript.Enabled=true end
                if hum then hum.PlatformStand=false;hum.AutoRotate=true;pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
                if hrp then hrp.Anchored=false;hrp.Velocity=Vector3.zero;hrp.RotVelocity=Vector3.zero end
                local head=char:FindFirstChild("Head")
                if head and head:FindFirstChild("TagPunido") then head.TagPunido:Destroy() end
            end
        end
        local function pendurarPoste()
            limparPoste()
            local char=LocalPlayer.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if not char or not hum or not hrp then return end
            local animateScript=char:FindFirstChild("Animate")
            if animateScript then animateScript.Enabled=false end
            hrp.Anchored=true;hum.PlatformStand=true
            local ancora=Instance.new("Part")
            ancora.Name="H3XPosteAncora";ancora.Anchored=true;ancora.CanCollide=false;ancora.Transparency=1
            ancora.Size=Vector3.new(0.5,0.5,0.5);ancora.Position=POSICAO_POSTE;ancora.Parent=workspace
            posteData.ancora=ancora
            local corda=Instance.new("Part")
            corda.Name="H3XCorda";corda.Anchored=true;corda.CanCollide=false
            corda.Color=Color3.fromRGB(70,45,20);corda.Material=Enum.Material.Fabric
            corda.Size=Vector3.new(0.12,1,0.12);corda.Parent=workspace
            posteData.corda=corda
            local head=char:FindFirstChild("Head")
            if head then
                local old=head:FindFirstChild("TagPunido");if old then old:Destroy() end
                local bb=Instance.new("BillboardGui",head)
                bb.Name="TagPunido";bb.Size=UDim2.new(0,150,0,40)
                bb.StudsOffset=Vector3.new(0,2,0);bb.AlwaysOnTop=true
                local fr=Instance.new("Frame",bb)
                fr.Size=UDim2.fromScale(1,1);fr.BackgroundColor3=Color3.fromRGB(20,0,0);fr.BackgroundTransparency=0.2
                Instance.new("UICorner",fr).CornerRadius=UDim.new(0,8)
                local st=Instance.new("UIStroke",fr)
                st.Color=Color3.fromRGB(255,0,0);st.Thickness=2
                local tx=Instance.new("TextLabel",fr)
                tx.Size=UDim2.fromScale(1,1);tx.BackgroundTransparency=1
                tx.Text="PUNIDO";tx.TextColor3=Color3.fromRGB(255,40,40)
                tx.Font=Enum.Font.GothamBlack;tx.TextScaled=true
            end
            posteData.rs=char:FindFirstChild("RightShoulder")
            posteData.ls=char:FindFirstChild("LeftShoulder")
            posteData.rh=char:FindFirstChild("RightHip")
            posteData.lh=char:FindFirstChild("LeftHip")
            posteData.loop=task.spawn(function()
                local t0=tick()
                while posteData.ancora and posteData.ancora.Parent do
                    local c=LocalPlayer.Character
                    local h=c and c:FindFirstChildOfClass("Humanoid")
                    local r=c and c:FindFirstChild("HumanoidRootPart")
                    if h and r then
                        local tempo=tick()-t0
                        local angulo=math.cos(tempo*2.2)*math.rad(30)
                        local queda=math.abs(math.cos(tempo*2.2))*0.4
                        local posPivo=POSICAO_POSTE+Vector3.new(0,-1.5-queda,0)
                        r.CFrame=CFrame.new(posPivo)*CFrame.Angles(math.rad(180),0,angulo)
                        local bBraco=math.sin(tempo*2.5)*math.rad(20)
                        if posteData.rs then pcall(function() posteData.rs.C0=CFrame.new(1,0.5,0)*CFrame.Angles(math.rad(180),0,math.rad(90)+bBraco) end) end
                        if posteData.ls then pcall(function() posteData.ls.C0=CFrame.new(-1,0.5,0)*CFrame.Angles(math.rad(180),0,math.rad(-90)-bBraco) end) end
                        if posteData.rh then pcall(function() posteData.rh.C0=CFrame.new(1,-1,0)*CFrame.Angles(math.rad(180),0,0) end) end
                        if posteData.lh then
                            local bPerna=math.sin(tempo*2.5+0.5)*math.rad(35)
                            pcall(function() posteData.lh.C0=CFrame.new(-1,-1,0)*CFrame.Angles(math.rad(180),0,bPerna) end)
                        end
                        if posteData.corda then
                            local posPe=r.Position+Vector3.new(0,2.5,0)
                            local centro=(POSICAO_POSTE+posPe)/2
                            local tam=(POSICAO_POSTE-posPe).Magnitude
                            posteData.corda.Size=Vector3.new(0.12,tam,0.12)
                            posteData.corda.CFrame=CFrame.lookAt(centro,POSICAO_POSTE)*CFrame.Angles(math.rad(90),0,0)
                        end
                    end
                    task.wait(0.01)
                end
            end)
        end

        local function chute()
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local bv=Instance.new("BodyVelocity",hrp)
            bv.Velocity=Vector3.new(math.random(-50,50),200,math.random(-50,50))
            bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge)
            task.delay(0.5,function() if bv then bv:Destroy() end end)
        end
        local function esmagar()
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local block=Instance.new("Part",workspace)
            block.Size=Vector3.new(60,60,60)
            block.Position=hrp.Position+Vector3.new(0,80,0)
            block.Anchored=true;block.CanCollide=true
            block.Material=Enum.Material.Concrete;block.Color=Color3.fromRGB(100,100,100)
            local startPos=block.Position
            task.spawn(function()
                local start=tick()
                while tick()-start<1 do
                    block.Position=block.Position-Vector3.new(0,3,0)
                    task.wait(0.02)
                end
                block.Position=startPos-Vector3.new(0,80,0)
                task.delay(2,function() if block then block:Destroy() end end)
            end)
        end

        local function backrooms()
            task.spawn(function()
                local char=LocalPlayer.Character
                local hrp=char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local sg=Instance.new("ScreenGui",PlayerGui)
                sg.Name="BackroomsBlackout";sg.DisplayOrder=9999
                sg.IgnoreGuiInset=true;sg.ResetOnSpawn=false
                local black=Instance.new("Frame",sg)
                black.Size=UDim2.fromScale(1,1);black.BackgroundColor3=Color3.new(0,0,0)
                black.BackgroundTransparency=1;black.BorderSizePixel=0
                TweenService:Create(black,TweenInfo.new(0.5),{BackgroundTransparency=0}):Play()
                task.wait(2)
                pcall(function()
                    local mapa=game:GetObjects("rbxassetid://"..BACKROOMS_MAP_ID)[1]
                    if mapa then
                        mapa.Parent=workspace
                        mapa.PrimaryPart=mapa.PrimaryPart or mapa:FindFirstChildWhichIsA("BasePart")
                        if mapa.PrimaryPart then mapa:SetPrimaryPartCFrame(CFrame.new(0,10000,0)) end
                    end
                end)
                if char and char:FindFirstChild("HumanoidRootPart") then char:MoveTo(BACKROOMS_POS) end
                TweenService:Create(black,TweenInfo.new(0.5),{BackgroundTransparency=1}):Play()
                task.wait(0.6);pcall(function() sg:Destroy() end)
            end)
        end

        local function transformIntoGoner()
            local RS=ReplicatedStorage
            pcall(function()
                RS:WaitForChild("Remotes"):WaitForChild("ChangeCharacterBody"):InvokeServer(unpack({{
                    116253341067642,110703630520331,119263803737569,
                    99234191703566,99948897896884,0
                }}))
            end)
            task.wait(3)
            local humanoid=(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()):WaitForChild("Humanoid")
            local anim=Instance.new("Animation");anim.AnimationId="rbxassetid://4686925579"
            humanoid:LoadAnimation(anim):Play()
            humanoid.WalkSpeed=0
            task.wait(2)
            pcall(function()
                local wearRemote=RS:WaitForChild("Remotes"):WaitForChild("Wear")
                for _,acc in ipairs(humanoid:GetAppliedDescription():GetAccessories(true)) do
                    if acc.AssetId then wearRemote:InvokeServer(tonumber(acc.AssetId)) end
                end
                RS.Remotes.Wear:InvokeServer(17771175724)
                RS.Remotes.Wear:InvokeServer(17822722698)
                RS.Remotes.Wear:InvokeServer(17822749561)
                RS.Remotes.Wear:InvokeServer(17772174303)
                RS.Remotes.Wear:InvokeServer(17770317484)
                RS.Remotes.Wear:InvokeServer(4586060885)
                RS.Remotes.Wear:InvokeServer(6913613757)
                RS.Remotes.ChangeBodyColor:FireServer("Really black")
                RS.Remotes.ApplyEmmiter:InvokeServer(18635845425,"087SmokeBlack")
            end)
            task.wait(1)
            for _,track in pairs(humanoid:GetPlayingAnimationTracks()) do track:Stop() end
            humanoid.WalkSpeed=16
        end

        local FloppaRunning=false
        local function floppaRain()
            FloppaRunning=true
            local sky=Instance.new("Sky")
            sky.SkyboxBk="rbxassetid://123446364161879";sky.SkyboxDn="rbxassetid://123446364161879"
            sky.SkyboxFt="rbxassetid://123446364161879";sky.SkyboxLf="rbxassetid://123446364161879"
            sky.SkyboxRt="rbxassetid://123446364161879";sky.SkyboxUp="rbxassetid://123446364161879"
            sky.Parent=Lighting
            task.spawn(function()
                while FloppaRunning do
                    local s=Instance.new("Sound")
                    s.SoundId="rbxassetid://8772968188";s.Volume=1;s.Parent=workspace;s:Play()
                    task.wait(5)
                end
            end)
            task.wait(1)
            local template=Instance.new("Part")
            template.Size=Vector3.new(2,2,2)
            local texId="rbxassetid://123446364161879"
            local function applyTex(part)
                for _,face in pairs({"Front","Back","Left","Right","Top","Bottom"}) do
                    local d=Instance.new("Decal")
                    d.Texture=texId;d.Face=Enum.NormalId[face];d.Parent=part
                end
            end
            local count=0
            while FloppaRunning do
                if count<80 then
                    for i=1,5 do
                        local floppa=template:Clone()
                        floppa.Position=Vector3.new(math.random(-250,250),100,math.random(-250,250))
                        applyTex(floppa)
                        floppa.Touched:Connect(function(hit)
                            local h=hit.Parent:FindFirstChildOfClass("Humanoid")
                            if h then h:TakeDamage(10) end
                        end)
                        floppa.Parent=workspace
                        Debris:AddItem(floppa,8)
                        count=count+1
                    end
                end
                task.wait(0.5)
            end
        end
        local function stopFloppa()
            FloppaRunning=false
            for _,obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Part") and obj.Size==Vector3.new(2,2,2) then
                    for _,c in ipairs(obj:GetChildren()) do
                        if c:IsA("Decal") then obj:Destroy();break end
                    end
                end
            end
            local flopSky=Lighting:FindFirstChildOfClass("Sky")
            if flopSky then flopSky:Destroy() end
        end

        local function domainExpansion()
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local originalCFrame=hrp.CFrame
            local domainCenter=Vector3.new(5000,100,5000)
            local sg=Instance.new("ScreenGui",PlayerGui)
            sg.Name="H3XDomain";sg.DisplayOrder=999999
            sg.IgnoreGuiInset=true;sg.ResetOnSpawn=false
            local bg=Instance.new("Frame",sg)
            bg.Size=UDim2.new(2,0,2,0);bg.Position=UDim2.new(-0.5,0,-0.5,0)
            bg.BackgroundColor3=Color3.new(0,0,0);bg.BorderSizePixel=0
            local titleLabel=Instance.new("TextLabel",sg)
            titleLabel.Size=UDim2.new(1,0,0.2,0);titleLabel.Position=UDim2.new(0,0,0.4,0)
            titleLabel.BackgroundTransparency=1;titleLabel.TextColor3=Color3.fromRGB(200,0,0)
            titleLabel.TextTransparency=1;titleLabel.Font=Enum.Font.Antique
            titleLabel.TextScaled=true;titleLabel.Text="Malevolent Shrine"
            task.wait(0.8)
            hrp.CFrame=CFrame.new(domainCenter)
            pcall(function()
                Lighting.Brightness=0.3;Lighting.ClockTime=0
                Lighting.Ambient=Color3.fromRGB(60,0,0)
                Lighting.OutdoorAmbient=Color3.fromRGB(40,0,0)
                Lighting.FogStart=5;Lighting.FogEnd=60
                Lighting.FogColor=Color3.fromRGB(5,0,0)
            end)
            local floor=Instance.new("Part")
            floor.Size=Vector3.new(300,1,300);floor.Anchored=true;floor.CanCollide=true
            floor.Material=Enum.Material.SmoothPlastic;floor.Color=Color3.fromRGB(10,3,3)
            floor.CFrame=CFrame.new(domainCenter-Vector3.new(0,3,0));floor.Parent=workspace
            TweenService:Create(bg,TweenInfo.new(1.5),{BackgroundTransparency=1}):Play()
            task.delay(0.5,function()
                TweenService:Create(titleLabel,TweenInfo.new(1),{TextTransparency=0}):Play()
                task.delay(2.5,function()
                    TweenService:Create(titleLabel,TweenInfo.new(1.2),{TextTransparency=1}):Play()
                end)
            end)
            task.delay(8,function()
                if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame=originalCFrame end
                if floor and floor.Parent then floor:Destroy() end
                task.wait(1)
                if sg and sg.Parent then sg:Destroy() end
                pcall(function()
                    Lighting.Brightness=2;Lighting.ClockTime=14
                    Lighting.Ambient=Color3.fromRGB(70,70,70)
                    Lighting.OutdoorAmbient=Color3.fromRGB(128,128,128)
                end)
            end)
        end

        local function theRakeJumpscare()
            local SoundService=game:GetService("SoundService")
            local sg=Instance.new("ScreenGui",CoreGui)
            sg.Name="H3XRake";sg.IgnoreGuiInset=true;sg.ResetOnSpawn=false;sg.DisplayOrder=999999
            local im=Instance.new("ImageLabel",sg)
            im.Size=UDim2.new(1.2,0,1.2,0);im.Position=UDim2.new(-0.1,0,-0.1,0)
            im.BackgroundTransparency=1;im.Image="rbxassetid://108753859505348"
            local s1=Instance.new("Sound");s1.SoundId="rbxassetid://18967004856";s1.Volume=10;s1.Parent=SoundService
            local s2=Instance.new("Sound");s2.SoundId="rbxassetid://103396125105301";s2.Volume=10;s2.Parent=SoundService
            local shaking=true
            task.spawn(function()
                while shaking do
                    im.Position=UDim2.new(-0.1,math.random(-10,10),-0.1,math.random(-10,10))
                    task.wait(0.05)
                end
            end)
            s1:Play()
            task.delay(2,function()
                s2:Play()
                s2.Ended:Connect(function() shaking=false;sg:Destroy() end)
            end)
        end

        local U={loopKill=false,loopFire=false,loopSit=false,loopBring=false}
        local origSpeed={}

        local function processar(texto)
            if not texto or texto=="" or texto==" " then return end
            local base,sub,resto=parseCmd(texto)
            if not base then return end
            local meuNome=LocalPlayer.Name:lower()
            local char=LocalPlayer.Character
            local h=char and char:FindFirstChildOfClass("Humanoid")
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            local alvo=resto:match("^(%S+)")
            local extra=resto:match("^%S+%s+(.+)$")
            local isParaMim=(alvo and alvo:lower()==meuNome) or (alvo==nil and base~="verifique" and base~="noop" and base~="domainexpansion" and base~="flopparain" and base~="unfloppa")

            if base=="aviso" then
                local rem,msg=texto:match(";aviso%s+([^|]+)|(.+)$")
                if rem and msg then anuncio(rem,msg:gsub("||","|")) end
                return
            end
            if base=="ch" then
                local al,m=texto:match(";ch%s+(.-)%s+(.+)$")
                if al and m and string.lower(al)==meuNome then
                    enviarChat(m)
                    task.delay(0.5,function() WriteBoard(";ack "..meuNome.." ok") end)
                end
                return
            end
            if base=="chall" then
                local m=texto:match(";chall%s+(.+)$")
                if m then enviarChat(m) end
                return
            end
            if base=="ack" then return end
            if not isParaMim then return end

            if base=="kill" or base=="reset" then if h then h.Health=0 end;return end
            if base=="kick" then
                local mot=resto:match("^%S+%s+(.+)$") or "Kickado pelo H3X Admin"
                pcall(function() LocalPlayer:Kick(mot) end);return
            end
            if base=="loopkill" then
                U.loopKill=true
                task.spawn(function()
                    while U.loopKill do
                        local hu=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if hu then hu.Health=0 end
                        task.wait(1)
                    end
                end);return
            end
            if base=="unloopkill" then U.loopKill=false;return end
            if base=="fling" then
                if hrp then TweenService:Create(hrp,TweenInfo.new(1),{CFrame=CFrame.new(0,100000,0)}):Play() end;return
            end
            if base=="freeze" then if h then origSpeed[meuNome]=h.WalkSpeed;h.WalkSpeed=0 end;return end
            if base=="unfreeze" then if h then h.WalkSpeed=origSpeed[meuNome] or 16 end;return end
            if base=="sit" then if h then h.Sit=true end;return end
            if base=="loopsit" then
                U.loopSit=true
                task.spawn(function()
                    while U.loopSit do
                        local hu=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if hu then hu.Sit=true end
                        task.wait(0.5)
                    end
                end);return
            end
            if base=="unloopsit" then U.loopSit=false;return end
            if base=="fire" then
                if hrp then Instance.new("Fire",hrp) end
                if h then h:TakeDamage(100) end;return
            end
            if base=="loopfire" then
                U.loopFire=true
                task.spawn(function()
                    while U.loopFire do
                        local r=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if r then Instance.new("Fire",r) end
                        local hu=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if hu then hu:TakeDamage(100) end
                        task.wait(1)
                    end
                end);return
            end
            if base=="unloopfire" then U.loopFire=false;return end
            if base=="explode" then
                if hrp then
                    local ex=Instance.new("Explosion",workspace)
                    ex.Position=hrp.Position;ex.BlastPressure=500000;ex.BlastRadius=10
                    ex.DestroyJointRadiusPercent=0
                    if h then h.Health=0 end
                end;return
            end
            if base=="bring" then
                if not hrp then return end
                local tn=resto:match("^(%S+)%s+%S+$")
                if tn then
                    local tp=Players:FindFirstChild(tn)
                    local tr=tp and tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
                    if tr then tr.CFrame=hrp.CFrame*CFrame.new(0,2,3) end
                end;return
            end
            if base=="loopbring" then
                if not hrp then return end
                local tn=resto:match("^(%S+)%s+%S+$")
                U.loopBring=true
                task.spawn(function()
                    while U.loopBring do
                        if tn then
                            local tp=Players:FindFirstChild(tn)
                            local tr=tp and tp.Character and tp.Character:FindFirstChild("HumanoidRootPart")
                            local mr=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if tr and mr then tr.CFrame=mr.CFrame*CFrame.new(0,2,3) end
                        end
                        task.wait(0.5)
                    end
                end);return
            end
            if base=="unloopbring" then U.loopBring=false;return end
            if base=="jail" then
                if sub=="invisible" then jailInvisivel()
                elseif hrp then criarJail(hrp.Position) end
                return
            end
            if base=="unjail" then
                if sub=="invisible" then desjailInvisivel() else removerJail() end
                return
            end
            if base=="castigo" then castigo();return end
            if base=="descastigo" then descastigo();return end
            if base=="poste" then pendurarPoste();return end
            if base=="soltar" then limparPoste();return end
            if base=="chute" then chute();return end
            if base=="esmagar" then esmagar();return end
            if base=="backrooms" then backrooms();return end
            if base=="goner" then transformIntoGoner();return end
            if base=="flopparain" then floppaRain();return end
            if base=="unfloppa" then stopFloppa();return end
            if base=="domainexpansion" then domainExpansion();return end
            if base=="therakejumpscare" then theRakeJumpscare();return end
            if base=="tptroll" then
                if hrp then
                    local oldPos=hrp.Position
                    hrp.CFrame=CFrame.new(Vector3.new(799,-9,482))
                    task.delay(3,function() if hrp and hrp.Parent then hrp.CFrame=CFrame.new(oldPos) end end)
                end;return
            end
            if base=="float" then
                if hrp and h then
                    local maxH=hrp.Position.Y+50
                    h.WalkSpeed=0;h.JumpHeight=0
                    local bv=Instance.new("BodyVelocity",hrp)
                    bv.MaxForce=Vector3.new(0,math.huge,0)
                    bv.Velocity=Vector3.new(0,10,0)
                    task.spawn(function()
                        while hrp and hrp.Parent and h and h.Parent do
                            if hrp.Position.Y>=maxH then
                                if bv and bv.Parent then bv:Destroy() end
                                h.Health=0;break
                            end
                            task.wait(0.2)
                        end
                    end)
                end;return
            end
            if base=="lag" then
                if hrp then
                    for i=1,50 do
                        task.spawn(function()
                            pcall(function()
                                local ex=Instance.new("Explosion")
                                ex.Position=hrp.Position+Vector3.new(math.random(-10,10),math.random(0,5),math.random(-10,10))
                                ex.BlastRadius=20;ex.BlastPressure=1000000;ex.Parent=workspace
                            end)
                        end)
                    end
                end;return
            end
            if base=="verifique" then
                local RE=ReplicatedStorage:FindFirstChild("RE")
                if RE and RE:FindFirstChild("1Too1l") then RE["1Too1l"]:InvokeServer("PickingTools","LaundryBasket") end
                task.delay(0.5,function()
                    for _,p in ipairs(Players:GetPlayers()) do
                        local function possui()
                            return (p.Backpack and p.Backpack:FindFirstChild("LaundryBasket")) or (p.Character and p.Character:FindFirstChild("LaundryBasket"))
                        end
                        if possui() and p.Character then CreateTag(p.Name) end
                    end
                end);return
            end
            if base=="jumps1" then jumpscare("rbxassetid://126754882337711","rbxassetid://138873214826309");return end
            if base=="jumps2" then jumpscare("rbxassetid://86379969987314","rbxassetid://143942090");return end
            if base=="jumps3" then jumpscare("rbxassetid://127382022168206","rbxassetid://143942090");return end
            if base=="jumps4" then jumpscare("rbxassetid://95973611964555","rbxassetid://138873214826309");return end
            if base=="animejumpscare" then
                task.spawn(function()
                    pcall(function()
                        local gui=Instance.new("ScreenGui",CoreGui)
                        gui.Name="H3XAnimeJS";gui.ResetOnSpawn=false;gui.IgnoreGuiInset=true;gui.DisplayOrder=2147483647
                        local wb=Instance.new("Frame",gui)
                        wb.Size=UDim2.fromScale(1,1);wb.BackgroundColor3=Color3.new(1,1,1)
                        local im=Instance.new("ImageLabel",gui)
                        im.AnchorPoint=Vector2.new(0.5,0.5);im.Position=UDim2.fromScale(0.5,0.5)
                        im.Size=UDim2.fromScale(1,1);im.BackgroundTransparency=1;im.Image="rbxassetid://84838094344701"
                        local s1=Instance.new("Sound",gui);s1.SoundId="rbxassetid://82719020266339";s1.Volume=1
                        local s2=Instance.new("Sound",workspace);s2.SoundId="rbxassetid://134884767490882";s2.Volume=0.8;s2.Looped=true
                        task.delay(2.8,function() if im.Parent then im.Image="rbxassetid://95558068230459" end end)
                        local t=0
                        local conn
                        conn=RunService.RenderStepped:Connect(function(dt)
                            if not im.Parent then conn:Disconnect();return end
                            t+=dt*5
                            im.Position=UDim2.fromScale(0.5+math.sin(t*7)*0.02,0.5+math.cos(t*8)*0.02)
                            im.Size=UDim2.fromScale(1+math.sin(t*8)*0.1,1+math.sin(t*8)*0.1)
                            im.Rotation=math.sin(t*10)*9
                        end)
                        s1.Ended:Connect(function() if gui and gui.Parent then gui:Destroy() end; s2:Play() end)
                        s1:Play()
                    end)
                end);return
            end
            if base=="pararjumpscare" then
                pcall(function()
                    local gui=CoreGui:FindFirstChild("H3XAnimeJS")
                    if gui then gui:Destroy() end
                    for _,s in ipairs(workspace:GetChildren()) do
                        if s:IsA("Sound") and s.SoundId=="rbxassetid://134884767490882" then s:Stop();s:Destroy() end
                    end
                end);return
            end
        end
        _G.__H3XProcessar = processar

        local function attach()
            if not Board.pronto then return end
            Board.label:GetPropertyChangedSignal("Text"):Connect(function()
                local raw=Board.label.Text
                if not raw or raw=="" or raw==" " then return end
                if raw:match("^;noop") then return end
                if _G.__H3XExecutar then _G.__H3XExecutar(raw) end
            end)
            local raw=Board.label.Text
            if raw and raw~="" and raw~=" " and not raw:match("^;noop") then
                if _G.__H3XExecutar then _G.__H3XExecutar(raw) end
            end
        end
        if Board.pronto then attach()
        else task.spawn(function() while not Board.pronto do task.wait(0.2) end; attach() end) end
    end)

    -- ============================================================
    -- CHAT LISTENER
    -- ============================================================
    task.spawn(function()
        while not _G.__H3XProcessar or not _G.__H3XWriteBoard do task.wait(0.5) end
        local function processarChat(msg)
            if not msg or msg=="" then return end
            if msg:sub(1,1) ~= ";" then return end
            if msg:match("^;noop") then return end
            local base=parseCmd(msg)
            if not base then return end
            if _G.__H3XExecutar then _G.__H3XExecutar(msg) end
        end
        local conectado=false
        pcall(function()
            local tcs=game:GetService("TextChatService")
            if tcs.ChatVersion==Enum.ChatVersion.TextChatService then
                local general=tcs.TextChannels:FindFirstChild("RBXGeneral")
                if general then
                    general.MessageReceived:Connect(function(m)
                        if m.Text and m.Text~="" then processarChat(m.Text) end
                    end)
                    conectado=true
                end
            end
        end)
        if not conectado then
            pcall(function()
                local ev=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                local onMsg=ev and ev:FindFirstChild("OnMessageDoneFiltering")
                if onMsg then onMsg.OnClientEvent:Connect(function(d) if d and d.Message then processarChat(d.Message) end end) end
            end)
        end
    end)

    -- ============================================================
    -- ENVIO CENTRAL (exposto pro hub/admin)
    -- ============================================================
    local function EnviarComando(cmd, target, extra)
        target = tostring(target or ""):lower():gsub("^%s+",""):gsub("%s+$","")
        if target=="" and cmd~="verifique" and cmd~="chall" and cmd~="aviso" and cmd~="domainexpansion" and cmd~="flopparain" and cmd~="unfloppa" then return end
        local txt = ";"..cmd
        if target~="" then txt=txt.." "..target end
        if extra and extra~="" then
            extra=tostring(extra):gsub("|","||")
            txt=txt.." "..extra
        end
        if _G.__H3XWriteBoard then
            _G.__H3XWriteBoard(txt)
            task.delay(0.6,function() if _G.__H3XWriteBoard then _G.__H3XWriteBoard(" ") end end)
        end
        local enviou=false
        pcall(function()
            local tcs=game:GetService("TextChatService")
            if tcs.ChatVersion==Enum.ChatVersion.TextChatService then
                local ch=tcs.TextChannels:FindFirstChild("RBXGeneral")
                if ch then ch:SendAsync(txt);enviou=true end
            end
        end)
        if not enviou then
            pcall(function()
                local ev=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                if ev and ev:FindFirstChild("SayMessageRequest") then
                    ev.SayMessageRequest:FireServer(txt,"All")
                end
            end)
        end
    end
    _G.H3X.EnviarComando = EnviarComando

    print("[H3X] ✅ CORE carregado — chat reader + P2P + funções ativas")
end)
-- ═══════════════════════════════════════════════════════════════════
-- H3X ADMIN — painel WindUI (só abre pra quem tem acesso)
-- Depende do H3X_CORE carregado antes
-- ═══════════════════════════════════════════════════════════════════
task.spawn(function()
    task.wait(1.5)
    if not _G.H3X or not _G.H3X.EnviarComando then
        warn("[H3X ADMIN] Cole o H3X_CORE primeiro!")
        return
    end

    local Players      = game:GetService("Players")
    local LocalPlayer  = Players.LocalPlayer
    local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
    local EnviarComando = _G.H3X.EnviarComando

    local cargo, tipo, exp, dias, ok = _G.H3X.getInfoAcesso(LocalPlayer.Name)
    if not ok then
        warn("[H3X ADMIN] Sem acesso — painel não abre.")
        return
    end

    local WindUI
    for i=1,3 do
        local okL, res = pcall(function()
            return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/download/1.4.0/main.lua", true))()
        end)
        if okL and res then WindUI = res; break end
        task.wait(1)
    end
    if not WindUI then warn("[H3X ADMIN] WindUI falhou.") return end

    local AdminWindow = WindUI:CreateWindow({
        Title = "H3X ADMIN",
        Icon = "shield",
        Author = "H3X Team",
        Folder = "H3XAdmin",
        Size = UDim2.fromOffset(500, 620),
        Transparent = true, Theme = "Dark", Resizable = true,
        SideBarWidth = 180, HideSearchBar = false, ScrollBarEnabled = true,
    })
    WindUI:SetTheme("Dark")

    local function getPlayersList2()
        local t = {}
        for _, p in ipairs(Players:GetPlayers()) do table.insert(t, p.Name) end
        table.sort(t); return t
    end
    local registered = {}
    local function regDD(dd) if dd then table.insert(registered, dd) end end
    local function updDD()
        local list = getPlayersList2()
        for _, dd in ipairs(registered) do
            pcall(function()
                if dd.Refresh then dd:Refresh(list)
                elseif dd.SetValues then dd:SetValues(list)
                elseif dd.Set then dd:Set(list) end
            end)
        end
    end
    task.spawn(function() while true do task.wait(10); pcall(updDD) end end)
    local function ddPlayer(tab, title, desc, cb)
        local dd = tab:Dropdown({
            Title = title or "Jogador Alvo",
            Desc = desc or "Selecione",
            Values = getPlayersList2(), Multi = false, AllowNone = true,
            Callback = function(o) cb(o or "") end,
        })
        regDD(dd); return dd
    end
    local function btn(tab, title, desc, cb)
        return tab:Button({Title=title, Desc=desc, Callback=cb})
    end
    local function sec(tab, title)
        tab:Section({ Title = title, TextXAlignment = "Left", TextSize = 17 })
    end

    -- ====================== ABA COMANDOS ======================
    local TabCmd = AdminWindow:Tab({ Title = "Comandos", Icon = "terminal" })
    AdminWindow:SelectTab(1)
    local TName = ""
    ddPlayer(TabCmd, "Jogador Alvo", "Selecione", function(o) TName = o end)

    sec(TabCmd, "Trolls Físicos")
    btn(TabCmd, "/chute", "Arremessa", function() if TName~="" then EnviarComando("chute", TName) end end)
    btn(TabCmd, "/esmagar", "Achata", function() if TName~="" then EnviarComando("esmagar", TName) end end)
    btn(TabCmd, "/backrooms", "Backrooms real", function() if TName~="" then EnviarComando("backrooms", TName) end end)
    btn(TabCmd, "/poste", "Pendura no poste", function() if TName~="" then EnviarComando("poste", TName) end end)
    btn(TabCmd, "/soltar", "Solta do poste", function() if TName~="" then EnviarComando("soltar", TName) end end)

    sec(TabCmd, "Kill / Kick")
    btn(TabCmd, "/kill", "Mata", function() if TName~="" then EnviarComando("kill", TName) end end)
    btn(TabCmd, "/loopkill", "Loop kill", function() if TName~="" then EnviarComando("loopkill", TName) end end)
    btn(TabCmd, "/unloopkill", "Para", function() if TName~="" then EnviarComando("unloopkill", TName) end end)
    btn(TabCmd, "/kick", "Kicka", function() if TName~="" then EnviarComando("kick", TName, "Kickado pelo H3X Admin") end end)
    btn(TabCmd, "/explode", "Explode", function() if TName~="" then EnviarComando("explode", TName) end end)

    sec(TabCmd, "Jail")
    btn(TabCmd, "/jail", "Jaula", function() if TName~="" then EnviarComando("jail", TName) end end)
    btn(TabCmd, "/unjail", "Solta", function() if TName~="" then EnviarComando("unjail", TName) end end)
    btn(TabCmd, "/jail invisible", "Invisível", function() if TName~="" then EnviarComando("jail invisible", TName) end end)
    btn(TabCmd, "/unjail invisible", "Remove", function() if TName~="" then EnviarComando("unjail invisible", TName) end end)
    btn(TabCmd, "/castigo", "Castigo", function() if TName~="" then EnviarComando("castigo", TName) end end)
    btn(TabCmd, "/descastigo", "Solta", function() if TName~="" then EnviarComando("descastigo", TName) end end)

    sec(TabCmd, "Trolls Gerais")
    btn(TabCmd, "/freeze", "Congela", function() if TName~="" then EnviarComando("freeze", TName) end end)
    btn(TabCmd, "/unfreeze", "Descongela", function() if TName~="" then EnviarComando("unfreeze", TName) end end)
    btn(TabCmd, "/fling", "Fling", function() if TName~="" then EnviarComando("fling", TName) end end)
    btn(TabCmd, "/sit", "Senta", function() if TName~="" then EnviarComando("sit", TName) end end)
    btn(TabCmd, "/loopsit", "Loop sit", function() if TName~="" then EnviarComando("loopsit", TName) end end)
    btn(TabCmd, "/unloopsit", "Para", function() if TName~="" then EnviarComando("unloopsit", TName) end end)
    btn(TabCmd, "/fire", "Fogo", function() if TName~="" then EnviarComando("fire", TName) end end)
    btn(TabCmd, "/loopfire", "Loop fire", function() if TName~="" then EnviarComando("loopfire", TName) end end)
    btn(TabCmd, "/unloopfire", "Para", function() if TName~="" then EnviarComando("unloopfire", TName) end end)

    sec(TabCmd, "Bring")
    btn(TabCmd, "/bring", "Traz", function() if TName~="" then EnviarComando("bring", TName, LocalPlayer.Name) end end)
    btn(TabCmd, "/loopbring", "Loop bring", function() if TName~="" then EnviarComando("loopbring", TName, LocalPlayer.Name) end end)
    btn(TabCmd, "/unloopbring", "Para", function() if TName~="" then EnviarComando("unloopbring", TName) end end)

    sec(TabCmd, "Extras")
    btn(TabCmd, "/float", "Float", function() if TName~="" then EnviarComando("float", TName) end end)
    btn(TabCmd, "/tptroll", "TP troll", function() if TName~="" then EnviarComando("tptroll", TName) end end)
    btn(TabCmd, "/lag", "Lag", function() if TName~="" then EnviarComando("lag", TName) end end)
    btn(TabCmd, "/verifique", "Tags", function() EnviarComando("verifique","") end)

    sec(TabCmd, "Morphs & Efeitos")
    btn(TabCmd, "/goner", "Goner", function() if TName~="" then EnviarComando("goner", TName) end end)
    btn(TabCmd, "/domainexpansion", "Domain", function() if TName~="" then EnviarComando("domainexpansion", TName) end end)
    btn(TabCmd, "/flopparain", "Floppa Rain", function() if TName~="" then EnviarComando("flopparain", TName) end end)
    btn(TabCmd, "/unfloppa", "Para Floppa", function() if TName~="" then EnviarComando("unfloppa", TName) end end)

    sec(TabCmd, "Jumpscares")
    btn(TabCmd, "/jumps1", "Jumpscare 1", function() if TName~="" then EnviarComando("jumps1", TName) end end)
    btn(TabCmd, "/jumps2", "Jumpscare 2", function() if TName~="" then EnviarComando("jumps2", TName) end end)
    btn(TabCmd, "/jumps3", "Jumpscare 3", function() if TName~="" then EnviarComando("jumps3", TName) end end)
    btn(TabCmd, "/jumps4", "Jumpscare 4", function() if TName~="" then EnviarComando("jumps4", TName) end end)
    btn(TabCmd, "/therakejumpscare", "The Rake", function() if TName~="" then EnviarComando("therakejumpscare", TName) end end)
    btn(TabCmd, "/animejumpscare", "Anime", function() if TName~="" then EnviarComando("animejumpscare", TName) end end)
    btn(TabCmd, "/pararjumpscare", "Parar Anime", function() if TName~="" then EnviarComando("pararjumpscare", TName) end end)

    -- ====================== ABA AVISO ======================
    local TabAviso = AdminWindow:Tab({ Title = "Aviso", Icon = "megaphone" })
    local avisoRem, avisoMsg = "Admin", ""
    sec(TabAviso, "Enviar Aviso")
    TabAviso:Input({
        Title = "Remetente", Default = avisoRem,
        Callback = function(t) if t~="" then avisoRem=t end end
    })
    TabAviso:Input({
        Title = "Mensagem", Placeholder = "Digite...",
        Callback = function(t) avisoMsg = t or "" end
    })
    btn(TabAviso, "📢 Enviar Aviso", "Manda aviso na tela", function()
        if avisoMsg == "" then return end
        local txt = ";aviso " .. avisoRem .. "|" .. avisoMsg:gsub("|","||")
        if _G.__H3XWriteBoard then _G.__H3XWriteBoard(txt); task.delay(0.6, function() _G.__H3XWriteBoard(" ") end) end
        _G.H3X.enviarChat(txt)
    end)

    -- ====================== ABA CHAT ======================
    local TabChat = AdminWindow:Tab({ Title = "Chat", Icon = "message-circle" })
    local chatAlvo, chatMsg = "", ""
    sec(TabChat, "Forçar Chat")
    ddPlayer(TabChat, "Jogador Alvo", "Quem vai falar", function(o) chatAlvo = o end)
    TabChat:Input({
        Title = "Mensagem", Placeholder = "Texto",
        Callback = function(t) chatMsg = t or "" end
    })
    btn(TabChat, "💬 Enviar no Chat", "Faz o alvo falar", function()
        if chatAlvo=="" or chatMsg=="" then return end
        EnviarComando("ch", chatAlvo, chatMsg)
    end)
    btn(TabChat, "📢 Falar para Todos", "Todos os listeners falam", function()
        if chatMsg == "" then return end
        if _G.__H3XWriteBoard then _G.__H3XWriteBoard(";chall "..chatMsg); task.delay(0.6, function() _G.__H3XWriteBoard(" ") end) end
        _G.H3X.enviarChat(";chall "..chatMsg)
    end)

    -- ====================== ABA INFO ======================
    local TabInfo = AdminWindow:Tab({ Title = "Info", Icon = "info" })
    sec(TabInfo, "👤 Sua Conta")
    TabInfo:Paragraph({ Title = "Nick", Desc = "👤 " .. LocalPlayer.Name })
    TabInfo:Paragraph({ Title = "UserID", Desc = "🆔 " .. tostring(LocalPlayer.UserId) })
    TabInfo:Paragraph({ Title = "Cargo", Desc = cargo })
    sec(TabInfo, "⏳ Acesso")
    TabInfo:Paragraph({ Title = "Tipo", Desc = "🎫 " .. tipo })
    TabInfo:Paragraph({ Title = "Expira em", Desc = "📅 " .. exp })
    local lblDias = TabInfo:Paragraph({ Title = "Dias Restantes", Desc = "Carregando..." })
    task.spawn(function()
        while true do
            local _,_,_,d = _G.H3X.getInfoAcesso(LocalPlayer.Name)
            if d >= 999999 then lblDias.Desc = "♾️ Permanente"
            elseif d <= 0 then lblDias.Desc = "❌ EXPIRADO"
            else lblDias.Desc = "📅 " .. d .. " dias" end
            task.wait(1)
        end
    end)

    print("[H3X ADMIN] ✅ Painel aberto")
end)
