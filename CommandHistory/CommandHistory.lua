--[[--------------------------------------------------------------------
  CommandHistory 0.1.0
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
local VERSION = "0.1.0"

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
    hintClick  = "клик по строке — в поле ввода",
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
    help       = "команды: /commandhistory [panel | N | minimap | reset | list | clear | size N | lang ru/en/auto | alt | own | keys | probe]",
    on         = "вкл",
    off        = "выкл",
  },
  en = {
    title      = "Command history",
    search     = "Search:",
    searchTip  = "click the search field and type",
    clearFind  = "Clear the search",
    tipUp      = "Up one line, Shift for a whole page",
    tipDown    = "Down one line, Shift for a whole page",
    clearAll   = "Clear all",
    hintClick  = "click — put in the chat box",
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
    help       = "commands: /commandhistory [panel | N | minimap | reset | list | clear | size N | lang ru/en/auto | alt | own | keys | probe]",
    on         = "on",
    off        = "off",
  },
}

local function CurrentLang()
  local pick = CommandHistoryDB and CommandHistoryDB.lang or "auto"
  if pick == "ru" or pick == "en" then return pick end
  if GetLocale and GetLocale() == "ruRU" then return "ru" end
  return "en"
end

local function L(key) return STRINGS[CurrentLang()][key] or key end
local function Lf(key, a, b, c, d) return string.format(L(key), a, b, c, d) end

----------------------------------------------------------------------
-- state
----------------------------------------------------------------------

local hooked  = {}        -- box -> true
local slots   = {}        -- script name -> true when the client accepted it
local spy     = 0         -- seconds left of the key spy
local boxCount = 0
local pos, draft = 0, nil -- how far back we are, and the unsent line
local driver

local function Print(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66" .. ADDON .. ":|r " .. msg)
  end
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
    if self.GetText then Remember(self:GetText()) end
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
  panel:SetHeight(74 + PANEL_ROWS * ROW_H + 30)
  panel:SetFrameStrata("DIALOG")
  panel:SetToplevel(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")

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
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -58, top)
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

    rowButtons[i] = row
    rowButtons["pin" .. i] = pin
    rowButtons["macro" .. i] = macro
    rowButtons["del" .. i] = del
    rowNumber[i] = num
    rowUses[i] = uses
    rowText[i] = text
    rowEntry[i] = nil
    rowIndex[row] = i
    rowIndex[pin] = i
    rowIndex[macro] = i
    rowIndex[del] = i
    i = i + 1
  end

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
    else
      rowEntry[i] = nil
      rowNumber[i]:SetText("")
      rowText[i]:SetText("")
      rowUses[i]:SetText("")
      row:Hide()
      pin:Hide()
      macro:Hide()
      del:Hide()
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

  else
    Print(L("help"))
  end
end

----------------------------------------------------------------------
-- events
----------------------------------------------------------------------

local function OnEvent(self, ev)
  ev = ev or event

  if ev == "VARIABLES_LOADED" or ev == "PLAYER_LOGIN" then
    InitDB()
    HookAll()
    FeedClientHistory()
    ApplyMinimapButton()
    return
  end

  if ev == "PLAYER_ENTERING_WORLD" then
    InitDB()
    HookAll()          -- some chat frames appear late
    ApplyMinimapButton()
    return
  end
end

InitDB()

driver = CreateFrame("Frame", "CommandHistoryDriver")
driver:SetScript("OnEvent", OnEvent)
driver:SetScript("OnUpdate", function(self, elapsed)
  local e = elapsed or arg1 or 0
  if spy > 0 then
    spy = spy - e
    if spy <= 0 then
      spy = 0
      Print(L("keysDone"))
    end
  end
end)
driver:RegisterEvent("VARIABLES_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")

SLASH_COMMANDHISTORY1 = "/commandhistory"
SLASH_COMMANDHISTORY2 = "/cmdh"
SLASH_COMMANDHISTORY3 = "/chh"
SlashCmdList["COMMANDHISTORY"] = HandleSlash
