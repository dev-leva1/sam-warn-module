if SAM_LOADED then return end

local sam, command, language = sam, sam.command, sam.language

-- Добавляем языковые строки
language.Add("warn", "{A} выдал предупреждение {T} ({V}/{V_2}): {V_3}")
language.Add("unwarn", "{A} снял последнее предупреждение с {T}")
language.Add("unwarn_id", "{A} снял предупреждение #{V} с {T}")
language.Add("warning_not_found", "Предупреждение не найдено или уже снято!")
language.Add("no_active_warnings", "У {T} нет активных предупреждений")
language.Add("warnings_list", "Предупреждения игрока {T}:")
language.Add("warning_entry", "#{V} [{V_2}] от {V_3}: {V_4}")

command.set_category("Punishment")

-- Создаем таблицу для хранения предупреждений
if not sql.TableExists("sam_warnings") then
    sql.Query([[
        CREATE TABLE IF NOT EXISTS sam_warnings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            steam_id VARCHAR(32),
            admin_steam_id VARCHAR(32),
            reason TEXT,
            timestamp INTEGER,
            expired INTEGER DEFAULT 0
        )
    ]])
end

-- Настройки системы предупреждений
local WARNING_SETTINGS = {
    max_warnings = 3,
    expire_time = 7 * 24 * 60 * 60,
    punishments = {
        [1] = function(ply) RunConsoleCommand("sam", "mute", "#" .. ply:EntIndex(), "30", "Первое предупреждение") end,
        [2] = function(ply) RunConsoleCommand("sam", "kick", "#" .. ply:EntIndex(), "Второе предупреждение") end,
        [3] = function(ply) RunConsoleCommand("sam", "ban", "#" .. ply:EntIndex(), "1440", "Превышен лимит предупреждений") end
    }
}

-- Функции для работы с предупреждениями
local function GetActiveWarnings(steam_id)
    local current_time = os.time()
    local query = string.format([[
        SELECT COUNT(*) as count 
        FROM sam_warnings 
        WHERE steam_id = '%s' 
        AND expired = 0
    ]], steam_id)
    
    local result = sql.QueryRow(query)
    if result then
        return tonumber(result.count) or 0
    end
    return 0
end

local function GetWarnings(steam_id)
    local query = string.format([[
        SELECT * 
        FROM sam_warnings 
        WHERE steam_id = '%s' 
        AND expired = 0 
        ORDER BY id DESC
    ]], steam_id)
    
    local result = sql.Query(query)
    if result then
        return result
    end
    return {}
end

-- Регистрация команд
do
    command.new("warn")
        :SetPermission("warn", "admin")
        :SetCategory("Punishment")
        :Help("Выдать предупреждение игроку")
        :AddArg("player", {single_target = true})
        :AddArg("text", {hint = "reason"})
        :OnExecute(function(ply, targets, reason)
            if not IsValid(ply) then return end
            
            local target = targets[1]
            if not IsValid(target) then return end
            
            local steam_id = target:SteamID64()
            local admin_steam_id = ply:SteamID64()
            
            -- Экранируем причину предупреждения
            local safe_reason = sql.SQLStr(reason, true) -- true означает не добавлять кавычки
            
            local query = string.format([[
                INSERT INTO sam_warnings 
                (steam_id, admin_steam_id, reason, timestamp, expired) 
                VALUES ('%s', '%s', '%s', %d, 0)
            ]], steam_id, admin_steam_id, safe_reason, os.time())
            
            local success = sql.Query(query)
            if success == false then
                print("[SAM Warnings] SQL Error:", sql.LastError())
                print("[SAM Warnings] Query:", query)
                return
            end
            
            local warnings_count = GetActiveWarnings(steam_id)
            
            sam.player.send_message(nil, "warn", {
                A = ply, 
                T = targets,
                V = warnings_count, 
                V_2 = WARNING_SETTINGS.max_warnings, 
                V_3 = reason
            })
            
            if WARNING_SETTINGS.punishments[warnings_count] then
                WARNING_SETTINGS.punishments[warnings_count](target)
            end
        end)
    :End()

    command.new("unwarn")
        :SetPermission("unwarn", "admin")
        :SetCategory("Punishment")
        :Help("Снять предупреждение с игрока")
        :AddArg("player", {single_target = true})
        :AddArg("number", {hint = "warn_id", optional = true})
        :OnExecute(function(ply, targets, warn_id)
            if not IsValid(ply) then return end
            
            local target = targets[1]
            if not IsValid(target) then return end
            
            local steam_id = target:SteamID64()
            local warnings = GetWarnings(steam_id)
            
            if warn_id then
                local query = string.format([[
                    UPDATE sam_warnings 
                    SET expired = 1 
                    WHERE id = %d AND steam_id = '%s' AND expired = 0
                ]], warn_id, steam_id)
                
                local success = sql.Query(query)
                if success ~= false then
                    sam.player.send_message(nil, "unwarn_id", {
                        A = ply, 
                        T = targets, -- Передаем всю таблицу целей
                        V = warn_id
                    })
                else
                    ply:sam_send_message("warning_not_found")
                end
            else
                if #warnings > 0 then
                    local last_warning = warnings[1]
                    local query = string.format([[
                        UPDATE sam_warnings 
                        SET expired = 1 
                        WHERE id = %d
                    ]], last_warning.id)
                    
                    sql.Query(query)
                    
                    sam.player.send_message(nil, "unwarn", {
                        A = ply, 
                        T = targets -- Передаем всю таблицу целей
                    })
                else
                    ply:sam_send_message("no_active_warnings", {
                        T = targets -- Передаем всю таблицу целей
                    })
                end
            end
        end)
    :End()

    command.new("warnings")
        :SetPermission("warnings", "admin")
        :SetCategory("Punishment")
        :Help("Просмотр предупреждений игрока")
        :AddArg("player", {single_target = true})
        :OnExecute(function(ply, targets)
            if not IsValid(ply) then return end
            
            local target = targets[1]
            if not IsValid(target) then return end
            
            local steam_id = target:SteamID64()
            local warnings = GetWarnings(steam_id)
            
            if #warnings > 0 then
                ply:sam_send_message("warnings_list", {
                    T = targets -- Передаем всю таблицу целей
                })
                
                for _, warning in ipairs(warnings) do
                    local admin = player.GetBySteamID64(warning.admin_steam_id)
                    local admin_name = admin and admin:Name() or "Неизвестный админ"
                    local date = os.date("%d/%m/%Y %H:%M", tonumber(warning.timestamp))
                    
                    ply:sam_send_message("warning_entry", {
                        V = warning.id,
                        V_2 = date,
                        V_3 = admin_name,
                        V_4 = warning.reason
                    })
                end
            else
                ply:sam_send_message("no_active_warnings", {
                    T = targets -- Передаем всю таблицу целей
                })
            end
        end)
    :End()
end

-- Автоматическая очистка устаревших предупреждений
timer.Create("SAM.WarningsCleanup", 3600, 0, function()
    local current_time = os.time()
    sql.Query(string.format([[
        UPDATE sam_warnings 
        SET expired = 1 
        WHERE timestamp + %d < %d 
        AND expired = 0
    ]], WARNING_SETTINGS.expire_time, current_time))
end)

-- Добавляем права доступа
sam.permissions.add("warn", nil, "admin")
sam.permissions.add("unwarn", nil, "admin")
sam.permissions.add("warnings", nil, "admin") 
