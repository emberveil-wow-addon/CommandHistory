--[[--------------------------------------------------------------------
  CommandHistory 0.2.1
  Client 1.12.1 / Lua 5.1 (Emberveil).

  The chat input box on this client does not walk back through what was
  typed before, which makes repeating a slash command a retyping exercise.
  The widget documentation lists both EditBox:AddHistoryLine and
  EditBox:SetAltArrowKeyMode, so the client does carry the machinery — it is
  simply not fed or not reachable with the plain arrow keys.

  This addon does three things, each independent of the others, so a failure
  of one still leaves the rest working:
    1. turns off alt-arrow mode, which is what makes bare Up and Down
       reach the history instead of moving the caret;
    2. feeds every sent line into the client's own history;
    3. keeps its own list as well and walks it from an OnArrowPressed
       handler, so the history works even if the built in one does not.
  The list is saved, so it is still there after a relog.
----------------------------------------------------------------------]]

local ADDON   = "CommandHistory"
local VERSION = "0.2.1"

local defaults = {
  lines = nil,   -- filled lazily: the remembered input, oldest first
  size  = 30,    -- how many lines to keep
  own   = true,  -- walk our own list from the arrow handler
  alt   = false, -- alt arrow mode: false means bare arrows browse history
  minimap = true,-- show the button next to the minimap
  mmangle = 200, -- where on the ring that button sits, in degrees
  x = nil,       -- panel position, absolute bottom left corner
  y = nil,
  pins    = nil, -- filled lazily: text -> true for the lines kept on top
  uses    = nil, -- text -> how many times it has been typed
  lang    = "auto", -- "ru", "en" or "auto" for the client locale
}

----------------------------------------------------------------------
-- localisation
----------------------------------------------------------------------

local STRINGS = {
  ru = {
    title      = "История команд",
    search     = "Поиск:",
    searchTip  = "щёлкните по полю поиска и печатайте",
    clearFind  = "Очистить поиск",
    tipUp      = "Вверх на строку, с Shift — на страницу",
    tipDown    = "Вниз на строку, с Shift — на страницу",
    clearAll   = "Очистить всё",
    hintClick  = "клик по строке — в поле ввода чата",
    tipRow     = "Щёлкните, чтобы подставить команду в поле ввода",
    nothing    = "ничего не найдено",
    counter    = "%d-%d из %d (всего %d)",
    tipPin     = "Закрепить: строка держится сверху и не вытесняется",
    tipMacro   = "Сделать макрос из этой команды",
    tipDel     = "Удалить эту строку",
    mmOpen     = "ЛКМ — открыть список",
    mmHide     = "ПКМ — убрать эту кнопку",
    mmMove     = "Shift+тащить — переместить по кругу",
    noBox      = "поле ввода не найдено.",
    noMacroApi = "этот клиент не даёт создавать макросы из аддона.",
    macroCmd   = "макрос имеет смысл только для команды, начинающейся со слэша.",
    macroOk    = "макрос |cffffd700%s|r создан — откройте «Макросы» и перетащите его на панель.",
    macroFail  = "|cffff8080макрос не создан|r — скорее всего кончились слоты (18 общих и 18 личных).",
    deleted    = "удалено: %s",
    cleared    = "история очищена.",
    panelFail  = "|cffff8080не удалось построить панель:|r %s",
    mmGone     = "кнопка у миникарты убрана. Вернуть: /cmdh minimap",
    mmFail     = "|cffff8080кнопку у миникарты построить не вышло:|r %s",
    noSuch     = "такой строки в истории нет.",
    wasReset   = "окно и кнопка возвращены на места по умолчанию.",
    mmState    = "кнопка у миникарты: %s",
    sizeSet    = "хранить строк: %d, сейчас в истории: %d",
    sizeErr    = "укажите число от 1 до 200, например: /cmdh size 50",
    altOn      = "стрелки с Alt: вкл (обычные стрелки двигают курсор)",
    altOff     = "стрелки с Alt: выкл (обычные стрелки листают историю)",
    ownState   = "своя история: %s",
    ownOff     = "выкл — только встроенная",
    empty      = "история пуста.",
    listHead   = "последние строки (%d из %d):",
    probeHead  = "|cffffd700--- проверка ---|r",
    probeBox   = "поле ввода найдено: %s, перехвачено полей: %d",
    probeApi   = "AddHistoryLine: %s, SetAltArrowKeyMode: %s, GetText: %s",
    probeHook  = "наши обработчики приняты: %s",
    probeNone  = "|cffff8080ни одного|r",
    probeLines = "строк в истории: %d, хранить: %d, своя история: %s",
    keysLive   = "живые обработчики: %s",
    keysAsk    = "щёлкните в поле ввода, понажимайте стрелки И несколько букв — 15 секунд слушаю.",
    keysNote   = "буквы печатаются, а стрелки нет — их забирает клиент; тишина совсем — клавиши до аддонов не доходят.",
    keysDone   = "слежка за клавишами закончена.",
    langSet    = "язык: %s",
    help       = "команды: /commandhistory [panel | N | out | cmds | minimap | reset | list | clear | size N | lang ru/en/auto | alt | own | keys | probe]",
    on         = "вкл",
    off        = "выкл",
    inputLabel = "Команда:",
    inputTip   = "печатайте или вставьте из буфера: Ctrl+V. Enter — отправить",
    inputHint  = "Ctrl+V — вставить из буфера · Enter — отправить · ответ смотрите по «?» в списке",
    sendTip    = "Отправить строку",
    send       = "Отправить",
    sendNoText = "строка пуста.",
    sendHow    = "отправлено через %s",
    sendFail   = "не удалось отправить: клиент не отдал ни одного способа.",
    sendManual = "сам отправить не смог — строка в поле ввода чата, нажмите Enter.",
    noRead     = "клиент не даёт прочитать поле ввода (нет GetText) — своя форма ввода тут невозможна.",
    tipOut     = "Показать ответ на эту команду",
    outTitle   = "Ответ на команду",
    outFor     = "команда: %s",
    outHint    = "каждая строка выделяется отдельно: щёлкните её, выделите и Ctrl+C · листать — стрелками слева",
    outEmpty   = "ответа не записано — отправьте команду из этого окна или из поля ввода",
    outFull    = "Во весь экран",
    outSmall   = "Обычный размер",
    outClose   = "Закрыть",
    outLines   = "строки %d-%d из %d",
    outNone    = "по этой команде ответа не записано.",
    outLast    = "последняя команда: %s",
    probeEdit  = "своё поле ввода: GetText %s, GetNumLetters %s, Insert %s, SetMultiLine %s, HighlightText %s",
    probeOut   = "записано ответов: команд %d, строк %d, слушаю сейчас: %s",
    probeCatch = "перехват AddMessage: %s, события чата: подписаны (%s)",
    outWho     = "найдено игроков: %d",
    cmdsHead   = "команды всех аддонов: обработчиков %d, команд %d",
    cmdsNone   = "не нашёл ни одной зарегистрированной команды.",
    cmdsTitle  = "все команды",
    outClear   = "Очистить",
    outClearTip = "Забыть ответ на эту команду. С Shift — забыть все записанные ответы",
    outCleared = "ответ на «%s» забыт.",
    outClearedAll = "все записанные ответы забыты (%d).",
    probeEsc   = "Esc: UISpecialFrames %s, окно в списке %s, перехват меню %s",
    probePaste = "проверка буфера: щёлкните поле «Команда» в окне истории, нажмите Ctrl+V и посмотрите, появился ли текст. Символов в поле сейчас: %s",
  },
  en = {
    title      = "Command history",
    search     = "Search:",
    searchTip  = "click the search field and type",
    clearFind  = "Clear the search",
    tipUp      = "Up one line, Shift for a whole page",
    tipDown    = "Down one line, Shift for a whole page",
    clearAll   = "Clear all",
    hintClick  = "click a line - into the chat box",
    tipRow     = "Click to put the command in the chat box",
    nothing    = "nothing found",
    counter    = "%d-%d of %d (%d stored)",
    tipPin     = "Pin: the line stays on top and is never dropped",
    tipMacro   = "Make a macro out of this command",
    tipDel     = "Delete this line",
    mmOpen     = "Left click — open the list",
    mmHide     = "Right click — hide this button",
    mmMove     = "Shift+drag — move around the ring",
    noBox      = "the chat input box was not found.",
    noMacroApi = "this client does not let an addon create macros.",
    macroCmd   = "a macro only makes sense for a line that starts with a slash.",
    macroOk    = "macro |cffffd700%s|r created — open Macros and drag it onto a bar.",
    macroFail  = "|cffff8080macro not created|r — most likely out of slots (18 general, 18 personal).",
    deleted    = "deleted: %s",
    cleared    = "history cleared.",
    panelFail  = "|cffff8080could not build the panel:|r %s",
    mmGone     = "minimap button hidden. Bring it back: /cmdh minimap",
    mmFail     = "|cffff8080could not build the minimap button:|r %s",
    noSuch     = "there is no such line in the history.",
    wasReset   = "window and button are back where they started.",
    mmState    = "minimap button: %s",
    sizeSet    = "keeping %d lines, %d stored right now",
    sizeErr    = "give a number from 1 to 200, for example: /cmdh size 50",
    altOn      = "alt arrow mode: on (bare arrows move the caret)",
    altOff     = "alt arrow mode: off (bare arrows walk the history)",
    ownState   = "own history: %s",
    ownOff     = "off — the built in one only",
    empty      = "the history is empty.",
    listHead   = "latest lines (%d of %d):",
    probeHead  = "|cffffd700--- check ---|r",
    probeBox   = "input box found: %s, boxes hooked: %d",
    probeApi   = "AddHistoryLine: %s, SetAltArrowKeyMode: %s, GetText: %s",
    probeHook  = "handlers the client accepted: %s",
    probeNone  = "|cffff8080none|r",
    probeLines = "lines stored: %d, keeping: %d, own history: %s",
    keysLive   = "live handlers: %s",
    keysAsk    = "click the chat box, press the arrows AND a few letters — listening for 15 seconds.",
    keysNote   = "letters printed but no arrows — the client keeps them; nothing at all — no keys reach addons.",
    keysDone   = "key watch finished.",
    langSet    = "language: %s",
    help       = "commands: /commandhistory [panel | N | out | cmds | minimap | reset | list | clear | size N | lang ru/en/auto | alt | own | keys | probe]",
    on         = "on",
    off        = "off",
    inputLabel = "Command:",
    inputTip   = "type or paste from the clipboard: Ctrl+V. Enter sends",
    inputHint  = "Ctrl+V pastes from the clipboard - Enter sends - the answer is behind the \"?\" in the list",
    sendTip    = "Send the line",
    send       = "Send",
    sendNoText = "the line is empty.",
    sendHow    = "sent through %s",
    sendFail   = "could not send: the client offered no way to do it.",
    sendManual = "could not send it myself - the line is in the chat box, press Enter.",
    noRead     = "the client will not let the input field be read (no GetText) - an own input form is impossible here.",
    tipOut     = "Show the answer to this command",
    outTitle   = "Command output",
    outFor     = "command: %s",
    outHint    = "every line is its own field: click it, select and press Ctrl+C - page with the arrows on the left",
    outEmpty   = "nothing recorded - send a command from this window or from the input field",
    outFull    = "Full screen",
    outSmall   = "Normal size",
    outClose   = "Close",
    outLines   = "lines %d-%d of %d",
    outNone    = "nothing was recorded for this command.",
    outLast    = "last command: %s",
    probeEdit  = "own edit box: GetText %s, GetNumLetters %s, Insert %s, SetMultiLine %s, HighlightText %s",
    probeOut   = "recorded answers: %d commands, %d lines, listening now: %s",
    probeCatch = "AddMessage hook: %s, chat events: subscribed (%s)",
    outWho     = "players found: %d",
    cmdsHead   = "commands of every addon: %d handlers, %d commands",
    cmdsNone   = "no registered command found.",
    cmdsTitle  = "every command",
    outClear   = "Clear",
    outClearTip = "Forget the answer to this command. With Shift, forget every recorded answer",
    outCleared = "the answer to \"%s\" is forgotten.",
    outClearedAll = "every recorded answer is forgotten (%d).",
    probeEsc   = "Esc: UISpecialFrames %s, window listed %s, menu hook %s",
    probePaste = "clipboard check: click the Command field in the history window, press Ctrl+V and see whether text appears. Letters in the field now: %s",
  },
}

