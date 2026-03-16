-- devstudio.lua
-- GooCraft DevStudio - Fully click-driven editor on the TOP monitor
-- No conflicting keybinds - everything is a clickable button
-- Arrow keys / typing still work in the editor area ONLY

local STATE_FILE = "/.goocraft_state"
local SITES_FILE = "/.goocraft_sites"
local SITES_DIR  = "/goocraft_sites/"

if not fs.exists(SITES_DIR) then fs.makeDir(SITES_DIR) end

-- ============================================================
--  FIND MONITOR
-- ============================================================
local mon = nil
for _, side in ipairs({"top","back","left","right","front","bottom"}) do
  if peripheral.isPresent(side) and peripheral.getType(side) == "monitor" then
    mon = peripheral.wrap(side)
    break
  end
end
if not mon then mon = peripheral.find("monitor") end
if not mon then
  print("DevStudio needs a monitor attached!")
  print("Attach a monitor and restart.")
  return
end

mon.setTextScale(0.5)
local W, H = mon.getSize()

-- ============================================================
--  COLOURS
-- ============================================================
local C = {
  bg         = colours.black,
  topBar     = colours.grey,
  topText    = colours.white,
  editor     = colours.black,
  editorText = colours.white,
  lineNum    = colours.grey,
  cursorBg   = colours.blue,
  accent     = colours.cyan,
  green      = colours.green,
  red        = colours.red,
  yellow     = colours.yellow,
  orange     = colours.orange,
  subtle     = colours.lightGrey,
  btnBg      = colours.lightGrey,
  btnFg      = colours.black,
  logo       = { colours.blue, colours.red, colours.yellow, colours.blue,
                 colours.blue, colours.green, colours.red, colours.yellow },
  syn_kw     = colours.yellow,
  syn_str    = colours.green,
  syn_com    = colours.lightGrey,
  syn_tag    = colours.cyan,
  syn_num    = colours.magenta,
}

-- ============================================================
--  MONITOR DRAW HELPERS
-- ============================================================
local function mAt(x, y, text, fg, bg)
  if y < 1 or y > H or x < 1 then return end
  mon.setCursorPos(x, y)
  if fg then mon.setTextColor(fg) end
  if bg then mon.setBackgroundColor(bg) end
  local avail = W - x + 1
  if avail <= 0 then return end
  mon.write(text:sub(1, avail))
end

local function mFill(x, y, fw, fh, bg)
  mon.setBackgroundColor(bg)
  for row = y, y + fh - 1 do
    if row >= 1 and row <= H then
      local sx = math.max(1, x)
      local aw = fw - (sx - x)
      if aw > 0 then
        mon.setCursorPos(sx, row)
        mon.write(string.rep(" ", math.min(aw, W - sx + 1)))
      end
    end
  end
end

local function mCls()
  mon.setBackgroundColor(C.bg)
  mon.clear()
end

local function trunc(s, n)
  if not s then return "" end
  if #s <= n then return s end
  return s:sub(1, n-2) .. ".."
end

-- ============================================================
--  BUTTON REGISTRY
-- ============================================================
local BUTTONS = {}

local function clearButtons() BUTTONS = {} end

