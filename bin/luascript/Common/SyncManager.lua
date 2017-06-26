---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/12/2
-- desc： 同步管理器
---------------------------------------------------
local flog
if not GRunOnClient then
    flog = require "basic/log"
end
local Const = require "Common/constant"

SyncManager = {}
local SyncManager = SyncManager

local function GetS2CRPC(unit)
    if unit then
        local scene = scene_manager.find_scene(unit:GetSceneID())
        if scene then
            return scene:get_rpc_code()
        else
            flog("error"," not found scene[" .. unit:GetSceneID() .. ']')
        end
    end
    return nil
end


local function SendMsg2TargetAndSource(unit, source, data)
    local A_unit = nil
    if unit.entityType == EntityType.Dummy then
        A_unit = unit
    elseif unit.entityType == EntityType.Pet then
        A_unit = unit.owner
    end

    if A_unit and A_unit.data.server_object and A_unit.data.server_object.send_message then
        A_unit.data.server_object:send_message(GetS2CRPC(unit), data)
    end

    if source then
        local B_unit = nil
        if source.entityType == EntityType.Dummy then
            B_unit = source
        elseif source.entityType == EntityType.Pet then
            B_unit = source.owner
        end

        if B_unit and A_unit and B_unit.uid == A_unit.uid then
            return 
        end
        if B_unit and B_unit.data.server_object and B_unit.data.server_object.send_message then
            B_unit.data.server_object:send_message(GetS2CRPC(unit), data)
        end
    end
end

function SyncManager.SC_OnCastSkillStart(unit, slot_id, skill_id, target)
    if not GRunOnClient then
        local target_id
        if target then
            target_id = target.uid
        end

        local host = unit
        if unit.entityType == EntityType.Pet then
            host = unit.owner
        end
        host:BroadcastToAoi(GetS2CRPC(unit),
        {
            func_name = "OnSyncOnCastSkillStart",
            entity_id = unit.uid,
            slot_id = slot_id,
            skill_id = skill_id,
            target_id = target_id,
            result = 0,
        })
    end
end