local function CurrentLang()
  local pick = CommandHistoryDB and CommandHistoryDB.lang or "auto"
  if pick == "ru" or pick == "en" then return pick end
  if GetLocale and GetLocale() == "ruRU" then return "ru" end
  return "en"
end

local function L(key) return STRINGS[CurrentLang()][key] or key end
local function Lf(key, a, b, c, d, e, f)
  return string.format(L(key), a, b, c, d, e, f)
end

----------------------------------------------------------------------
-- state
----------------------------------------------------------------------

local hooked  = {}        -- box -> true
local slots   = {}        -- script name -> true when the client accepted it
local spy     = 0         -- seconds left of the key spy
local boxCount = 0
local pos, draft = 0, nil -- how far back we are, and the unsent line
local driver
local OutStartHook        -- starts recording the answer; set further down
local origGameMenu        -- the client's ToggleGameMenu, once we wrap it

local speaking = false      -- true while our own line is going to the chat

local OutRecordHook       -- set once the recorder exists
local chatHookOk = false  -- did wrapping AddMessage actually take?
chatEventCount = 0        -- how many chat events the client accepted

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66" .. ADDON .. ":|r " .. msg)
  end
  -- If the frame would not take our wrapper, the line has to be handed to the
  -- recorder here instead, or the answer to an addon command is lost.
  if not chatHookOk and OutRecordHook then OutRecordHook(msg) end
end

-- Some of our own lines are about the addon rather than about the command --
-- "sent through ...", "nothing recorded" -- and those have no business inside
-- the recorded answer. Everything else we print is a real reply to a slash
-- command and belongs there, so only these are marked.
local function Report(msg)
  speaking = true
  Print(msg)
  speaking = false
end

-- Escape closes a window whose NAME is in UISpecialFrames. The list holds
-- names, so an unnamed frame can never be registered, and the same name must
-- not go in twice.
local function EscClose(name)
  if type(UISpecialFrames) ~= "table" or not name then return end
  local i = 1
  while UISpecialFrames[i] do
    if UISpecialFrames[i] == name then return end
    i = i + 1
  end
  UISpecialFrames[i] = name
end

local function InitDB()
  if type(CommandHistoryDB) ~= "table" then CommandHistoryDB = {} end
  for k, v in pairs(defaults) do
    if CommandHistoryDB[k] == nil and v ~= nil then CommandHistoryDB[k] = v end
  end
  if type(CommandHistoryDB.lines) ~= "table" then CommandHistoryDB.lines = {} end
  if type(CommandHistoryDB.pins) ~= "table" then CommandHistoryDB.pins = {} end
  if type(CommandHistoryDB.uses) ~= "table" then CommandHistoryDB.uses = {} end
  if type(CommandHistoryDB.size) ~= "number" or CommandHistoryDB.size < 1 then
    CommandHistoryDB.size = 30
  end

  -- older builds let blank lines in; squeeze them out once
  local clean, n = {}, 0
  local i = 1
  while CommandHistoryDB.lines[i] ~= nil do
    local line = CommandHistoryDB.lines[i]
    if type(line) == "string" and string.find(line, "%S")
       and string.sub(line, 1, 1) == "/" then
      n = n + 1
      clean[n] = line
    end
    i = i + 1
  end
  CommandHistoryDB.lines = clean
end

local function Count()
  local n = 0
  while CommandHistoryDB.lines[n + 1] ~= nil do n = n + 1 end
  return n
end

----------------------------------------------------------------------
-- the list
----------------------------------------------------------------------

local function IsCommand(line)
  return type(line) == "string" and string.sub(line, 1, 1) == "/"
end

local function Pinned(line)
  return line ~= nil and CommandHistoryDB.pins[line] == true
end

-- Drop one line and close the gap behind it.
local function RemoveAt(pos)
  local lines = CommandHistoryDB.lines
  local n = Count()
  if type(pos) ~= "number" or pos < 1 or pos > n then return false end
  local i = pos
  while i < n do
    lines[i] = lines[i + 1]
    i = i + 1
  end
  lines[n] = nil
  return true
end

-- Drop the oldest lines until the list fits the chosen size. Pinned lines are
-- never dropped: keeping a line is exactly what pinning it means.
local function Trim()
  local guard = 0
  while Count() > CommandHistoryDB.size and guard < 500 do
    guard = guard + 1
    local n = Count()
    local victim = nil
    local i = 1
    while i <= n do
      if not Pinned(CommandHistoryDB.lines[i]) then victim = i break end
      i = i + 1
    end
    if not victim then return end          -- everything left is pinned
    RemoveAt(victim)
  end
end

-- The list as a human should see it: pinned lines first, newest first inside
-- each group, blanks gone, and the two filters applied. Every place that
-- shows history goes through here, so the panel, /cmdh list and /cmdh N
-- always number the same lines the same way.
local function DisplayList(query, max)
  local q = nil
  if type(query) == "string" and string.find(query, "%S") then
    q = string.lower(query)
  end

  local top, rest, tn, rn = {}, {}, 0, 0
  local i = Count()
  while i >= 1 do
    local line = CommandHistoryDB.lines[i]
    local keep = type(line) == "string" and string.find(line, "%S")
    if keep and not IsCommand(line) then keep = false end
    if keep and q and not string.find(string.lower(line), q, 1, true) then keep = false end
    if keep then
      local entry = { text = line, real = i, pinned = Pinned(line),
                      uses = CommandHistoryDB.uses[line] or 1 }
      if entry.pinned then
        tn = tn + 1
        top[tn] = entry
      else
        rn = rn + 1
        rest[rn] = entry
      end
    end
    i = i - 1
  end

  local out, n = {}, 0
  i = 1
  while i <= tn do n = n + 1 out[n] = top[i] i = i + 1 end
  i = 1
  while i <= rn do n = n + 1 out[n] = rest[i] i = i + 1 end

  local total = n
  if max and n > max then
    while n > max do out[n] = nil n = n - 1 end
  end
  return out, n, total
end

local function Remember(text)
  if type(text) ~= "string" then return end
  local trimmed = string.gsub(text, "^%s+", "")
  trimmed = string.gsub(trimmed, "%s+$", "")
  if trimmed == "" then return end
  if not string.find(trimmed, "%S") then return end
  -- the addon is about commands: ordinary chat is not worth remembering
  if not IsCommand(trimmed) then return end

  CommandHistoryDB.uses[trimmed] = (CommandHistoryDB.uses[trimmed] or 0) + 1

  -- typing a line again moves it back to the top instead of leaving a copy
  local n = Count()
  local i = n
  while i >= 1 do
    if CommandHistoryDB.lines[i] == trimmed then
      RemoveAt(i)
      n = n - 1
    end
    i = i - 1
  end

  CommandHistoryDB.lines[n + 1] = trimmed
  Trim()
  if UpdatePanelHook then UpdatePanelHook() end
end

-- Up and Down walk the list. Returns true when the key was used, so the
-- original handler is left alone the rest of the time.
local function Browse(box, key)
  if not CommandHistoryDB.own then return false end
  if key ~= "UP" and key ~= "DOWN" then return false end
  if not box or not box.SetText then return false end

  local n = Count()
  if n == 0 then return false end

  if key == "UP" then
    if pos == 0 then
      draft = (box.GetText and box:GetText()) or ""
    end
    if pos >= n then return true end          -- already at the oldest line
    pos = pos + 1
  else
    if pos == 0 then return false end         -- nothing to come back to
    pos = pos - 1
  end

  if pos == 0 then
    box:SetText(draft or "")
  else
    box:SetText(CommandHistoryDB.lines[n - pos + 1] or "")
  end

  if box.SetCursorPosition and box.GetNumLetters then
    box:SetCursorPosition(box:GetNumLetters())
  end
  return true
end

-- While the spy runs every key that reaches us is printed, so we can see
-- which script this client actually uses for the arrows.
local function Spy(where, key)
  if spy <= 0 then return end
  Print("|cff808080" .. where .. ":|r " .. tostring(key))
end

local function ResetWalk()
  pos, draft = 0, nil
end

----------------------------------------------------------------------
-- hooking the chat input boxes
----------------------------------------------------------------------