local function mkBtn(x, y, label, id, bgCol, fgCol)
  local bg = bgCol or C.btnBg
  local fg = fgCol or C.btnFg
  mFill(x, y, #label, 1, bg)
  mAt(x, y, label, fg, bg)
  table.insert(BUTTONS, { x1=x, x2=x+#label-1, y1=y, y2=y, id=id })
  return x + #label
end

local function hitTest(mx, my)
  for _, b in ipairs(BUTTONS) do
    if mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2 then
      return b.id
    end
  end
  return nil
end

-- ============================================================
--  LAYOUT
-- ============================================================
local TOPBAR_Y  = 1
local TOOLBAR_Y = 2
local SIDEBAR_W = 16
local EDITOR_X  = SIDEBAR_W + 1
local EDITOR_W  = W - SIDEBAR_W
local EDITOR_Y  = 3
local EDITOR_H  = H - EDITOR_Y  -- last row = status bar
local STATUS_Y  = H

-- ============================================================
--  STATE
-- ============================================================
local function writeState(data)
  local f = fs.open(STATE_FILE, "w")
  f.write(textutils.serialise(data))
  f.close()
end

local function readSites()
  if not fs.exists(SITES_FILE) then return {} end
  local f = fs.open(SITES_FILE, "r")
  local d = textutils.unserialise(f.readAll())
  f.close()
  return d or {}
end

local function writeSites(sites)
  local f = fs.open(SITES_FILE, "w")
  f.write(textutils.serialise(sites))
  f.close()
end

local function saveSiteFile(name, content)
  local path = SITES_DIR .. name
  local f = fs.open(path, "w")
  f.write(content)
  f.close()
  return path
end

local function loadSiteFile(path)
  if not path or not fs.exists(path) then return "" end
  local f = fs.open(path, "r")
  local c = f.readAll()
  f.close()
  return c
end

-- ============================================================
--  TOPBAR
-- ============================================================
local function drawTopbar(site, modified)
  mFill(1, TOPBAR_Y, W, 1, C.topBar)
  local logo = "GooKraft"
  for i = 1, #logo do
    mAt(i, TOPBAR_Y, logo:sub(i,i), C.logo[i], C.topBar)
  end
  mAt(#logo+2, TOPBAR_Y, "DevStudio", C.orange, C.topBar)
  if site then
    local typeCol = (site.fileType == "lua") and C.orange or C.accent
    local badge = " "..(site.fileType or "html"):upper().." "
    mFill(#logo+12, TOPBAR_Y, #badge, 1, typeCol)
    mAt(#logo+12, TOPBAR_Y, badge, C.bg, typeCol)
    local nm = trunc((site.title or "Untitled")..(modified and " *" or ""), W - #logo - 16)
    mAt(#logo+12+#badge+1, TOPBAR_Y, nm, C.topText, C.topBar)
  end
end

-- ============================================================
--  TOOLBAR  (all clickable, no key shortcuts)
-- ============================================================
local function drawToolbar(context)
  mFill(1, TOOLBAR_Y, W, 1, C.btnBg)
  local x = 1
  if context == "editor" then
    x = mkBtn(x, TOOLBAR_Y, " Save ",    "save",    C.yellow, C.bg)
    x = mkBtn(x, TOOLBAR_Y, " Preview ", "preview", C.green,  C.bg)
    x = mkBtn(x, TOOLBAR_Y, " Publish ", "publish", C.accent, C.bg)
    x = mkBtn(x, TOOLBAR_Y, " Close ",   "close",   C.btnBg,  C.btnFg)
    mFill(x, TOOLBAR_Y, W-x-9, 1, C.btnBg)
    mkBtn(W-9, TOOLBAR_Y, " Browser ", "browser", C.accent, C.bg)
  elseif context == "preview" then
    mkBtn(1, TOOLBAR_Y, " << Back to Editor ", "back", C.orange, C.bg)
    mAt(23, TOOLBAR_Y, "-- PREVIEW --", C.yellow, C.btnBg)
  else
    x = mkBtn(x, TOOLBAR_Y, " + New Site ", "new", C.green, C.bg)
    mFill(x, TOOLBAR_Y, W-x-9, 1, C.btnBg)
    mkBtn(W-9, TOOLBAR_Y, " Browser ", "browser", C.accent, C.bg)
  end
end

-- ============================================================
--  STATUS BAR
-- ============================================================
local function drawStatus(msg, col)
  mFill(1, STATUS_Y, W, 1, C.topBar)
  mAt(2, STATUS_Y, trunc(msg or "", W-2), col or C.topText, C.topBar)
end

-- ============================================================
--  SIDEBAR (site list)
-- ============================================================
local function drawSidebar(sites, selectedIdx)
  mFill(1, EDITOR_Y, SIDEBAR_W, EDITOR_H, C.topBar)
  mAt(2, EDITOR_Y,   "SITES", C.accent, C.topBar)
  mAt(2, EDITOR_Y+1, string.rep("-", SIDEBAR_W-2), C.subtle, C.topBar)

  for i, site in ipairs(sites) do
    local y = EDITOR_Y + 1 + i
    if y >= STATUS_Y then break end
    local isSelected = (i == selectedIdx)
    local bg = isSelected and C.btnBg or C.topBar
    local fg = site.published and C.green or C.topText
    mFill(1, y, SIDEBAR_W, 1, bg)
    mAt(2, y, (site.published and "+" or " "), site.published and C.green or C.subtle, bg)
    mAt(3, y, trunc(site.title or "?", SIDEBAR_W-3), fg, bg)
    table.insert(BUTTONS, { x1=1, x2=SIDEBAR_W, y1=y, y2=y, id="select_"..i })
  end
end

-- ============================================================
--  SYNTAX HIGHLIGHTING
-- ============================================================
local LUA_KW = {
  ["and"]=1,["break"]=1,["do"]=1,["else"]=1,["elseif"]=1,["end"]=1,
  ["false"]=1,["for"]=1,["function"]=1,["if"]=1,["in"]=1,["local"]=1,
  ["nil"]=1,["not"]=1,["or"]=1,["repeat"]=1,["return"]=1,["then"]=1,
  ["true"]=1,["until"]=1,["while"]=1,["print"]=1,["require"]=1,
  ["pairs"]=1,["ipairs"]=1,["tostring"]=1,["tonumber"]=1,["type"]=1,
  ["math"]=1,["string"]=1,["table"]=1,["os"]=1,["fs"]=1,["term"]=1,
  ["colours"]=1,["colors"]=1,["peripheral"]=1,["rednet"]=1,["shell"]=1,
}

local function renderLineHTML(x, y, line, maxW)
  mFill(x, y, maxW, 1, C.editor)
  local px = x
  local function put(txt, fg)
    if px >= x+maxW then return end
    local s = txt:sub(1, x+maxW-px)
    mAt(px, y, s, fg, C.editor)
    px = px + #s
  end
  local i = 1
  while i <= #line and px < x+maxW do
    local ch = line:sub(i,i)
    if line:sub(i,i+3) == "<!--" then
      local e = line:find("-->",i,true) or #line
      put(line:sub(i,e+2), C.syn_com); i = e+3
    elseif ch == "<" then
      local e = line:find(">",i,true) or #line
      put(line:sub(i,e), C.syn_tag); i = e+1
    elseif ch=='"' or ch=="'" then
      local q=ch; local e=line:find(q,i+1,true) or #line
      put(line:sub(i,e), C.syn_str); i=e+1
    else
      local e=line:find('[<"\']]',i) or (#line+1)
      put(line:sub(i,e-1), C.editorText); i=e
    end
  end
end

local function renderLineLua(x, y, line, maxW)
  mFill(x, y, maxW, 1, C.editor)
  local px = x
  local function put(txt, fg)
    if px >= x+maxW then return end
    local s = txt:sub(1, x+maxW-px)
    mAt(px, y, s, fg, C.editor)
    px = px + #s
  end
  local ci = line:find("%-%-",1,true)
  local i = 1
  while i <= #line and px < x+maxW do
    if ci and i >= ci then put(line:sub(i), C.syn_com); break end
    local ch = line:sub(i,i)
    if ch=='"' or ch=="'" then
      local q=ch; local j=i+1
      while j<=#line do
        if line:sub(j,j)==q and line:sub(j-1,j-1)~="\\" then break end
        j=j+1
      end
      put(line:sub(i,j), C.syn_str); i=j+1
    elseif ch:match("%d") then
      local j=i
      while j<=#line and line:sub(j,j):match("[%d%.xXa-fA-F]") do j=j+1 end
      put(line:sub(i,j-1), C.syn_num); i=j
    elseif ch:match("[%a_]") then
      local j=i
      while j<=#line and line:sub(j,j):match("[%w_]") do j=j+1 end
      local word=line:sub(i,j-1)
      put(word, LUA_KW[word] and C.syn_kw or C.editorText); i=j
    else
      put(ch, C.editorText); i=i+1
    end
  end
end

-- ============================================================
--  EDITOR MODEL
-- ============================================================
local function makeEditor(content)
  local lines = {}
  for line in (content.."\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  if #lines == 0 then lines = {""} end
  return { lines=lines, curLine=1, curCol=1, scrollTop=1, modified=false }
end

local function editorContent(ed) return table.concat(ed.lines, "\n") end

local function editorClamp(ed)
  ed.curLine = math.max(1, math.min(#ed.lines, ed.curLine))
  ed.curCol  = math.max(1, math.min(#ed.lines[ed.curLine]+1, ed.curCol))
end

local function editorScroll(ed)
  if ed.curLine < ed.scrollTop then
    ed.scrollTop = ed.curLine
  elseif ed.curLine >= ed.scrollTop + EDITOR_H - 1 then
    ed.scrollTop = ed.curLine - EDITOR_H + 2
  end
end

local function renderEditor(ed, fileType)
  local lnW  = 4
  local codeX = EDITOR_X + lnW
  local codeW = EDITOR_W - lnW

  for i = 1, EDITOR_H - 1 do
    local li = ed.scrollTop + i - 1
    local y  = EDITOR_Y + i - 1
    if y >= STATUS_Y then break end

    -- gutter
    mFill(EDITOR_X, y, lnW, 1, C.topBar)
    if li <= #ed.lines then
      mAt(EDITOR_X, y, string.format("%3d ", li), C.lineNum, C.topBar)
    end

    -- code
    if li <= #ed.lines then
      local isCur = (li == ed.curLine)
      if isCur then mFill(codeX, y, codeW, 1, colours.lightGrey) end
      if fileType == "lua" then
        renderLineLua(codeX, y, ed.lines[li], codeW)
      else
        renderLineHTML(codeX, y, ed.lines[li], codeW)
      end
      if isCur then
        local cx = codeX + ed.curCol - 1
        if cx < codeX + codeW then
          local ch = ed.lines[li]:sub(ed.curCol, ed.curCol)
          if ch == "" then ch = " " end
          mAt(cx, y, ch, C.editorText, C.cursorBg)
        end
      end
    else
      mFill(codeX, y, codeW, 1, C.editor)
      mAt(codeX, y, "~", C.subtle, C.editor)
    end
  end
end

-- Key handling: ONLY cursor movement + text editing, NO action shortcuts
local function editorKey(ed, key)
  local line = ed.lines[ed.curLine]
  if     key == keys.up       then ed.curLine = math.max(1, ed.curLine-1); editorClamp(ed)
  elseif key == keys.down     then ed.curLine = math.min(#ed.lines, ed.curLine+1); editorClamp(ed)
  elseif key == keys.left     then
    if ed.curCol > 1 then ed.curCol = ed.curCol-1
    elseif ed.curLine > 1 then ed.curLine=ed.curLine-1; ed.curCol=#ed.lines[ed.curLine]+1 end
  elseif key == keys.right    then
    if ed.curCol <= #line then ed.curCol=ed.curCol+1
    elseif ed.curLine < #ed.lines then ed.curLine=ed.curLine+1; ed.curCol=1 end
  elseif key == keys.home     then ed.curCol = 1
  elseif key == keys["end"]   then ed.curCol = #line+1
  elseif key == keys.pageUp   then ed.curLine=math.max(1,ed.curLine-EDITOR_H); editorClamp(ed)
  elseif key == keys.pageDown then ed.curLine=math.min(#ed.lines,ed.curLine+EDITOR_H); editorClamp(ed)
  elseif key == keys.enter then
    local before=line:sub(1,ed.curCol-1); local after=line:sub(ed.curCol)
    local indent=before:match("^(%s*)") or ""
    if before:match("[{:]%s*$") then indent=indent.."  " end
    ed.lines[ed.curLine]=before
    table.insert(ed.lines, ed.curLine+1, indent..after)
    ed.curLine=ed.curLine+1; ed.curCol=#indent+1; ed.modified=true
  elseif key == keys.backspace then
    if ed.curCol > 1 then
      ed.lines[ed.curLine]=line:sub(1,ed.curCol-2)..line:sub(ed.curCol)
      ed.curCol=ed.curCol-1; ed.modified=true
    elseif ed.curLine > 1 then
      local prev=ed.lines[ed.curLine-1]
      ed.curCol=#prev+1
      ed.lines[ed.curLine-1]=prev..line
      table.remove(ed.lines, ed.curLine)
      ed.curLine=ed.curLine-1; ed.modified=true
    end
  elseif key == keys.delete then
    if ed.curCol <= #line then
      ed.lines[ed.curLine]=line:sub(1,ed.curCol-1)..line:sub(ed.curCol+1); ed.modified=true
    elseif ed.curLine < #ed.lines then
      ed.lines[ed.curLine]=line..ed.lines[ed.curLine+1]
      table.remove(ed.lines, ed.curLine+1); ed.modified=true
    end
  elseif key == keys.tab then
    ed.lines[ed.curLine]=line:sub(1,ed.curCol-1).."  "..line:sub(ed.curCol)
    ed.curCol=ed.curCol+2; ed.modified=true
  end
  editorScroll(ed)
end

local function editorChar(ed, char)
  local line=ed.lines[ed.curLine]
  ed.lines[ed.curLine]=line:sub(1,ed.curCol-1)..char..line:sub(ed.curCol)
  ed.curCol=ed.curCol+1; ed.modified=true
  editorScroll(ed)
end

-- ============================================================
--  TERMINAL INPUT HELPERS (dialogs use terminal for typing)
-- ============================================================
local function tInput(label, default)
  term.setBackgroundColor(colours.black)
  term.setTextColor(colours.white)
  term.clear()
  term.setCursorPos(1,1)
  term.write(label .. ": ")
  term.setCursorBlink(true)
  local val = read(nil, nil, nil, default or "")
  term.setCursorBlink(false)
  return val
end

local function tForm(title, fields)
  local results = {}
  for i, field in ipairs(fields) do
    local prompt = "["..title.."] "..i.."/"..#fields.." - "..field[1]
    local val = tInput(prompt, field[2] or "")
    results[i] = val
  end
  return results
end

-- Confirm via monitor touch
local function mConfirm(msg)
  -- Draw confirm box on monitor
  local dw = math.min(#msg + 14, W - 4)
  local dx = math.floor((W - dw)/2) + 1
  local dy = math.floor(H/2) - 2
  mFill(dx, dy, dw, 5, C.btnBg)
  mAt(dx+1, dy,   " Confirm ", C.bg, C.red)
  mAt(dx+1, dy+1, trunc(msg, dw-2), C.bg, C.btnBg)
  mAt(dx+1, dy+2, trunc(msg:len() > dw-4 and msg:sub(dw-4) or "", dw-2), C.bg, C.btnBg)
  local yesX = dx + 2
  local noX  = dx + dw - 7
  mkBtn(yesX, dy+3, "  YES  ", "cfm_yes", C.green, C.bg)
  mkBtn(noX,  dy+3, "  NO   ", "cfm_no",  C.red,   C.bg)
  while true do
    local ev, side, mx, my = os.pullEvent("monitor_touch")
    local hit = hitTest(mx, my)
    if hit == "cfm_yes" then return true end
    if hit == "cfm_no"  then return false end
  end
end

-- ============================================================
--  PREVIEW
-- ============================================================
local function previewScreen(site, content)
  writeState({ mode="preview", currentSite=site, status="previewing" })
  mCls()
  clearButtons()
  drawTopbar(site, false)
  drawToolbar("preview")

  local y = EDITOR_Y
  if site.fileType == "lua" then
    mAt(3, y, "Lua preview (read-only code view):", C.subtle, C.bg)
    y = y + 2
    local lines = {}
    for line in (content.."\n"):gmatch("([^\n]*)\n") do table.insert(lines, line) end
    local lnW=4; local codeX=1+lnW; local codeW=W-lnW
    for i, line in ipairs(lines) do
      if y >= STATUS_Y then break end
      mFill(1, y, lnW, 1, C.topBar)
      mAt(1, y, string.format("%3d ", i), C.lineNum, C.topBar)
      renderLineLua(codeX, y, line, codeW)
      y = y+1
    end
  else
    local text = content
    text = text:gsub("<style[^>]*>.-</style>","")
    text = text:gsub("<script[^>]*>.-</script>","")
    text = text:gsub("<[hH]%d[^>]*>(.-)</%s*[hH]%d>","\n==%1==\n")
    text = text:gsub("<[bB][rR]%s*/?>","\n")
    text = text:gsub("<[pP][^>]*>(.-)</%s*[pP]>","\n%1\n")
    text = text:gsub("<li[^>]*>(.-)</li>","  * %1\n")
    text = text:gsub("<[^>]+>","")
    text = text:gsub("&nbsp;"," "):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&amp;","&")
    for line in text:gmatch("[^\n]+") do
      if y >= STATUS_Y then break end
      local t = line:match("^%s*(.-)%s*$")
      if t ~= "" then
        local fg = C.editorText
        if t:sub(1,2)=="==" then fg=C.accent end
        if t:sub(1,2)=="  " then fg=C.yellow end
        mAt(2, y, trunc(t, W-3), fg, C.bg)
        y = y+1
      end
    end
  end

  drawStatus("Click  << Back to Editor  to return", C.green)
  while true do
    local ev, side, mx, my = os.pullEvent("monitor_touch")
    if hitTest(mx, my) == "back" then return end
  end
end

-- ============================================================
--  PUBLISH
-- ============================================================
local function publishSite(site, content)
  local ext = (site.fileType=="lua") and ".lua" or ".html"
  local safe = (site.url or "site"):gsub("[^%w%-_]","_")
  local path = saveSiteFile(safe..ext, content)
  site.filePath = path
  site.published = true
  local sites = readSites()
  local found = false
  for i, s in ipairs(sites) do
    if s.url == site.url then sites[i]=site; found=true; break end
  end
  if not found then table.insert(sites, site) end
  writeSites(sites)
  writeState({ mode="editor", currentSite=site, status="published" })
  return path
end

-- ============================================================
--  EDITOR SCREEN
-- ============================================================
local function runEditor(site, initialContent)
  local ed = makeEditor(initialContent or "")
  writeState({ mode="editor", currentSite=site, status="editing" })
  local statusMsg = "Click toolbar buttons above  |  Type & arrow keys work in editor"
  local statusCol = C.subtle

  local function redraw()
    clearButtons()
    mCls()
    drawTopbar(site, ed.modified)
    drawToolbar("editor")
    drawSidebar({}, 0)
    renderEditor(ed, site.fileType)
    drawStatus(statusMsg, statusCol)
  end

  redraw()

  while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "monitor_touch" then
      local hit = hitTest(p2, p3)

      if hit == "save" then
        local ext = (site.fileType=="lua") and ".lua" or ".html"
        local safe = (site.url or "site"):gsub("[^%w%-_]","_")
        site.filePath = saveSiteFile(safe..ext, editorContent(ed))
        ed.modified = false
        statusMsg = "Saved!  "..site.filePath
        statusCol = C.green
        redraw(); os.sleep(1)
        statusMsg = "Click toolbar buttons above  |  Type & arrow keys work in editor"
        statusCol = C.subtle
        redraw()

      elseif hit == "preview" then
        previewScreen(site, editorContent(ed))
        writeState({ mode="editor", currentSite=site, status="editing" })
        redraw()

      elseif hit == "publish" then
        publishSite(site, editorContent(ed))
        ed.modified = false
        statusMsg = "Published!  Live at: "..site.url
        statusCol = C.green
        redraw(); os.sleep(1.5)
        statusMsg = "Click toolbar buttons above  |  Type & arrow keys work in editor"
        statusCol = C.subtle
        redraw()

      elseif hit == "close" then
        if ed.modified then
          if mConfirm("Discard unsaved changes?") then return "back" end
          redraw()
        else
          return "back"
        end

      elseif hit == "browser" then
        return "browser"
      end

    elseif ev == "key" then
      editorKey(ed, p1)
      redraw()

    elseif ev == "char" then
      editorChar(ed, p1)
      redraw()
    end
  end
end

-- ============================================================
--  NEW SITE WIZARD
-- ============================================================
local function newSiteWizard()
  mCls()
  clearButtons()
  drawTopbar(nil, false)
  mFill(1, TOOLBAR_Y, W, 1, C.btnBg)
  mAt(3, TOOLBAR_Y, "New Site - Choose type:", C.bg, C.btnBg)

  local mid = math.floor(W/2)
  mkBtn(mid-20, EDITOR_Y+2, "  HTML / CSS Site  ", "type_html",   C.accent, C.bg)
  mkBtn(mid-20, EDITOR_Y+4, "  Lua Script Site  ", "type_lua",    C.orange, C.bg)
  mkBtn(mid-20, EDITOR_Y+6, "  Cancel           ", "type_cancel", C.btnBg,  C.btnFg)

  mAt(3, EDITOR_Y+9,  "HTML/CSS  web-style pages with markup & styling", C.subtle, C.bg)
  mAt(3, EDITOR_Y+10, "Lua       interactive programs that run in-game",  C.subtle, C.bg)
  drawStatus("Click a site type to continue", C.subtle)

  local fileType
  while true do
    local ev, side, mx, my = os.pullEvent("monitor_touch")
    local hit = hitTest(mx, my)
    if hit == "type_html"   then fileType="html"; break
    elseif hit == "type_lua"    then fileType="lua";  break
    elseif hit == "type_cancel" then return nil
    end
  end

  -- Input via terminal
  local vals = tForm("New "..fileType:upper().." Site", {
    { "Site display name", "" },
    { "URL  (e.g. mysite.mc)", "" },
    { "Short description", "" },
    { "Keywords  (comma separated)", "" },
  })
  if not vals or vals[1] == "" then return nil end

  local keywords = {}
  for kw in (vals[4] or ""):gmatch("[^,]+") do
    table.insert(keywords, kw:match("^%s*(.-)%s*$"))
  end

  local site = {
    title       = vals[1],
    url         = vals[2] ~= "" and vals[2] or (vals[1]:lower():gsub("%s+","")..".mc"),
    description = vals[3],
    keywords    = keywords,
    fileType    = fileType,
    published   = false,
    filePath    = nil,
  }

  local template
  if fileType == "html" then
    template = "<!DOCTYPE html>\n<html>\n<head>\n  <title>"..site.title.."</title>\n"
      .."  <style>\n    body { background: #1a1a2e; color: #e0e0e0; font-family: monospace; padding: 20px; }\n"
      .."    h1 { color: #00d4ff; }\n    p { color: #aaaaaa; }\n  </style>\n</head>\n<body>\n"
      .."  <h1>"..site.title.."</h1>\n  <p>Welcome to "..site.title.."!</p>\n"
      .."  <p>Edit this page in GooCraft DevStudio.</p>\n</body>\n</html>"
  else
    template = "-- "..site.title.."\n-- GooCraft Lua Site\n\n"
      .."local w, h = term.getSize()\n"
      .."term.setBackgroundColor(colours.black)\nterm.clear()\n"
      .."term.setCursorPos(1,1)\nterm.setTextColor(colours.cyan)\n"
      .."print(\""..site.title.."\")\n"
      .."term.setTextColor(colours.lightGrey)\nprint(string.rep(\"-\", w))\n"
      .."term.setTextColor(colours.white)\nprint(\"\")\n"
      .."print(\"Welcome to "..site.title.."!\")\n"
      .."print(\"Edit this in GooCraft DevStudio.\")\n"
      .."term.setTextColor(colours.grey)\nprint(\"Press any key to exit...\")\n"
      .."os.pullEvent(\"key\")\n"
  end

  return site, template
end

-- ============================================================
--  SITE MANAGER
-- ============================================================
local function siteManager()
  local selectedIdx = 1

  local function redraw()
    clearButtons()
    local sites = readSites()
    mCls()
    drawTopbar(nil, false)
    drawToolbar("manager")
    drawSidebar(sites, selectedIdx)
    mFill(EDITOR_X, EDITOR_Y, EDITOR_W, EDITOR_H, C.editor)
    writeState({ mode="devstudio", currentSite=nil, status="idle" })

    if #sites == 0 then
      mAt(EDITOR_X+2, EDITOR_Y+2, "No sites yet!", C.subtle, C.editor)
      mAt(EDITOR_X+2, EDITOR_Y+3, "Click  + New Site  in the toolbar.", C.accent, C.editor)
    else
      local site = sites[selectedIdx]
      if site then
        mAt(EDITOR_X+2, EDITOR_Y,   "SITE DETAILS", C.accent, C.editor)
        mAt(EDITOR_X+2, EDITOR_Y+1, string.rep("-", EDITOR_W-5), C.subtle, C.editor)
        mAt(EDITOR_X+2, EDITOR_Y+2, "Name  : "..trunc(site.title or "", EDITOR_W-12), C.editorText, C.editor)
        mAt(EDITOR_X+2, EDITOR_Y+3, "URL   : "..trunc(site.url or "", EDITOR_W-12), C.accent, C.editor)
        local tc = (site.fileType=="lua") and C.orange or C.accent
        mAt(EDITOR_X+2, EDITOR_Y+4, "Type  : "..(site.fileType or "html"):upper(), tc, C.editor)
        local ps = site.published and "YES  (live)" or "NO  (draft)"
        local pc = site.published and C.green or C.yellow
        mAt(EDITOR_X+2, EDITOR_Y+5, "Status: "..ps, pc, C.editor)
        mAt(EDITOR_X+2, EDITOR_Y+6, "Desc  : "..trunc(site.description or "", EDITOR_W-12), C.subtle, C.editor)
        if site.keywords and #site.keywords > 0 then
          mAt(EDITOR_X+2, EDITOR_Y+7, "Tags  : "..trunc(table.concat(site.keywords,", "), EDITOR_W-12), C.subtle, C.editor)
        end
        mAt(EDITOR_X+2, EDITOR_Y+9, string.rep("-", EDITOR_W-5), C.subtle, C.editor)

        -- Action buttons
        local bx = EDITOR_X+2
        local by = EDITOR_Y+10
        bx = mkBtn(bx, by, " Open Editor ", "open_editor", C.green, C.bg)
        bx = bx+1
        bx = mkBtn(bx, by, " Delete ", "delete_site", C.red, C.bg)
        if site.published then
          bx = bx+1
          mkBtn(bx, by, " Unpublish ", "unpublish", C.yellow, C.bg)
        end
      end
    end

    drawStatus("Click a site on the left  |  Use buttons to manage", C.subtle)
  end

  redraw()

  while true do
    local ev, p1, p2, p3 = os.pullEvent()

    if ev == "monitor_touch" then
      local hit = hitTest(p2, p3)

      if hit == "new" then
        local site, template = newSiteWizard()
        if site and template then
          local sites = readSites()
          table.insert(sites, site)
          writeSites(sites)
          selectedIdx = #sites
          local action = runEditor(site, template)
          if action == "browser" then return "browser" end
        end
        redraw()

      elseif hit == "browser" then
        return "browser"

      elseif hit == "open_editor" then
        local sites = readSites()
        if #sites > 0 then
          local site = sites[selectedIdx]
          local content = loadSiteFile(site.filePath)
          local action = runEditor(site, content)
          -- re-sync site data after editor
          local newSites = readSites()
          for i, s in ipairs(newSites) do
            if s.url == site.url then sites[i]=s; break end
          end
          if action == "browser" then return "browser" end
        end
        redraw()

      elseif hit == "delete_site" then
        local sites = readSites()
        if #sites > 0 then
          local site = sites[selectedIdx]
          if mConfirm("Delete "..trunc(site.title or "?", 18).."?") then
            if site.filePath and fs.exists(site.filePath) then fs.delete(site.filePath) end
            table.remove(sites, selectedIdx)
            writeSites(sites)
            selectedIdx = math.max(1, selectedIdx-1)
          end
        end
        redraw()

      elseif hit == "unpublish" then
        local sites = readSites()
        if #sites > 0 then
          sites[selectedIdx].published = false
          writeSites(sites)
        end
        redraw()

      else
        -- Sidebar site selection
        if hit then
          local idx = hit:match("^select_(%d+)$")
          if idx then
            selectedIdx = tonumber(idx)
            redraw()
          end
        end
      end
    end
  end
end

-- ============================================================
--  ENTRY
-- ============================================================
local action = siteManager()
if action == "browser" then
  shell.run("goocraft")
end