function SyncManager.OnSyncOnCastSkillStart(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    local target
    if data.target_id then
        target = SceneManager.GetEntityManager().GetPuppet(data.target_id)
    end
    if unit then
        local slot_id = data.slot_id
        local skill_id = data.skill_id
        if unit.skillManager.skills[slot_id] and 
            unit.skillManager.skills[slot_id].skill_id == skill_id then
            -- unit.skillManager:CastSkillStart(slot_id, {target = target})
            unit.commandManager.Excute(CreateSkillSyncCommand(unit, slot_id, target))
        else
            unit.skillManager:AddSkill( slot_id, skill_id, 1)
            -- unit.skillManager:CastSkillStart(slot_id, {target = target})
            unit.commandManager.Excute(CreateSkillSyncCommand(unit, slot_id, target))
        end
    end
end


function SyncManager.SC_OnSkillBreak(unit)
    if not GRunOnClient then
        unit:BroadcastToAoiIncludeSelf(
            GetS2CRPC(unit),
            {
                func_name = "OnSyncOnSkillBreak",
                entity_id = unit.uid,
                result = 0,
            }
        )
    end
end

function SyncManager.OnSyncOnSkillBreak(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        unit.skillManager:BreakSkill()
    end
end

function SyncManager.SC_OnTakeDamage(unit, damage, attacker, spell_id, event_type)
    if not GRunOnClient then
        local attacker_entity_id = nil
        if attacker then
            attacker_entity_id = attacker.uid
        end
        local data = {
                    func_name = "OnSyncOnTakeDamage",
                    entity_id = unit.uid,
                    num = damage,
                    attacker_entity_id = attacker_entity_id,
                    spell_id = spell_id,
                    current_hp = unit.hp, 
                    event_type = event_type,
                    result = 0,
                }

        SendMsg2TargetAndSource(unit, attacker, data)
    end
end

function SyncManager.OnSyncOnTakeDamage(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        local attacker = SceneManager.GetEntityManager().GetPuppet(data.attacker_entity_id)
        unit.commandManager.Excute(CreateBehitCommand(
            unit, 
            data.current_hp,
            data.num, 
            attacker, 
            data.spell_id, 
            data.event_type))
        
        -- unit:SetHp(data.current_hp)
        -- unit:TakeDamage(data.num, attacker, data.spell_id, data.event_type)
    end
end


function SyncManager.SC_OnAddHp(unit, num, source)
    if not GRunOnClient then
        local source_id 
        if source then
            source_id = source.uid
        end
        local data = {
                    func_name = "OnSyncOnAddHp",
                    entity_id = unit.uid,
                    num = num,
                    source_id = source_id,
                    current_hp = unit.hp, 
                    result = 0,
                }

        SendMsg2TargetAndSource(unit, source, data)
    end
end

function SyncManager.OnSyncOnAddHp(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        local source = SceneManager.GetEntityManager().GetPuppet(data.source_id)
        unit:SetHp(data.current_hp)
        unit:AddHp(data.num, source)
    end
end

function SyncManager.SC_OnAddMp(unit, num, source)
    if not GRunOnClient then
        local source_id 
        if source then
            source_id = source.uid
        end
        local data = {
                    func_name = "OnSyncOnAddMp",
                    entity_id = unit.uid,
                    num = num,
                    source_id = source_id,
                    current_mp = unit.mp, 
                    result = 0,
                }

        SendMsg2TargetAndSource(unit, source, data)
    end
end

function SyncManager.OnSyncOnAddMp(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        local source = SceneManager.GetEntityManager().GetPuppet(data.source_id)
        unit:SetMp(data.current_mp)
        unit:AddMp(data.num, source)
    end
end


function SyncManager.SC_OnReduceMp(unit, num, attacker)
    if not GRunOnClient then
        local attacker_id 
        if attacker then
            attacker_id = attacker.uid
        end
        local data = {
                    func_name = "OnSyncOnReduceMp",
                    entity_id = unit.uid,
                    num = num,
                    attacker_id = attacker_id,
                    current_mp = unit.mp, 
                    result = 0,
                }
        SendMsg2TargetAndSource(unit, attacker, data)
    end
end

function SyncManager.OnSyncOnReduceMp(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        local attacker = SceneManager.GetEntityManager().GetPuppet(data.attacker_id)
        unit:SetMp(data.current_mp)
        unit:ReduceMp(data.num, attacker)
    end
end

function SyncManager.OnSyncCurrentAttribute(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        for _,v in pairs(SyncAttribute) do
            if data[v] ~= nil then
                if type(unit[v]) ~= 'function' then
                    unit[v] = data[v]
                else
                    unit[v](data[v])
                end
            end
        end
        unit:NeedCalcProperty()
        unit.eventManager.Fire('OnCurrentAttributeChanged')
    end
end


function SyncManager.SC_CurrentAttribute(unit, data)
    if not GRunOnClient then
        data.entity_id = unit.uid
        data.func_name = "OnSyncCurrentAttribute"
        data.result = 0
        unit:BroadcastToAoiIncludeSelf(
            GetS2CRPC(unit),
            data
        )
    end
end

-- 添加buff的时候不仅要广播，还要更新 entity_info
function SyncManager.SC_AddBuff(unit, buff_id, data)
    if not GRunOnClient then

        local source_id = nil
        if data and data.source then
            source_id = data.source.uid
        end
        local source = nil 
        if data and data.source then
            source = data.source
        end 

        local config = GetConfig("growing_skill")
        local buff_data = config.Buff[tonumber(buff_id)]

        local info =   {
                    func_name = "OnSyncAddBuff",
                    entity_id = unit.uid,
                    source_id = source_id, 
                    buff_id = buff_id,
                    result = 0,
                }


        if buff_data.public == 1 then
            -- 公共buff就广播
            unit:BroadcastToAoiIncludeSelf(GetS2CRPC(unit), info)
        else
            SendMsg2TargetAndSource(unit, source, info)
        end
    end
end

function SyncManager.OnSyncAddBuff(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        local source = nil
        if data.source_id then
            source = SceneManager.GetEntityManager().GetPuppet(data.source_id)
        end
        unit.skillManager:AddBuff(data.buff_id,
            {
                source = source
            } )
    end
end

    -- 删除buff的时候不仅要广播，还要更新 entity_info
function SyncManager.SC_RemoveBuff(unit, buff)
    if not GRunOnClient then
        local buff_id = buff.buff_id
        local source_id = nil
        if buff.source then
            source_id = buff.source.uid
        end

        local config = GetConfig("growing_skill")
        local buff_data = config.Buff[tonumber(buff_id)]

        local info = {
                    func_name = "OnSyncRemoveBuff",
                    entity_id = unit.uid,
                    source_id = source_id, 
                    buff_id = buff_id,
                    result = 0,
                }

        if buff_data.public == 1 then
            -- 公共buff就广播
            unit:BroadcastToAoiIncludeSelf(GetS2CRPC(unit), info)
        else
            SendMsg2TargetAndSource(unit, buff.source, info)
        end
    end
end

function SyncManager.OnSyncRemoveBuff(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        local source = nil
        if data.source_id then
            source = SceneManager.GetEntityManager().GetPuppet(data.source_id)
        end
        --print('OnSyncRemoveBuff', data.buff_id)
        unit.skillManager:RemoveBuffByIDAndSource(data.buff_id, source)
    end
end

function SyncManager.SC_OnDied(unit, killer)
    if not GRunOnClient then
        local killer_entity_id
        if killer ~= nil then
            killer_entity_id = killer.uid
        end
        unit:BroadcastToAoiIncludeSelf(
            GetS2CRPC(unit),
        {
            func_name = "OnSyncOnDied",
            entity_id = unit.uid,
            killer_entity_id = killer_entity_id,
            result = 0,
        })
    end
end

function SyncManager.OnSyncOnDied(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        local killer = nil
        if data.killer_entity_id then
            killer = SceneManager.GetEntityManager().GetPuppet(data.killer_entity_id)
        end

        unit:OnDied(killer)
    end
end

function SyncManager.SC_OnSpurTo(unit, dir, speed, btime, time, atime, visible, bspeed, aspeed)
    if not GRunOnClient then

        unit:BroadcastToAoiIncludeSelf(
            GetS2CRPC(unit),
        {
            func_name = "OnSyncOnSpurTo",
            entity_id = unit.uid,
            dir_x = math.floor(dir.x*1000),
            dir_y = math.floor(dir.y*1000),
            dir_z = math.floor(dir.z*1000),
            speed = math.floor((speed or 0)*1000),
            btime = math.floor((btime or 0)*1000),
            time = math.floor((time or 0)*1000),
            atime = math.floor((atime or 0)*1000),
            visible = visible,
            bspeed = math.floor((bspeed or 0)*1000),
            aspeed = math.floor((aspeed or 0)*1000),
            result = 0,
        })
    end
end

function SyncManager.OnSyncOnSpurTo(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    if unit then
        unit:SpurtTo(
            Vector3.New(data.dir_x/1000, data.dir_y/1000, data.dir_z/1000),
            data.speed/1000,
            data.btime/1000,
            data.time/1000,
            data.atime/1000,
            data.visible,
            data.bspeed/1000,
            data.speed/1000
            )
    end
end

function SyncManager.SC_OnResurrect(unit, data)
    if not GRunOnClient then
        unit:BroadcastToAoi(
            GetS2CRPC(unit),
        {
            func_name = "OnSyncOnResurrect",
            entity_id = unit.uid,
            data = data,
            result = 0,
        })
    end
end

function SyncManager.OnSyncOnResurrect(data)
    SceneManager.GetEntityManager().ResurrectPuppet(data.entity_id, data.data)
end

function SyncManager.CS_CastSkill(unit, slot_id, target_entity_id)
    if GRunOnClient and unit:IsControl() then
        MessageManager.RequestLua(SceneManager.GetRPCMSGCode(), 
            {
                func_name = "on_cast_skill",
                entity_id = unit.uid,
                slot_id = slot_id,
                target_entity_id = target_entity_id,
                result = 0,
                mod = 'skill',
            },true)
    end
end

function SyncManager.SC_CastSkillFailed(unit, slot_id)
    if unit and unit.data.server_object and unit.data.server_object.send_message then
        unit.data.server_object:send_message(GetS2CRPC(unit), 
            {
                func_name = "OnSyncCastSkillFailed",
                slot_id = slot_id,
                entity_id = unit.uid,
            })
    end
end

function SyncManager.OnSyncCastSkillFailed(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    local slot_id = data.slot_id
    unit.skillManager:ClearCommonCD()
    unit.skillManager.skills[slot_id]:RefreshCD()
end

function SyncManager.on_cast_skill(avatar, input, syn_data)
    --flog("info", "on_cast_skill " .. input.entity_id)
    local EntityManager = avatar:get_entity_manager()
    if not EntityManager then
        --flog("error", ' find no entitymanager with entity_id = ' .. input.entity_id)
        return 
    end
    local unit = EntityManager.GetPuppet(input.entity_id)

    local slot_id = input.slot_id
    local target = EntityManager.GetPuppet(input.target_entity_id)
    if unit then
        if target == nil then
            unit:CastSkillToSky(slot_id)
        else
            unit.target = target
            local is_excute, res = unit:CastSkill( slot_id, target)
            if is_excute == true and res == false then
                SyncManager.SC_CastSkillFailed(unit, slot_id)
            end
        end
    else
        --flog("warn", "can't find pupet " .. input.entity_id)
    end
end


function SyncManager.SC_BroadcastUnitMsg(unit, event, data)
    if not GRunOnClient then
        unit:BroadcastToAoiIncludeSelf(
            GetS2CRPC(unit),
        {
            func_name = "OnSyncBroadcastUnitMsg",
            entity_id = unit.uid,
            event = event,
            data = data,
            result = 0,
        })
    end
end

function SyncManager.OnSyncBroadcastUnitMsg(data)
    local unit = SceneManager.GetEntityManager().GetPuppet(data.entity_id)
    unit:OnReceiveBroadcastUnitMsg(data.event, data.data)
end


local function on_client_rpc(input)
    
    local func_name = input.func_name
    if func_name == nil or SyncManager[func_name] == nil then
        --func_name = func_name or "nil"
        --flog("error", "on_game_rpc: no func_name  "..func_name)
        return
    end

    SyncManager[func_name](input)
end

-- 服务器远程过程函数
function SyncManager.on_server_rpc( avatar, input)
    local func_name = input.func_name
    if func_name == nil or SyncManager[func_name] == nil then
        --func_name = func_name or "nil"
        --flog("error", "on_game_rpc: no func_name  "..func_name)
        return
    end

    SyncManager[func_name](avatar, input)
end

if GRunOnClient then
    MessageManager.RegisterMessage(Const.SC_MESSAGE_LUA_GAME_RPC, on_client_rpc)
    MessageManager.RegisterMessage(Const.DC_MESSAGE_LUA_GAME_RPC, on_client_rpc)
else

end

return SyncManager