-- Not every script name exists on every client, and setting an unknown one
-- can raise. Everything goes through here so a refusal is just recorded.
local function SafeSetScript(box, name, fn)
  if not box.SetScript then return false end
  local ok = pcall(function() box:SetScript(name, fn) end)
  if ok then
    local got = nil
    pcall(function() got = box:GetScript(name) end)
    ok = (got ~= nil)
  end
  if ok then slots[name] = true end
  return ok
end

local function ApplyAltMode(box)
  if box.SetAltArrowKeyMode then box:SetAltArrowKeyMode(CommandHistoryDB.alt and true or false) end
end

local function HookBox(box)
  if not box or hooked[box] then return end
  if not box.SetScript or not box.GetScript then return end
  hooked[box] = true
  boxCount = boxCount + 1

  ApplyAltMode(box)

  local origEnter = box:GetScript("OnEnterPressed")
  SafeSetScript(box, "OnEnterPressed", function(self)
    self = self or this or box
    if self.GetText then
      local sent = self:GetText()
      Remember(sent)
      -- the answer to a line typed straight into chat is worth keeping too
      if OutStartHook and sent and sent ~= "" then OutStartHook(sent) end
    end
    ResetWalk()
    if origEnter then origEnter(self) end
  end)

  -- Three different ways a client can deliver an arrow key to an edit box.
  -- Whichever one this client actually uses, the first to fire wins and the
  -- others never see the key.
  local origArrow = box:GetScript("OnArrowPressed")
  SafeSetScript(box, "OnArrowPressed", function(self, key)
    self = self or this or box
    local k = key or arg1
    Spy("OnArrowPressed", k)
    if Browse(self, k) then return end
    if origArrow then origArrow(self, k) end
  end)

  local origKeyDown = box:GetScript("OnKeyDown")
  SafeSetScript(box, "OnKeyDown", function(self, key)
    self = self or this or box
    local k = key or arg1
    Spy("OnKeyDown", k)
    if Browse(self, k) then return end
    if origKeyDown then origKeyDown(self, k) end
  end)

  local origKeyUp = box:GetScript("OnKeyUp")
  SafeSetScript(box, "OnKeyUp", function(self, key)
    self = self or this or box
    Spy("OnKeyUp", key or arg1)
    if origKeyUp then origKeyUp(self, key or arg1) end
  end)

  -- Typing is watched too. If letters show up in the spy but arrows never do,
  -- the client is swallowing the arrows; if nothing shows up at all, it hands
  -- us no keys whatsoever and the whole idea is off the table.
  local origChar = box:GetScript("OnChar")
  SafeSetScript(box, "OnChar", function(self, ch)
    self = self or this or box
    Spy("OnChar", ch or arg1)
    if origChar then origChar(self, ch or arg1) end
  end)

  local origTab = box:GetScript("OnTabPressed")
  SafeSetScript(box, "OnTabPressed", function(self)
    self = self or this or box
    Spy("OnTabPressed", "TAB")
    if origTab then origTab(self) end
  end)

  local origEscape = box:GetScript("OnEscapePressed")
  SafeSetScript(box, "OnEscapePressed", function(self)
    self = self or this or box
    ResetWalk()
    if origEscape then origEscape(self) end
  end)

  local origFocus = box:GetScript("OnEditFocusGained")
  SafeSetScript(box, "OnEditFocusGained", function(self)
    self = self or this or box
    ResetWalk()
    if origFocus then origFocus(self) end
  end)
end

local function HookAll()
  if ChatFrameEditBox then HookBox(ChatFrameEditBox) end
  if getglobal then
    local i = 1
    while i <= 10 do
      HookBox(getglobal("ChatFrame" .. i .. "EditBox"))
      i = i + 1
    end
  end
end

-- Hand the saved lines to the client's own history as well, so its built in
-- browsing (if it works at all) starts out with everything we know.
local function FeedClientHistory()
  local box = ChatFrameEditBox or (getglobal and getglobal("ChatFrame1EditBox"))
  if not box or not box.AddHistoryLine then return 0 end
  local n, i = Count(), 1
  while i <= n do
    box:AddHistoryLine(CommandHistoryDB.lines[i])
    i = i + 1
  end
  return n
end
----------------------------------------------------------------------
-- the panel: history without any keys at all
----------------------------------------------------------------------

-- This client hands the chat box no keys, so the history has to be something
-- to look at and click. One click drops a line into the chat box ready to
-- send. The search field works the same way round: we never see the keys, we
-- just read what the client has already drawn into the box.

local panel, search, countText, upButton, downButton, mmButton
local panelTitle, searchLabel, panelHint, clearButton
local input, inputLabel, sendButton, inputHintFS   -- our own command line
local ShowOutHook                     -- set once the output window exists
local rowButtons, rowNumber, rowText, rowUses, rowEntry, rowIndex = {}, {}, {}, {}, {}, {}
local PANEL_ROWS = 12
local ROW_H      = 16
local offset     = 0
local lastQuery  = ""
local pollTimer  = 0

local UpdatePanel

local function EditBox()
  if ChatFrameEditBox then return ChatFrameEditBox end
  if getglobal then return getglobal("ChatFrame1EditBox") end
  return nil
end

local function PutInBox(text)
  local box = EditBox()
  if not box or not box.SetText then
    Print(L("noBox"))
    return
  end
  if box.Show then box:Show() end
  box:SetText(text)
  if box.SetFocus then box:SetFocus() end
  if box.SetCursorPosition and box.GetNumLetters then
    box:SetCursorPosition(box:GetNumLetters())
  end
end

local function SearchText()
  if not search or not search.GetText then return "" end
  return search:GetText() or ""
end

----------------------------------------------------------------------
-- what the client answered
----------------------------------------------------------------------

-- The answer to a command arrives as ordinary chat lines, so the only way to
-- keep it is to sit in front of AddMessage on every chat window and write
-- down what goes through. Lines are kept in memory only: a session's worth of
-- server output has no business growing the saved variables file.
local outBook = {}        -- command text -> the record below
local OUT_KEEP = 10       -- how many commands keep their answer
local OUT_CHARS = 400     -- longest line written down
local outWatch = nil      -- command being listened for right now
local outUntil = 0        -- until when
local outLast = nil       -- the last command that got anything
local chatHooked = {}     -- frame -> true
local OUT_WINDOW = 6      -- seconds of chat counted as the answer
local OUT_MAX = 400       -- lines kept per command

-- The answers live in the saved variables, so a /reload does not throw away
-- what the last commands said -- that was the first thing anyone noticed.
-- Bounded on three sides: ten commands, four hundred lines each, four hundred
-- characters a line.
local function OutLoad()
  outBook = {}
  local arr = CommandHistoryDB and CommandHistoryDB.out
  if type(arr) ~= "table" then
    arr = {}
    if CommandHistoryDB then CommandHistoryDB.out = arr end
  end
  local i = 1
  while arr[i] do
    local r = arr[i]
    if type(r) == "table" and r.cmd and type(r.lines) == "table" then
      outBook[r.cmd] = r
    end
    i = i + 1
  end
  outLast = CommandHistoryDB and CommandHistoryDB.outLast or nil
end

local function OutRemember(rec)
  local arr = CommandHistoryDB.out
  if type(arr) ~= "table" then arr = {}; CommandHistoryDB.out = arr end

  -- drop an older answer for the same command, then append
  local i, n = 1, 0
  while arr[i] do n = n + 1; i = i + 1 end
  local w = 1
  i = 1
  while i <= n do
    if arr[i] and arr[i].cmd ~= rec.cmd then
      arr[w] = arr[i]
      w = w + 1
    end
    i = i + 1
  end
  while arr[w] do arr[w] = nil; w = w + 1 end

  n = 0
  while arr[n + 1] do n = n + 1 end
  arr[n + 1] = rec
  n = n + 1

  -- trim the oldest away
  while n > OUT_KEEP do
    local k = 1
    while arr[k + 1] do arr[k] = arr[k + 1]; k = k + 1 end
    arr[k] = nil
    n = n - 1
  end
end

local function OutRecord(text)
  if not outWatch or speaking then return end
  if not text or text == "" then return end
  local rec = outBook[outWatch]
  if not rec then return end
  local n = 0
  while rec.lines[n + 1] do n = n + 1 end
  if n >= OUT_MAX then return end
  -- strip the colour codes: they help nobody once the text is on its way to
  -- the clipboard, and they make a copied line unreadable
  local clean = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  clean = string.gsub(clean, "|r", "")
  clean = string.gsub(clean, "|H.-|h(.-)|h", "%1")
  if string.len(clean) > OUT_CHARS then clean = string.sub(clean, 1, OUT_CHARS) .. "..." end
  rec.lines[n + 1] = clean
  if n == 0 then
    -- first line of an answer: keep it, and light the "?" beside the row at
    -- once. Without this the mark stayed dim until something else redrew the
    -- list, which looked like the answer had not been recorded at all.
    if CommandHistoryDB then OutRemember(rec) end
    if UpdatePanelHook then UpdatePanelHook() end
  end
  outLast = outWatch
  if CommandHistoryDB then CommandHistoryDB.outLast = outWatch end
end

-- Wrapping AddMessage only works if the frame will take a new field. On a
-- client where frames are protected the assignment is swallowed without an
-- error, so the result is checked rather than assumed: chatHookOk decides
-- whether anything can be caught this way at all.
-- Both ways in can be alive at once: the wrapper sees the formatted line the
-- player reads, the event carries the raw text. To keep one answer instead of
-- two, the last few event strings are remembered for half a second and a
-- chat line that contains one of them is left to the event.
local evSeen, evAt, evNext = {}, {}, 1
local EV_N = 6

local function EvNote(t)
  evSeen[evNext] = t
  evAt[evNext] = (GetTime and GetTime()) or 0
  evNext = evNext + 1
  if evNext > EV_N then evNext = 1 end
end

local function EvRecent(msg)
  if not msg then return false end
  local now = (GetTime and GetTime()) or 0
  local i = 1
  while i <= EV_N do
    local t = evSeen[i]
    if t and t ~= "" and (now - (evAt[i] or 0)) < 0.5 then
      if string.find(msg, t, 1, true) then return true end
    end
    i = i + 1
  end
  return false
end

