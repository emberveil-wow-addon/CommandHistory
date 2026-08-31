# CommandHistory

Аддон для World of Warcraft 1.12.1 (сервер [Emberveil](https://emberveil.org)).

Поле ввода чата на этом клиенте не отдаёт аддонам клавиши: ни стрелки, ни
буквы. Поэтому привычной истории по стрелке вверх сделать нельзя — и аддон
заменяет её списком, который можно посмотреть и щёлкнуть.

![версия](https://img.shields.io/badge/version-0.2.1-blue) ![клиент](https://img.shields.io/badge/client-1.12.1-orange)

## Что умеет

- Запоминает набранные команды (строки, начинающиеся со слэша) и хранит их
  между сессиями.
- Окно со списком: щелчок по строке подставляет команду в поле ввода —
  остаётся нажать Enter.
- **Поиск** по истории прямо в окне.
- **Закрепление** строк: закреплённые всегда сверху и никогда не вытесняются
  лимитом.
- **Счётчик повторов**: одна и та же команда не плодит копии, а поднимается
  наверх с пометкой `x3`.
- **Макрос в одно нажатие**: кнопка `M` превращает команду в макрос, который
  можно перетащить на панель действий и повесить на клавишу.
- Удаление одной строки крестиком и полная очистка списка.
- Кнопка у миникарты: левый клик — открыть список, правый — убрать кнопку,
  Shift+перетаскивание — переместить по кругу.
- **Своя строка ввода** внизу окна: принимает вставку из буфера по **Ctrl+V**,
  чего штатное поле чата на этом клиенте не умеет. Enter или кнопка
  «Отправить» отправляют строку и кладут её в историю.
- **Окно ответа**: кнопка `?` у строки показывает, что клиент ответил на эту
  команду в последний раз. Каждая строка ответа — отдельное поле: щёлкните её,
  выделите и скопируйте по Ctrl+C. Окно разворачивается на весь экран и тогда
  показывает столько строк, сколько влезает; листается стрелками; «Очистить»
  забывает ответ, с Shift — все записанные. Ответы хранятся между сессиями:
  последние 10 команд, до 400 строк на команду.
- **`/cmdh cmds`** — команды всех аддонов и клиента: по строке на обработчик со
  всеми его псевдонимами, в том же окне ответа, откуда список можно листать и
  копировать. На этом клиенте `/script` отключён, так что иначе этот список
  никак не получить.
- Окна закрываются по **Esc**.
- Русский и английский интерфейс, определяется по локали клиента.

## Установка

1. Скачайте архив из [релизов](../../releases).
2. Распакуйте папку `CommandHistory` в `Interface/AddOns`.
3. Путь должен получиться такой: `Interface/AddOns/CommandHistory/CommandHistory.toc`

## Команды

| Команда | Что делает |
| --- | --- |
| `/cmdh panel` | открыть или закрыть окно со списком |
| `/cmdh 2` | подставить вторую строку в поле ввода |
| `/cmdh list` | показать последние строки в чате |
| `/cmdh minimap` | показать или убрать кнопку у миникарты |
| `/cmdh reset` | вернуть окно и кнопку на места по умолчанию |
| `/cmdh size 50` | сколько строк хранить (по умолчанию 30) |
| `/cmdh clear` | очистить историю |
| `/cmdh lang ru\|en\|auto` | язык интерфейса |
| `/cmdh out` | окно ответа на последнюю команду |
| `/cmdh cmds` | команды всех аддонов списком |
| `/cmdh probe` | самодиагностика |
| `/cmdh keys` | 15 секунд печатать, какие клавиши доходят до аддона |

Полное имя команды — `/commandhistory`, короткие — `/cmdh` и `/chh`.

## Особенности клиента

Полезно знать, если будете делать своё:

- поле ввода чата не вызывает у аддонов ни `OnArrowPressed`, ни `OnKeyDown`,
  ни `OnChar` — работает только `OnEnterPressed`;
- колесо мыши над окном аддона забирает камера;
- вставка картинок в текст (`|T...|t`) не отображается: маркеры съедаются,
  путь печатается как обычный текст;
- обычная кнопка без шаблона не получает цвета текста — надпись без цветового
  кода может оказаться невидимой;
- **`Ctrl+V` работает в своём `EditBox`, но не в штатном поле чата.** У
  `ChatFrameEditBox` на этом клиенте не зарегистрированы `GetText`,
  `GetCursorPosition`, `HighlightText` и `GetTextInsets` — это урезанный
  экземпляр виджета, обычный `CreateFrame("EditBox")` полноценный;
- апи буфера обмена в Lua нет вовсе: ни прочитать, ни записать. Поэтому свои
  горячие клавиши вставки или копирования добавить нельзя — их обрабатывает
  сам клиент внутри виджета;
- `HighlightText` отсутствует и у своих `EditBox`, так что выделить текст за
  игрока нечем — только мышью;
- **обёртка над `frame.AddMessage` не встаёт**: присваивание нового поля фрейму
  молча не применяется. Ответ сервера ловится подпиской на события `CHAT_MSG_*`,
  а вывод `/who` — вообще через `WHO_LIST_UPDATE` и `GetWhoInfo`;
- **`/script` и `/run` отключены** — строка просто уходит в чат как обычное
  сообщение. Всё, что нужно посмотреть или посчитать, приходится делать внутри
  аддона;
- **в многострочном `EditBox` мышью выделяется только первая строка**, ни строка
  ниже, ни несколько подряд. Поэтому в окне ответа каждая строка — своё
  однострочное поле.

---

# CommandHistory (English)

An addon for World of Warcraft 1.12.1 on the [Emberveil](https://emberveil.org)
server.

The chat input box on this client hands addons no keys at all — neither the
arrows nor the letters. The usual Up-arrow history is therefore impossible, so
this addon replaces it with a list you can look at and click.

## Features

- Remembers the commands you type (lines starting with a slash) and keeps them
  between sessions.
- A window with the list: click a line to put it back in the chat box, then
  press Enter.
- **Search** through the history inside the window.
- **Pinning**: pinned lines stay on top and are never dropped by the size
  limit.
- **Use counts**: typing the same command again moves it back to the top with
  an `x3` mark instead of leaving a copy.
- **One click to a macro**: the `M` button turns a command into a macro you can
  drag onto an action bar and bind to a key.
- Delete a single line with the cross, or clear the whole list.
- A minimap button: left click opens the list, right click hides the button,
  Shift+drag moves it around the ring.
- **Its own input line** at the bottom of the window: it takes a paste from the
  clipboard with **Ctrl+V**, which the stock chat box on this client cannot do.
  Enter or the Send button puts the line on its way and into the history.
- **Output window**: the `?` beside a line shows what the client answered that
  command last time. Every line of the answer is a field of its own: click it,
  select it and copy with Ctrl+C. The window can fill the screen and then shows
  as many lines as fit; the arrows page through it; Clear forgets the answer,
  and with Shift every recorded answer. Answers are kept between sessions: the
  last 10 commands, up to 400 lines each.
- **`/cmdh cmds`** lists the commands of every addon and of the client itself,
  one line per handler with all its aliases, in the same output window. This
  client has `/script` disabled, so there is no other way to get that list.
- The windows close on **Esc**.
- Russian and English, picked from the client locale.

## Installation

1. Download the archive from [releases](../../releases).
2. Unpack the `CommandHistory` folder into `Interface/AddOns`.
3. The result should be `Interface/AddOns/CommandHistory/CommandHistory.toc`

## Commands

`/commandhistory`, or the short `/cmdh` and `/chh`:
`panel`, `N`, `out`, `cmds`, `list`, `minimap`, `reset`, `size N`, `clear`,
`lang ru|en|auto`, `probe`, `keys`.

## Licence

MIT — see [LICENSE](LICENSE).
