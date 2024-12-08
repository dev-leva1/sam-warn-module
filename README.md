Основные возможности:​

Выдача предупреждений игрокам с указанием причины
Просмотр активных предупреждений игрока
Снятие предупреждений (последнего или по ID)
Автоматические наказания при достижении определенного количества предупреждений
Автоматическое удаление устаревших предупреждений

Команды:​

!warn <игрок> <причина> - Выдать предупреждение игроку
!unwarn <игрок> [ID] - Снять предупреждение (последнее или по ID)
!warnings <игрок> - Просмотреть предупреждения игрока

Автоматические наказания:​

1 предупреждение - Мут на 30 минут
2 предупреждения - Кик с сервера
3 предупреждения - Бан на 24 часа

Установка​

Скачайте файл warnings.lua
Поместите его в папку garrysmod/addons/sam/lua/sam/modules/
Перезапустите сервер или выполните команду sam reload

Настройка​
Вы можете изменить настройки в начале файла warnings.lua:

local WARNING_SETTINGS = {
    max_warnings = 3, -- Максимальное количество предупреждений
    expire_time = 7 * 24 * 60 * 60, -- Время жизни предупреждения (7 дней)
    punishments = { -- Автоматические наказания
        [1] = function(ply) RunConsoleCommand("sam", "mute", "#" .. ply:EntIndex(), "30", "Первое предупреждение") end,
        [2] = function(ply) RunConsoleCommand("sam", "kick", "#" .. ply:EntIndex(), "Второе предупреждение") end,
        [3] = function(ply) RunConsoleCommand("sam", "ban", "#" .. ply:EntIndex(), "1440", "Превышен лимит предупреждений") end
    }
}

Права доступа​

Модуль автоматически добавляет следующие права:
warn - Возможность выдавать предупреждения
unwarn - Возможность снимать предупреждения
warnings - Возможность просматривать предупреждения
По умолчанию все права доступны группе "admin" и выше.

Зависимости
​
SAM Admin Mod (версия 1.0 или выше)
SQLite (встроен в Garry's Mod)

Примечания​

Предупреждения хранятся в SQLite базе данных
Предупреждения автоматически удаляются через 7 дней (настраивается)
При достижении максимального количества предупреждений игрок получает бан
Все действия логируются в чате сервера