local function HookChatFrame(f)
  if not f or chatHooked[f] or type(f.AddMessage) ~= "function" then return end
  chatHooked[f] = true
  local orig = f.AddMessage
  local wrapper = function(self, msg, r, g, b, id)
    if not EvRecent(msg) then OutRecord(msg) end
    return orig(self, msg, r, g, b, id)
  end
  f.AddMessage = wrapper
  if f.AddMessage == wrapper then chatHookOk = true end
end

local function HookChatFrames()
  if DEFAULT_CHAT_FRAME then HookChatFrame(DEFAULT_CHAT_FRAME) end
  if not getglobal then return end
  local i = 1
  while i <= 10 do
    HookChatFrame(getglobal("ChatFrame" .. i))
    i = i + 1
  end
end

OutRecordHook = OutRecord

-- The other way the client's answer arrives. Where AddMessage cannot be
-- wrapped, this is the only way: the server's own replies come as chat events
-- whatever the frame does. Addon output does not, which is why Print hands
-- its line over directly.
local CHAT_EVENTS = {
  "CHAT_MSG_SYSTEM", "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE",
  "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL_LIST",
  "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_SAY",
  "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
  "CHAT_MSG_RAID", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_EMOTE",
  "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL",
  "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_LOOT",
  "CHAT_MSG_MONEY", "CHAT_MSG_SKILL", "CHAT_MSG_TRADESKILLS",
  "CHAT_MSG_COMBAT_MISC_INFO", "CHAT_MSG_IGNORED", "CHAT_MSG_AFK",
  "CHAT_MSG_DND", "CHAT_MSG_BG_SYSTEM_NEUTRAL", "CHAT_MSG_OPENING",
}

local function OutChatEvent(ev, a1, a2)
  if not outWatch then return end
  if not a1 or a1 == "" then return end
  EvNote(a1)
  if a2 and a2 ~= "" and ev ~= "CHAT_MSG_SYSTEM" then
    OutRecord("[" .. a2 .. "] " .. a1)
  else
    OutRecord(a1)
  end
end

-- /who is answered through the who list rather than through chat on this
-- client, so it is read out of the API instead. Same for the time played
-- reply, which arrives as its own event.
local function OutWhoList()
  if not outWatch then return end
  if type(GetNumWhoResults) ~= "function" or type(GetWhoInfo) ~= "function" then return end
  local n = GetNumWhoResults()
  if not n or n < 1 then return end
  OutRecord(Lf("outWho", n))
  local i = 1
  while i <= n do
    local name, guild, level, race, class, zone = GetWhoInfo(i)
    if name then
      local line = name
      if level then line = line .. " - " .. level end
      if class then line = line .. " " .. class end
      if race then line = line .. " " .. race end
      if zone and zone ~= "" then line = line .. " - " .. zone end
      if guild and guild ~= "" then line = line .. " <" .. guild .. ">" end
      OutRecord(line)
    end
    i = i + 1
  end
end

-- Every slash command the client knows. It routes them through globals named
-- SLASH_<KEY>1..8 while the handlers live in SlashCmdList under the same key,
-- so walking that table and asking for the globals gives the whole picture.
-- /script is disabled on this client, which makes an addon the only place this
-- can be done at all.
local function CmdLines()
  if type(SlashCmdList) ~= "table" then return {}, 0, 0 end

  local keys, kn = {}, 0
  for key in pairs(SlashCmdList) do
    kn = kn + 1
    keys[kn] = key
  end
  table.sort(keys)

  local lines, ln, total = {}, 0, 0
  local i = 1
  while i <= kn do
    local key = keys[i]
    local names, nn = "", 0
    local j = 1
    while j <= 8 do
      local cmd = getglobal and getglobal("SLASH_" .. key .. j)
      if type(cmd) == "string" and cmd ~= "" then
        if nn > 0 then names = names .. "  " end
        names = names .. cmd
        nn = nn + 1
        total = total + 1
      end
      j = j + 1
    end
    if nn > 0 then
      ln = ln + 1
      lines[ln] = key .. ":  " .. names
    end
    i = i + 1
  end

  return lines, ln, total
end

-- Opens the recording window for one command. Anything printed for the next
-- few seconds belongs to it.
local function OutStart(text)
  -- Remember() trims the line before storing it, and the "?" beside a row
  -- looks the answer up by that stored text. Keying the record with the raw
  -- string left a trailing space enough to lose the answer.
  if type(text) ~= "string" then return end
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  if text == "" then return end

  outWatch = text
  outUntil = (GetTime and GetTime() or 0) + OUT_WINDOW
  local rec = { cmd = text, at = (time and time()) or 0, lines = {} }
  outBook[text] = rec
  -- not written down yet: a command that answers nothing should not take up
  -- one of the ten kept slots
  HookChatFrames()
end

OutStartHook = OutStart

local function OutStop()
  outWatch = nil
end

local function OutFor(text)
  return outBook[text]
end

-- A record with no lines in it is the same as no record: the command answered
-- nothing, so the mark beside it stays dim and the button says so.
local function OutHas(text)
  local rec = outBook[text]
  return (rec and rec.lines and rec.lines[1]) and true or false
end

----------------------------------------------------------------------
-- sending a line ourselves
----------------------------------------------------------------------

-- Our own input field has to put the line on its way without the chat box's
-- Enter key, which addons cannot press. Four ways are tried in order and the
-- first one the client actually has wins; the name of the winner is printed
-- so a failure says which door was closed.
local function SlashDispatch(line)
  if type(SlashCmdList) ~= "table" then return false end
  local _, _, word, rest = string.find(line, "^(/%S+)%s*(.*)$")
  if not word then return false end
  local lower = string.lower(word)
  for key, fn in pairs(SlashCmdList) do
    local i = 1
    while i <= 8 do
      local cmd = getglobal and getglobal("SLASH_" .. key .. i)
      if cmd and string.lower(cmd) == lower then
        fn(rest or "")
        return true
      end
      i = i + 1
    end
  end
  return false
end

local function SendLine(text)
  if not text or text == "" then
    Report(L("sendNoText"))
    return false
  end

  OutStart(text)
  Remember(text)      -- the chat box path would do this itself; the rest would not

  local box = EditBox()
  if box and box.SetText and type(ChatEdit_SendText) == "function" then
    box:SetText(text)
    ChatEdit_SendText(box, 1)
    Report(Lf("sendHow", "ChatEdit_SendText"))
    return true
  end

  if box and box.SetText and type(ChatEdit_OnEnterPressed) == "function" then
    box:SetText(text)
    local keep = this
    this = box
    ChatEdit_OnEnterPressed(box)
    this = keep
    Report(Lf("sendHow", "ChatEdit_OnEnterPressed"))
    return true
  end

  if string.sub(text, 1, 1) == "/" then
    if SlashDispatch(text) then
      Report(Lf("sendHow", "SlashCmdList"))
      return true
    end
  elseif type(SendChatMessage) == "function" then
    SendChatMessage(text, "SAY")
    Report(Lf("sendHow", "SendChatMessage"))
    return true
  end

  -- Nothing sent it for us. The line is at least put in the chat box, focused
  -- and ready, so the player only has to press Enter -- which is still better
  -- than losing what was pasted.
  OutStop()
  if box and box.SetText then
    PutInBox(text)
    Report(L("sendManual"))
    return true
  end
  Report(L("sendFail"))
  return false
end

----------------------------------------------------------------------
-- making a macro out of a line
----------------------------------------------------------------------

-- Macro names are short and have to be unique, so a long command is cut down
-- and a number is added when that name is taken.
local function MacroName(text)
  local name = string.gsub(text, "^/", "")
  name = string.gsub(name, "%s+", " ")
  name = string.sub(name, 1, 16)
  if name == "" then name = "cmd" end

  if type(GetMacroIndexByName) ~= "function" then return name end
  if GetMacroIndexByName(name) == 0 then return name end

  local i = 2
  while i <= 20 do
    local try = string.sub(name, 1, 14) .. i
    if GetMacroIndexByName(try) == 0 then return try end
    i = i + 1
  end
  return name
end

local function MakeMacro(text)
  if type(CreateMacro) ~= "function" then
    Print(L("noMacroApi"))
    return
  end
  if not IsCommand(text) then
    Print(L("macroCmd"))
    return
  end

  local name = MacroName(text)
  local index = CreateMacro(name, 1, text, nil, nil)
  if type(index) == "number" and index > 0 then
    Print(Lf("macroOk", name))
  else
    Print(L("macroFail"))
  end
end

----------------------------------------------------------------------
-- rows
----------------------------------------------------------------------

local function IndexFromName(widget, prefix, len)
  if not widget or not widget.GetName then return nil end
  local n = widget:GetName()
  if not n or string.sub(n, 1, len) ~= prefix then return nil end
  return tonumber(string.sub(n, len + 1))
end

local function RowIndexOf(widget)
  if not widget then return nil end
  return rowIndex[widget] or IndexFromName(widget, "CommandHistoryPanelRow", 22)
end

local function EntryOf(widget)
  local i = RowIndexOf(widget)
  if not i then return nil end
  return rowEntry[i], i
end

local function RowClick(self)
  local entry = EntryOf(self or this)
  if entry and entry.text ~= "" then PutInBox(entry.text) end
end

local function PinClick(self)
  local entry = EntryOf(self or this)
  if not entry then return end
  if CommandHistoryDB.pins[entry.text] then
    CommandHistoryDB.pins[entry.text] = nil
  else
    CommandHistoryDB.pins[entry.text] = true
  end
  UpdatePanel()
end

local function MacroClick(self)
  local entry = EntryOf(self or this)
  if entry then MakeMacro(entry.text) end
end

local function DeleteClick(self)
  local entry = EntryOf(self or this)
  if not entry then return end
  if RemoveAt(entry.real) then
    CommandHistoryDB.pins[entry.text] = nil
    Print(Lf("deleted", entry.text))
    UpdatePanel()
  end
end

-- The "?" beside a line opens what the client answered the last time that
-- line was sent from this window.
local function OutClick(self)
  local e = EntryOf(self or this)
  if not e then return end
  if not OutFor(e.text) then
    Report(L("outNone"))
    return
  end
  if ShowOutHook then ShowOutHook(e.text) end
end

-- Reads our own command line and sends it. GetText is the one method this
-- client does not register on the chat box; on an edit box of our own it is
-- there, and without it there would be nothing to send.
local function SendFromInput()
  if not input then return end
  if not input.GetText then
    Report(L("noRead"))
    return
  end
  local text = input:GetText() or ""
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  if text == "" then
    Report(L("sendNoText"))
    return
  end
  if SendLine(text) then
    input:SetText("")
    if UpdatePanelHook then UpdatePanelHook() end
  end
end

local function ClearAllClick()
  CommandHistoryDB.lines = {}
  CommandHistoryDB.pins = {}
  CommandHistoryDB.uses = {}
  offset = 0
  Print(L("cleared"))
  UpdatePanel()
end

-- Scrolling is done by the buttons alone. The mouse wheel never reaches an
-- addon frame on this client — the camera swallows it, the same way the chat
-- box swallows the arrow keys — so there is nothing to hook. Holding Shift
-- moves a whole page instead of one line.
local function Scroll(step)
  if IsShiftKeyDown and IsShiftKeyDown() then step = step * PANEL_ROWS end
  offset = offset + step
  UpdatePanel()
end

----------------------------------------------------------------------
-- position
----------------------------------------------------------------------

-- Kept as the absolute bottom left corner rather than an anchor pair:
-- StartMoving re-anchors a frame however it likes, and a pair read back
-- through GetPoint could land the window in a screen corner on the next
-- login. The bag window taught us that one.
local function ApplyPanelPosition()
  if not panel then return end
  panel:ClearAllPoints()
  local x, y = CommandHistoryDB.x, CommandHistoryDB.y
  if type(x) == "number" and type(y) == "number" then
    panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
  else
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  end
end

local function SavePanelPosition()
  if not panel or not panel.GetLeft then return end
  local x, y = panel:GetLeft(), panel:GetBottom()
  if type(x) == "number" and type(y) == "number" then
    CommandHistoryDB.x, CommandHistoryDB.y = x, y
    ApplyPanelPosition()
  end
end

----------------------------------------------------------------------
-- building it
----------------------------------------------------------------------

local function MakeFont(parent, size)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  if not fs:GetFont() or fs:GetFont() == "" then
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
  end
  return fs
end

local function TinyButton(name, parent, label, tipKey, handler)
  local b = CreateFrame("Button", name, parent)
  b:SetWidth(18)
  b:SetHeight(ROW_H)
  b:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  b:SetText(label)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  b:SetScript("OnClick", handler)
  b:SetScript("OnEnter", function(self)
    self = self or this
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L(tipKey))
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function BuildPanel()
  if panel then return end

  panel = CreateFrame("Frame", "CommandHistoryPanel", UIParent)
  panel:SetWidth(470)
  panel:SetHeight(74 + PANEL_ROWS * ROW_H + 74)
  panel:SetFrameStrata("DIALOG")
  panel:SetToplevel(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  EscClose("CommandHistoryPanel")

  -- two ways to start the move: the drag event is not always delivered on
  -- this client, so a plain mouse down works as well
  panel:SetScript("OnDragStart", function(self) (self or this):StartMoving() end)
  panel:SetScript("OnMouseDown", function(self, button)
    self = self or this
    local b = button or arg1
    if b and b ~= "LeftButton" then return end
    self:StartMoving()
  end)
  panel:SetScript("OnDragStop", function(self)
    self = self or this
    self:StopMovingOrSizing()
    SavePanelPosition()
  end)
  panel:SetScript("OnMouseUp", function(self)
    self = self or this
    self:StopMovingOrSizing()
    SavePanelPosition()
  end)

  panel:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if not title:GetFont() or title:GetFont() == "" then
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
  end
  title:SetPoint("TOP", panel, "TOP", 0, -16)
  panelTitle = title

  local close
  local ok = pcall(function()
    close = CreateFrame("Button", "CommandHistoryPanelClose", panel, "UIPanelCloseButton")
  end)
  if not ok or not close then
    close = CreateFrame("Button", "CommandHistoryPanelClose", panel)
    close:SetWidth(20)
    close:SetHeight(18)
    close:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
    close:SetText("|cffff6060X|r")
  end
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -8)
  close:SetScript("OnClick", function() panel:Hide() end)

  -- search: the client draws what is typed, we only read it back
  local label = MakeFont(panel, 12)
  label:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -40)
  label:SetTextColor(0.6, 0.6, 0.6)
  searchLabel = label

  search = CreateFrame("EditBox", "CommandHistoryPanelSearch", panel)
  search:SetWidth(300)
  search:SetHeight(18)
  search:SetPoint("TOPLEFT", panel, "TOPLEFT", 64, -37)
  -- the field has to take the click itself, otherwise the panel underneath
  -- grabs it and starts dragging the window instead of giving focus
  search:EnableMouse(true)
  pcall(function() search:SetFontObject(ChatFontNormal) end)
  if not search:GetFont() or search:GetFont() == "" then
    search:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  end
  search:SetTextColor(1, 1, 1)
  search:SetJustifyH("LEFT")      -- an EditBox centres its text by default
  search:SetMaxLetters(60)
  search:SetScript("OnMouseDown", function(self)
    self = self or this
    if self.SetFocus then self:SetFocus() end
  end)
  search:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  search:SetBackdropColor(0, 0, 0, 0.6)
  search:SetTextInsets(6, 6, 0, 0)
  pcall(function() search:SetAutoFocus(false) end)
  search:SetScript("OnEscapePressed", function(self)
    self = self or this
    self:SetText("")
    if self.ClearFocus then self:ClearFocus() end
  end)
  search:SetScript("OnEnterPressed", function(self)
    self = self or this
    if self.ClearFocus then self:ClearFocus() end
  end)

  local clearSearch = TinyButton("CommandHistoryPanelSearchClear", panel, "|cff808080x|r",
    "clearFind", function()
      if search then search:SetText("") end
      offset = 0
      UpdatePanel()
    end)
  clearSearch:SetPoint("LEFT", search, "RIGHT", 2, 0)

  local i = 1
  while i <= PANEL_ROWS do
    local top = -64 - (i - 1) * ROW_H

    local row = CreateFrame("Button", "CommandHistoryPanelRow" .. i, panel)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 34, top)
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -78, top)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:SetScript("OnClick", RowClick)

    -- a Button centres its own label, so the text lives in font strings of
    -- our own instead: the number right aligned in a fixed column, the line
    -- left aligned after it. That is what keeps the list even.
    local num = MakeFont(row, 12)
    num:SetPoint("LEFT", row, "LEFT", 0, 0)
    num:SetWidth(20)
    num:SetJustifyH("RIGHT")
    num:SetTextColor(0.5, 0.5, 0.5)

    local uses = MakeFont(row, 11)
    uses:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    uses:SetWidth(34)
    uses:SetJustifyH("RIGHT")
    uses:SetTextColor(0.45, 0.45, 0.45)

    local text = MakeFont(row, 12)
    text:SetPoint("LEFT", row, "LEFT", 26, 0)
    text:SetPoint("RIGHT", row, "RIGHT", -38, 0)
    text:SetJustifyH("LEFT")
    text:SetTextColor(1, 0.82, 0)

    -- each button gets a strip of its own: nothing overlaps the row, so a
    -- click can never land on the wrong thing
    local pin = TinyButton("CommandHistoryPanelPin" .. i, panel, "*",
      "tipPin", PinClick)
    pin:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, top)

    local macro = TinyButton("CommandHistoryPanelMacro" .. i, panel, "|cff808080M|r",
      "tipMacro", MacroClick)
    macro:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -36, top)

    local del = TinyButton("CommandHistoryPanelDel" .. i, panel, "|cff808080x|r",
      "tipDel", DeleteClick)
    del:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, top)

    local out = TinyButton("CommandHistoryPanelOut" .. i, panel, "|cff80c0ff?|r",
      "tipOut", OutClick)
    out:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -56, top)

    rowButtons[i] = row
    rowButtons["pin" .. i] = pin
    rowButtons["macro" .. i] = macro
    rowButtons["del" .. i] = del
    rowButtons["out" .. i] = out
    rowNumber[i] = num
    rowUses[i] = uses
    rowText[i] = text
    rowEntry[i] = nil
    rowIndex[row] = i
    rowIndex[pin] = i
    rowIndex[macro] = i
    rowIndex[del] = i
    rowIndex[out] = i
    i = i + 1
  end

  -- Our own command line. The chat box on this client takes nothing from the
  -- clipboard; an edit box of our own is the only place a paste can land, and
  -- from here the line goes out without the Enter key the chat box wants.
  inputLabel = MakeFont(panel, 12)
  inputLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 56)
  inputLabel:SetWidth(76)
  inputLabel:SetJustifyH("LEFT")
  inputLabel:SetTextColor(0.6, 0.6, 0.6)

  input = CreateFrame("EditBox", "CommandHistoryPanelInput", panel)
  input:SetHeight(18)
  input:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 96, 54)
  input:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -104, 54)
  input:EnableMouse(true)
  pcall(function() input:SetFontObject(ChatFontNormal) end)
  if not input:GetFont() or input:GetFont() == "" then
    input:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  end
  input:SetTextColor(1, 1, 1)
  input:SetJustifyH("LEFT")
  input:SetMaxLetters(255)
  input:SetTextInsets(6, 6, 0, 0)
  input:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  input:SetBackdropColor(0, 0, 0, 0.6)
  pcall(function() input:SetAutoFocus(false) end)
  input:SetScript("OnMouseDown", function(self)
    self = self or this
    if self.SetFocus then self:SetFocus() end
  end)
  input:SetScript("OnEscapePressed", function(self)
    self = self or this
    if self.ClearFocus then self:ClearFocus() end
    if panel then panel:Hide() end
  end)
  input:SetScript("OnEnterPressed", function(self)
    self = self or this
    SendFromInput()
  end)

  sendButton = CreateFrame("Button", "CommandHistoryPanelSend", panel)
  sendButton:SetWidth(84)
  sendButton:SetHeight(18)
  sendButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 54)
  sendButton:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  sendButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  sendButton:SetScript("OnClick", function() SendFromInput() end)
  sendButton:SetScript("OnEnter", function(self)
    self = self or this
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L("sendTip"))
    GameTooltip:AddLine(L("inputTip"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  sendButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  -- the paste hint gets a line of its own: it is the least obvious thing in
  -- this window and the bottom strip is already full
  inputHintFS = MakeFont(panel, 11)
  inputHintFS:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 36)
  inputHintFS:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 36)
  inputHintFS:SetJustifyH("LEFT")
  inputHintFS:SetTextColor(0.55, 0.55, 0.55)

  local clear = CreateFrame("Button", "CommandHistoryPanelClear", panel)
  clear:SetWidth(100)
  clear:SetHeight(18)
  clear:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 12)
  clear:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  -- a bare Button gets no colour of its own on this client, so its label can
  -- come out invisible: the small buttons only show because their text
  -- carries a colour code. This one gets both.
  pcall(function() clear:SetTextColor(1, 0.82, 0) end)
  clear:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  clear:SetScript("OnClick", ClearAllClick)
  clearButton = clear

  countText = MakeFont(panel, 11)
  countText:SetPoint("BOTTOM", panel, "BOTTOM", 0, 16)
  countText:SetTextColor(0.6, 0.6, 0.6)

  downButton = TinyButton("CommandHistoryPanelDown", panel, "|cff595959v|r",
    "tipDown", function() Scroll(1) end)
  downButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 12)

  upButton = TinyButton("CommandHistoryPanelUp", panel, "|cff595959^|r",
    "tipUp", function() Scroll(-1) end)
  upButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 12)

  local hint = MakeFont(panel, 11)
  hint:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -60, 16)
  hint:SetJustifyH("RIGHT")
  hint:SetTextColor(0.5, 0.5, 0.5)
  panelHint = hint

  -- the search box gives us no key events either, so its contents are simply
  -- read a few times a second and the list refreshed when they change
  panel:SetScript("OnUpdate", function(self, elapsed)
    pollTimer = pollTimer + (elapsed or arg1 or 0)
    if pollTimer < 0.2 then return end
    pollTimer = 0
    if SearchText() ~= lastQuery then
      offset = 0
      UpdatePanel()
    end
  end)

  ApplyPanelPosition()
  panel:Hide()   -- a fresh frame is visible by default
end

-- Every fixed caption is written here rather than at build time, so
-- switching the language redraws the window instead of leaving it half
-- translated until the next login.
local function ApplyPanelStrings()
  if panelTitle then panelTitle:SetText(L("title")) end
  if searchLabel then searchLabel:SetText(L("search")) end
  if panelHint then panelHint:SetText(L("hintClick")) end
  if clearButton then clearButton:SetText("|cffffd700" .. L("clearAll") .. "|r") end
  if inputLabel then inputLabel:SetText(L("inputLabel")) end
  if sendButton then sendButton:SetText("|cffffd700" .. L("send") .. "|r") end
  if inputHintFS then inputHintFS:SetText(L("inputHint")) end
end

UpdatePanel = function()
  if not panel then return end

  ApplyPanelStrings()

  lastQuery = SearchText()
  local list, shownCount, total = DisplayList(lastQuery)

  -- keep the window on a sensible page after deletions and filtering
  local maxOffset = total - PANEL_ROWS
  if maxOffset < 0 then maxOffset = 0 end
  if offset > maxOffset then offset = maxOffset end
  if offset < 0 then offset = 0 end

  local i = 1
  while i <= PANEL_ROWS do
    local entry = list[i + offset]
    local row = rowButtons[i]
    local pin = rowButtons["pin" .. i]
    local macro = rowButtons["macro" .. i]
    local del = rowButtons["del" .. i]
    local outBtn = rowButtons["out" .. i]

    if entry then
      rowEntry[i] = entry
      rowNumber[i]:SetText((i + offset) .. ".")
      rowText[i]:SetText(entry.text)
      if entry.pinned then
        rowText[i]:SetTextColor(1, 0.82, 0)
        pin:SetText("|cffffd700*|r")
      else
        rowText[i]:SetTextColor(0.85, 0.85, 0.85)
        pin:SetText("|cff595959*|r")
      end
      if entry.uses > 1 then
        rowUses[i]:SetText("x" .. entry.uses)
      else
        rowUses[i]:SetText("")
      end
      if IsCommand(entry.text) then macro:Show() else macro:Hide() end
      row:Show()
      pin:Show()
      del:Show()
      if outBtn then
        -- a dim mark when nothing was recorded, a bright one when there is
        if OutHas(entry.text) then
          outBtn:SetText("|cff80c0ff?|r")
        else
          outBtn:SetText("|cff4a5a6a?|r")
        end
        outBtn:Show()
      end
    else
      rowEntry[i] = nil
      rowNumber[i]:SetText("")
      rowText[i]:SetText("")
      rowUses[i]:SetText("")
      row:Hide()
      pin:Hide()
      macro:Hide()
      del:Hide()
      if outBtn then outBtn:Hide() end
    end
    i = i + 1
  end

  if upButton then
    if offset > 0 then upButton:SetText("|cffffd700^|r") else upButton:SetText("|cff595959^|r") end
  end
  if downButton then
    if offset < maxOffset then downButton:SetText("|cffffd700v|r") else downButton:SetText("|cff595959v|r") end
  end

  if countText then
    local first = 0
    if total > 0 then first = offset + 1 end
    local last = offset + PANEL_ROWS
    if last > total then last = total end
    if total == 0 then
      countText:SetText(L("nothing"))
    else
      countText:SetText(Lf("counter", first, last, total, Count()))
    end
  end
end

function UpdatePanelHook() if UpdatePanel then UpdatePanel() end end

local function TogglePanel()
  if not panel then
    local ok, err = pcall(BuildPanel)
    if not ok or not panel then
      Print(Lf("panelFail", tostring(err)))
      return
    end
  end
  if panel:IsShown() then
    panel:Hide()
  else
    ApplyPanelPosition()
    offset = 0
    UpdatePanel()
    panel:Show()
    if search and search.SetFocus then search:SetFocus() end
  end
end

----------------------------------------------------------------------
-- the minimap button
----------------------------------------------------------------------

local function PlaceMinimapButton()
  if not mmButton or not Minimap then return end
  local angle = CommandHistoryDB.mmangle
  if type(angle) ~= "number" then angle = 200 end
  local rad = angle * math.pi / 180
  mmButton:ClearAllPoints()
  mmButton:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(rad), 80 * math.sin(rad))
end

-- math.atan2 is not on every Lua build, so the angle is worked out by hand
-- when it is missing.
local function Atan2(y, x)
  if math.atan2 then return math.atan2(y, x) end
  if x > 0 then return math.atan(y / x) end
  if x < 0 then
    if y >= 0 then return math.atan(y / x) + math.pi end
    return math.atan(y / x) - math.pi
  end
  if y > 0 then return math.pi / 2 end
  if y < 0 then return -math.pi / 2 end
  return 0
end

local function ShiftHeld()
  return IsShiftKeyDown and IsShiftKeyDown()
end

local function StopDrag(self)
  self = self or this
  if self and self.SetScript then self:SetScript("OnUpdate", nil) end
end

local function DragButton(self)
  self = self or this
  -- let go of the button the moment Shift is released, so a drag can never
  -- get stuck and send the icon chasing the cursor around the ring
  if not ShiftHeld() then StopDrag(self) return end
  if not GetCursorPosition or not Minimap.GetCenter then return end
  local mx, my = Minimap:GetCenter()
  if not mx then return end
  local scale = 1
  if Minimap.GetEffectiveScale then scale = Minimap:GetEffectiveScale() or 1 end
  if scale == 0 then scale = 1 end
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale
  CommandHistoryDB.mmangle = math.deg(Atan2(cy - my, cx - mx))
  PlaceMinimapButton()
end

local function BuildMinimapButton()
  if mmButton or not Minimap then return end

  mmButton = CreateFrame("Button", "CommandHistoryMinimapButton", Minimap)
  mmButton:SetWidth(31)
  mmButton:SetHeight(31)
  mmButton:SetFrameStrata("MEDIUM")
  mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mmButton:RegisterForDrag("LeftButton")

  local icon = mmButton:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Scroll_03")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("CENTER", mmButton, "CENTER", 0, 1)

  local border = mmButton:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetWidth(53)
  border:SetHeight(53)
  border:SetPoint("TOPLEFT", mmButton, "TOPLEFT", 0, 0)

  mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  mmButton:SetScript("OnClick", function(self, button)
    local btn = button or arg1
    if btn == "RightButton" then
      CommandHistoryDB.minimap = false
      mmButton:Hide()
      Print(L("mmGone"))
      return
    end
    TogglePanel()
  end)

  -- moving the icon takes Shift as well as the mouse button: without that
  -- every ordinary click-and-twitch dragged it somewhere new
  mmButton:SetScript("OnDragStart", function(self)
    self = self or this
    if not ShiftHeld() then return end
    self:SetScript("OnUpdate", DragButton)
  end)
  mmButton:SetScript("OnDragStop", StopDrag)
  mmButton:SetScript("OnMouseUp", StopDrag)
  mmButton:SetScript("OnHide", StopDrag)

  mmButton:SetScript("OnEnter", function(self)
    self = self or this
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(L("title"))
    GameTooltip:AddLine("|cff9d9d9d" .. L("mmOpen") .. "|r")
    GameTooltip:AddLine("|cff9d9d9d" .. L("mmHide") .. "|r")
    GameTooltip:AddLine("|cff9d9d9d" .. L("mmMove") .. "|r")
    GameTooltip:Show()
  end)
  mmButton:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)

  PlaceMinimapButton()
end

local function ApplyMinimapButton()
  if CommandHistoryDB.minimap then
    local ok, err = pcall(BuildMinimapButton)
    if not ok then
      Print(Lf("mmFail", tostring(err)))
      return
    end
    if mmButton then PlaceMinimapButton(); mmButton:Show() end
  elseif mmButton then
    mmButton:Hide()
  end
end

----------------------------------------------------------------------
-- slash commands
----------------------------------------------------------------------

local function HandleSlash(msg)
  msg = string.lower(msg or "")
  msg = string.gsub(msg, "^%s+", "")
  msg = string.gsub(msg, "%s+$", "")

  if msg == "panel" or msg == "п" then
    TogglePanel()

  elseif string.find(msg, "^%d+$") then
    local i = tonumber(msg)
    local list = DisplayList(nil, i)
    if list[i] then PutInBox(list[i].text) else Print(L("noSuch")) end

  elseif msg == "reset" then
    CommandHistoryDB.x, CommandHistoryDB.y = nil, nil
    CommandHistoryDB.mmangle = 200
    ApplyPanelPosition()
    PlaceMinimapButton()
    Print(L("wasReset"))

  elseif msg == "minimap" then
    CommandHistoryDB.minimap = not CommandHistoryDB.minimap
    ApplyMinimapButton()
    Print(Lf("mmState", CommandHistoryDB.minimap and L("on") or L("off")))

  elseif msg == "clear" then
    CommandHistoryDB.lines = {}
    CommandHistoryDB.pins = {}
    CommandHistoryDB.uses = {}
    ResetWalk()
    if UpdatePanelHook then UpdatePanelHook() end
    Print(L("cleared"))

  elseif string.sub(msg, 1, 4) == "lang" then
    local _, _, want = string.find(msg, "^lang%s+(%a+)$")
    if want == "ru" or want == "en" or want == "auto" then
      CommandHistoryDB.lang = want
      if UpdatePanelHook then UpdatePanelHook() end
      Print(Lf("langSet", want))
    else
      Print("/cmdh lang ru | en | auto")
    end

  elseif string.sub(msg, 1, 4) == "size" then
    local _, _, n = string.find(msg, "^size%s+(%d+)$")
    n = tonumber(n)
    if n and n >= 1 and n <= 200 then
      CommandHistoryDB.size = n
      Trim()
      ResetWalk()
      Print(Lf("sizeSet", n, Count()))
    else
      Print(L("sizeErr"))
    end

  elseif msg == "alt" then
    CommandHistoryDB.alt = not CommandHistoryDB.alt
    for box in pairs(hooked) do ApplyAltMode(box) end
    Print(CommandHistoryDB.alt and L("altOn") or L("altOff"))

  elseif msg == "own" then
    CommandHistoryDB.own = not CommandHistoryDB.own
    Print(Lf("ownState", CommandHistoryDB.own and L("on") or L("ownOff")))

  elseif msg == "list" then
    local list, n = DisplayList(nil, 10)
    if n == 0 then
      Print(L("empty"))
    else
      Print(Lf("listHead", n, Count()))
      local i = 1
      while i <= n do
        local mark = list[i].pinned and "|cffffd700*|r" or " "
        local uses = ""
        if list[i].uses > 1 then uses = " |cff808080x" .. list[i].uses .. "|r" end
        DEFAULT_CHAT_FRAME:AddMessage("  " .. mark .. "|cff808080" .. i .. ".|r "
          .. list[i].text .. uses)
        i = i + 1
      end
    end

  elseif msg == "keys" then
    spy = 15
    local live, any = "", false
    for name in pairs(slots) do
      if any then live = live .. ", " end
      live = live .. name
      any = true
    end
    Print(Lf("keysLive", any and live or L("probeNone")))
    Print(L("keysAsk"))
    Print(L("keysNote"))

  elseif msg == "cmds" or msg == "commands" then
    local lines, n, total = CmdLines()
    if n == 0 then
      Report(L("cmdsNone"))
    else
      -- the list goes through the recorder, so it lands in the output window
      -- where it can be paged and copied
      local name = "/cmdh cmds"
      OutStart(name)
      local i = 1
      while i <= n do
        OutRecord(lines[i])
        i = i + 1
      end
      OutStop()
      Report(Lf("cmdsHead", n, total))
      if ShowOutHook then ShowOutHook(name) end
    end

  elseif msg == "out" then
    if outLast and OutHas(outLast) then
      Report(Lf("outLast", outLast))
      if ShowOutHook then ShowOutHook(nil) end
    else
      Report(L("outNone"))
    end

  elseif msg == "probe" then
    local box = ChatFrameEditBox or (getglobal and getglobal("ChatFrame1EditBox"))
    Print(L("probeHead"))
    Print(Lf("probeBox", tostring(box ~= nil), boxCount))
    if box then
      Print(Lf("probeApi", tostring(box.AddHistoryLine ~= nil), tostring(box.SetAltArrowKeyMode ~= nil), tostring(box.GetText ~= nil)))
      local list, any = "", false
      for name in pairs(slots) do
        if any then list = list .. ", " end
        list = list .. name
        any = true
      end
      Print(Lf("probeHook", any and list or L("probeNone")))
    end
    Print(Lf("probeLines", Count(), CommandHistoryDB.size, CommandHistoryDB.own and L("on") or L("off")))

    -- what an edit box of OUR own can do, which is a different question from
    -- what the chat box can do
    local probe = CreateFrame("EditBox", "CommandHistoryProbeBox", UIParent)
    probe:Hide()
    Print(Lf("probeEdit",
      tostring(probe.GetText ~= nil), tostring(probe.GetNumLetters ~= nil),
      tostring(probe.Insert ~= nil), tostring(probe.SetMultiLine ~= nil),
      tostring(probe.HighlightText ~= nil)))
    local inList = false
    if type(UISpecialFrames) == "table" then
      local k = 1
      while UISpecialFrames[k] do
        if UISpecialFrames[k] == "CommandHistoryPanel" then inList = true end
        k = k + 1
      end
    end
    Report(Lf("probeEsc", tostring(type(UISpecialFrames) == "table"),
      tostring(inList), tostring(origGameMenu ~= nil)))

    local cmds, allLines = 0, 0
    for _, r in pairs(outBook) do
      cmds = cmds + 1
      local k = 1
      while r.lines and r.lines[k] do allLines = allLines + 1; k = k + 1 end
    end
    Report(Lf("probeOut", cmds, allLines, tostring(outWatch ~= nil)))
    Report(Lf("probeCatch", tostring(chatHookOk), tostring(chatEventCount)))

    local letters = "?"
    if input and input.GetNumLetters then letters = tostring(input:GetNumLetters()) end
    Print(Lf("probePaste", letters))

  else
    Print(L("help"))
  end
end

----------------------------------------------------------------------
-- the output window
----------------------------------------------------------------------

-- The text lives in a multi-line EditBox because that is the only widget on
-- this client a player can select from and copy with Ctrl+C: HighlightText is
-- not registered here, so selecting cannot be done for them. Paging is ours
-- rather than a ScrollFrame's -- we own the text, so showing a window of
-- lines is both simpler and predictable.
local outFrame, outPane, outTitleFS, outHintFS, outCmdFS, outCountFS
local outLine = {}        -- i -> one line of the answer, its own edit box, outEmptyFS
local outUpBtn, outDownBtn, outFullBtn, outCloseBtn, outClearBtn
local outShown = nil      -- command the window is showing
local outOffset = 0
local outFullMode = false
local OUT_ROWS_SMALL = 14
local OUT_ROWS_FULL = 34
local UpdateOut

-- How many lines fit right now. A fixed 34 left a third of a full screen
-- window empty, so the number is taken from the height the field actually has:
-- the field spans from 56 below the top to 58 above the bottom, and a line of
-- this font takes about 15.
local OUT_LINE_H = 15

local function OutRows()
  local fixed = outFullMode and OUT_ROWS_FULL or OUT_ROWS_SMALL
  if not outFrame or not outFrame.GetHeight then return fixed end
  local h = outFrame:GetHeight()
  if type(h) ~= "number" or h <= 0 then return fixed end
  local n = math.floor((h - 122) / OUT_LINE_H)
  if n < 5 then n = 5 elseif n > 120 then n = 120 end
  return n
end

local function OutApplySize()
  if not outFrame then return end
  if outFullMode then
    outFrame:ClearAllPoints()
    outFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    outFrame:SetWidth(UIParent:GetWidth() - 80)
    outFrame:SetHeight(UIParent:GetHeight() - 80)
    if outFullBtn then outFullBtn:SetText("|cffffd700" .. L("outSmall") .. "|r") end
  else
    outFrame:ClearAllPoints()
    outFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    outFrame:SetWidth(600)
    outFrame:SetHeight(122 + OUT_ROWS_SMALL * OUT_LINE_H)
    if outFullBtn then outFullBtn:SetText("|cffffd700" .. L("outFull") .. "|r") end
  end
end

-- Forgetting an answer has to reach both the lookup and the saved array, or
-- the record comes back on the next login.
local function OutForget(cmd)
  if not cmd then return 0 end
  outBook[cmd] = nil
  local arr = CommandHistoryDB and CommandHistoryDB.out
  if type(arr) ~= "table" then return 1 end
  local n, i = 0, 1
  while arr[i] do n = n + 1; i = i + 1 end
  local w = 1
  i = 1
  while i <= n do
    if arr[i] and arr[i].cmd ~= cmd then
      arr[w] = arr[i]
      w = w + 1
    end
    i = i + 1
  end
  while arr[w] do arr[w] = nil; w = w + 1 end
  if outLast == cmd then
    outLast = nil
    if CommandHistoryDB then CommandHistoryDB.outLast = nil end
  end
  return 1
end

local function OutForgetAll()
  local n = 0
  for _ in pairs(outBook) do n = n + 1 end
  outBook = {}
  outWatch = nil
  outLast = nil
  if CommandHistoryDB then
    CommandHistoryDB.out = {}
    CommandHistoryDB.outLast = nil
  end
  return n
end

-- A line of the answer. It is an EditBox rather than a FontString because
-- only an edit box can be selected with the mouse and copied with Ctrl+C.
local function OutLine(i)
  if outLine[i] then return outLine[i] end
  local e = CreateFrame("EditBox", "CommandHistoryOutLine" .. i, outPane)
  e:SetHeight(OUT_LINE_H)
  e:SetPoint("TOPLEFT", outPane, "TOPLEFT", 6, -4 - (i - 1) * OUT_LINE_H)
  e:SetPoint("TOPRIGHT", outPane, "TOPRIGHT", -6, -4 - (i - 1) * OUT_LINE_H)
  e:EnableMouse(true)
  pcall(function() e:SetAutoFocus(false) end)
  pcall(function() e:SetFontObject(ChatFontNormal) end)
  if not e:GetFont() or e:GetFont() == "" then
    e:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
  end
  e:SetTextColor(0.9, 0.9, 0.9)
  e:SetJustifyH("LEFT")
  e:SetTextInsets(2, 2, 0, 0)
  e:SetScript("OnMouseDown", function(self)
    self = self or this
    if self.SetFocus then self:SetFocus() end
  end)
  e:SetScript("OnEscapePressed", function(self)
    self = self or this
    if self.ClearFocus then self:ClearFocus() end
    if outFrame then outFrame:Hide() end
  end)
  e:SetScript("OnEnterPressed", function(self)
    self = self or this
    if self.ClearFocus then self:ClearFocus() end
  end)
  outLine[i] = e
  return e
end

local function BuildOut()
  if outFrame then return end

  outFrame = CreateFrame("Frame", "CommandHistoryOut", UIParent)
  outFrame:SetFrameStrata("DIALOG")
  outFrame:SetToplevel(true)
  outFrame:SetMovable(true)
  outFrame:EnableMouse(true)
  outFrame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  outFrame:Hide()
  EscClose("CommandHistoryOut")

  local moving = false
  outFrame:SetScript("OnMouseDown", function(self)
    self = self or this
    if outFullMode then return end          -- nothing to drag when it fills the screen
    if not moving then moving = true; self:StartMoving() end
  end)
  outFrame:SetScript("OnMouseUp", function(self)
    self = self or this
    if moving then moving = false; self:StopMovingOrSizing() end
  end)

  outTitleFS = outFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if not outTitleFS:GetFont() or outTitleFS:GetFont() == "" then
    outTitleFS:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
  end
  outTitleFS:SetPoint("TOP", outFrame, "TOP", 0, -16)

  outCmdFS = MakeFont(outFrame, 12)
  outCmdFS:SetPoint("TOPLEFT", outFrame, "TOPLEFT", 18, -38)
  outCmdFS:SetPoint("TOPRIGHT", outFrame, "TOPRIGHT", -18, -38)
  outCmdFS:SetJustifyH("LEFT")
  outCmdFS:SetTextColor(1, 0.82, 0)

  -- One EditBox per line instead of a single multi-line one. Selecting across
  -- lines does not work on this client -- only the first line of a multi-line
  -- box can be picked up -- so every line gets a box of its own and any of
  -- them can be selected and copied.
  outPane = CreateFrame("Frame", "CommandHistoryOutPane", outFrame)
  outPane:SetPoint("TOPLEFT", outFrame, "TOPLEFT", 18, -56)
  outPane:SetPoint("BOTTOMRIGHT", outFrame, "BOTTOMRIGHT", -18, 58)
  outPane:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  outPane:SetBackdropColor(0, 0, 0, 0.7)

  -- The "nothing recorded" notice is a label OVER the field, not text inside
  -- it: text inside would be copied along with the answer, and it is not part
  -- of the answer.
  outEmptyFS = MakeFont(outFrame, 12)
  outEmptyFS:SetPoint("TOPLEFT", outPane, "TOPLEFT", 8, -8)
  outEmptyFS:SetPoint("TOPRIGHT", outPane, "TOPRIGHT", -8, -8)
  outEmptyFS:SetJustifyH("LEFT")
  outEmptyFS:SetTextColor(0.5, 0.5, 0.5)
  outEmptyFS:Hide()

  outHintFS = MakeFont(outFrame, 11)
  outHintFS:SetPoint("BOTTOMLEFT", outFrame, "BOTTOMLEFT", 18, 40)
  outHintFS:SetWidth(420)
  outHintFS:SetJustifyH("LEFT")
  outHintFS:SetTextColor(0.55, 0.55, 0.55)

  outCountFS = MakeFont(outFrame, 11)
  outCountFS:SetPoint("BOTTOMRIGHT", outFrame, "BOTTOMRIGHT", -18, 40)
  outCountFS:SetWidth(180)
  outCountFS:SetJustifyH("RIGHT")
  outCountFS:SetTextColor(0.55, 0.55, 0.55)

  -- One strip along the bottom, right to left, with a gap between every
  -- pair: the wide "full screen" button used to be anchored over the arrows.
  local function WideButton(name, width, right, handler)
    local b = CreateFrame("Button", name, outFrame)
    b:SetWidth(width)
    b:SetHeight(18)
    b:SetPoint("BOTTOMRIGHT", outFrame, "BOTTOMRIGHT", right, 12)
    b:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    b:SetScript("OnClick", handler)
    return b
  end

  outCloseBtn = WideButton("CommandHistoryOutClose", 70, -16, function() outFrame:Hide() end)

  outFullBtn = WideButton("CommandHistoryOutFull", 112, -94, function()
    outFullMode = not outFullMode
    outOffset = 0
    OutApplySize()
    UpdateOut()
  end)

  outClearBtn = WideButton("CommandHistoryOutClear", 100, -214, function()
    if IsShiftKeyDown and IsShiftKeyDown() then
      local n = OutForgetAll()
      Report(Lf("outClearedAll", n))
    else
      if not outShown then return end
      local cmd = outShown
      OutForget(cmd)
      Report(Lf("outCleared", cmd))
    end
    outOffset = 0
    UpdateOut()
    if UpdatePanelHook then UpdatePanelHook() end
  end)
  outClearBtn:SetScript("OnEnter", function(self)
    self = self or this
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L("outClearTip"))
    GameTooltip:Show()
  end)
  outClearBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  -- the paging arrows live in the left corner: the right half of the strip is
  -- full of wide buttons and they were sitting on top of each other
  outUpBtn = TinyButton("CommandHistoryOutUp", outFrame, "|cffffd700^|r", "tipUp",
    function() outOffset = outOffset - OutRows(); UpdateOut() end)
  outUpBtn:SetPoint("BOTTOMLEFT", outFrame, "BOTTOMLEFT", 18, 12)

  outDownBtn = TinyButton("CommandHistoryOutDown", outFrame, "|cffffd700v|r", "tipDown",
    function() outOffset = outOffset + OutRows(); UpdateOut() end)
  outDownBtn:SetPoint("BOTTOMLEFT", outFrame, "BOTTOMLEFT", 38, 12)

  OutApplySize()
end

UpdateOut = function()
  if not outFrame then return end

  outTitleFS:SetText(L("outTitle"))
  outHintFS:SetText(L("outHint"))
  outCloseBtn:SetText("|cffffd700" .. L("outClose") .. "|r")
  outClearBtn:SetText("|cffffd700" .. L("outClear") .. "|r")
  outFullBtn:SetText("|cffffd700" .. (outFullMode and L("outSmall") or L("outFull")) .. "|r")

  local cmd = outShown
  outCmdFS:SetText(cmd and Lf("outFor", cmd) or "")

  local rec = cmd and OutFor(cmd)
  local lines = rec and rec.lines or {}
  local total = 0
  while lines[total + 1] do total = total + 1 end

  local rows = OutRows()

  local maxOffset = total - rows
  if maxOffset < 0 then maxOffset = 0 end
  if outOffset > maxOffset then outOffset = maxOffset end
  if outOffset < 0 then outOffset = 0 end

  local function hideFrom(k)
    while outLine[k] do outLine[k]:Hide(); k = k + 1 end
  end

  if total == 0 then
    hideFrom(1)
    if outEmptyFS then
      outEmptyFS:SetText(L("outEmpty"))
      outEmptyFS:Show()
    end
    outCountFS:SetText("")
    return
  end
  if outEmptyFS then outEmptyFS:Hide() end

  local i = 1
  while i <= rows do
    local ln = lines[i + outOffset]
    if not ln then break end
    local e = OutLine(i)
    e:SetText(ln)
    e:Show()
    i = i + 1
  end
  hideFrom(i)
  outCountFS:SetText(Lf("outLines", outOffset + 1, outOffset + i - 1, total))
end

local function ShowOut(cmd)
  BuildOut()
  outShown = cmd or outLast
  outOffset = 0
  OutApplySize()
  UpdateOut()
  outFrame:Show()
end

ShowOutHook = ShowOut

-- UISpecialFrames is the polite way and it is registered above, but it only
-- works if the client's own Escape handler walks that list. This is the belt
-- to that braces: Escape with nothing else to do ends in ToggleGameMenu, so a
-- window of ours standing open takes the key first. Nothing about the
-- keyboard is captured, so movement keys are untouched.
local function InstallEscHook()
  if origGameMenu or type(ToggleGameMenu) ~= "function" then return end
  origGameMenu = ToggleGameMenu
  ToggleGameMenu = function()
    -- the game menu itself wins: Escape has to be able to close it
    if GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown() then
      return origGameMenu()
    end
    if outFrame and outFrame:IsShown() then
      outFrame:Hide()
      return
    end
    if panel and panel:IsShown() then
      panel:Hide()
      return
    end
    return origGameMenu()
  end
end

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------

local function OnEvent(self, ev)
  ev = ev or event

  if ev and string.sub(ev, 1, 9) == "CHAT_MSG_" then
    OutChatEvent(ev, arg1, arg2)
    return
  end

  if ev == "WHO_LIST_UPDATE" then
    OutWhoList()
    return
  end

  if ev == "VARIABLES_LOADED" or ev == "PLAYER_LOGIN" then
    InitDB()
    OutLoad()
    HookChatFrames()
    HookAll()
    FeedClientHistory()
    ApplyMinimapButton()
    InstallEscHook()
    return
  end

  if ev == "PLAYER_ENTERING_WORLD" then
    InitDB()
    HookAll()          -- some chat frames appear late
    ApplyMinimapButton()
    InstallEscHook()
    return
  end
end

InitDB()

driver = CreateFrame("Frame", "CommandHistoryDriver")
driver:SetScript("OnEvent", OnEvent)
driver:SetScript("OnUpdate", function(self, elapsed)
  local e = elapsed or arg1 or 0

  -- stop listening a few seconds after the command went out, or every later
  -- line of chat would be filed under it
  if outWatch and GetTime and GetTime() > outUntil then
    OutStop()
    if UpdatePanelHook then UpdatePanelHook() end
  end

  if spy > 0 then
    spy = spy - e
    if spy <= 0 then
      spy = 0
      Print(L("keysDone"))
    end
  end
end)
local ce, ceOk = 1, 0
while CHAT_EVENTS[ce] do
  -- an event name this client does not know must not stop the rest
  local name = CHAT_EVENTS[ce]
  if pcall(function() driver:RegisterEvent(name) end) then ceOk = ceOk + 1 end
  ce = ce + 1
end
chatEventCount = ceOk

pcall(function() driver:RegisterEvent("WHO_LIST_UPDATE") end)
driver:RegisterEvent("VARIABLES_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")

SLASH_COMMANDHISTORY1 = "/commandhistory"
SLASH_COMMANDHISTORY2 = "/cmdh"
SLASH_COMMANDHISTORY3 = "/chh"
SlashCmdList["COMMANDHISTORY"] = HandleSlash
