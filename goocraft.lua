-- goocraft.lua
-- GooCraft Browser - Google-style search, runs on TOP monitor
-- All navigation via clickable buttons - no keybind conflicts
-- Part of the GooCraft Suite

local STATE_FILE = "/.goocraft_state"
local SITES_FILE = "/.goocraft_sites"

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
  print("GooCraft needs a monitor attached!")
  print("Attach a monitor and restart.")
  return
end

mon.setTextScale(0.5)
local W, H = mon.getSize()

-- ============================================================
--  COLOURS
-- ============================================================
local C = {
  bg       = colours.black,
  topBar   = colours.grey,
  topText  = colours.white,
  accent   = colours.blue,
  urlCol   = colours.cyan,
  descCol  = colours.lightGrey,
  inputBg  = colours.grey,
  inputFg  = colours.white,
  subtle   = colours.grey,
  green    = colours.green,
  orange   = colours.orange,
  yellow   = colours.yellow,
  btnBg    = colours.lightGrey,
  btnFg    = colours.black,
  logo     = { colours.blue, colours.red, colours.yellow, colours.blue,
               colours.blue, colours.green, colours.red, colours.yellow },
}

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

-- ============================================================
--  MONITOR HELPERS
-- ============================================================
local function mAt(x, y, text, fg, bg)
  if y < 1 or y > H or x < 1 then return end
  mon.setCursorPos(x, y)
  if fg then mon.setTextColor(fg) end
  if bg then mon.setBackgroundColor(bg) end
  local avail = W - x + 1
  if avail > 0 then mon.write(text:sub(1, avail)) end
end

local function mFill(x, y, fw, fh, bg)
  mon.setBackgroundColor(bg)
  for row = y, y+fh-1 do
    if row >= 1 and row <= H then
      local sx = math.max(1, x)
      local aw = fw - (sx - x)
      if aw > 0 then
        mon.setCursorPos(sx, row)
        mon.write(string.rep(" ", math.min(aw, W-sx+1)))
      end
    end
  end
end

local function mCls()
  mon.setBackgroundColor(C.bg)
  mon.clear()
end

local function mCx(text) return math.floor((W - #text) / 2) + 1 end

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
--  SEARCH
-- ============================================================
local function doSearch(query)
  local sites = readSites()
  query = query:lower()
  local results = {}
  for _, site in ipairs(sites) do
    if site.published then
      local score = 0
      if (site.title or ""):lower():find(query,1,true)       then score = score+3 end
      if (site.url   or ""):lower():find(query,1,true)       then score = score+2 end
      if (site.description or ""):lower():find(query,1,true) then score = score+1 end
      for _, kw in ipairs(site.keywords or {}) do
        if kw:lower():find(query,1,true) then score = score+2 end
      end
      if score > 0 then table.insert(results, {site=site, score=score}) end
    end
  end
  table.sort(results, function(a,b) return a.score > b.score end)
  local out = {}
  for _, r in ipairs(results) do table.insert(out, r.site) end
  return out
end

-- ============================================================
--  TOPBAR (always shown)
-- ============================================================
local function drawTopbar(subtitle)
  mFill(1, 1, W, 1, C.topBar)
  local logo = "GooKraft"
  for i = 1, #logo do
    mAt(i, 1, logo:sub(i,i), C.logo[i], C.topBar)
  end
  if subtitle then
    mAt(#logo+2, 1, subtitle, C.topText, C.topBar)
  end
  -- DevStudio button always top-right
  mkBtn(W-12, 1, " DevStudio ", "goto_devstudio", C.orange, C.bg)
end

-- ============================================================
--  HOME SCREEN
-- ============================================================
local function homeScreen()
  writeState({ mode="browser", status="idle" })
  mCls()
  clearButtons()
  drawTopbar("Home")

  -- Logo centred
  local logoY = math.floor(H/2) - 3
  local logo  = "GooKraft"
  local lx    = mCx(logo)
  for i = 1, #logo do
    mAt(lx+i-1, logoY, logo:sub(i,i), C.logo[i], C.bg)
  end

  local tag = "Search the network"
  mAt(mCx(tag), logoY+1, tag, C.subtle, C.bg)

  -- Search box
  local boxW = math.min(40, W-6)
  local boxX = math.floor((W-boxW)/2)+1
  local boxY = logoY+3

  mFill(boxX, boxY, boxW, 1, C.inputBg)
  mAt(boxX+1, boxY, ">", C.subtle, C.inputBg)

  -- Search button
  mkBtn(boxX+boxW+1, boxY, " Search ", "do_search", C.accent, C.bg)

  -- Site count
  local sites = readSites()
  local pub = 0
  for _, s in ipairs(sites) do if s.published then pub=pub+1 end end
  local ct = pub.." site"..(pub~=1 and "s" or "").." indexed"
  mAt(mCx(ct), H, ct, C.subtle, C.bg)

  -- Hint
  mAt(mCx("Type on keyboard then click Search"), logoY+5, "Type on keyboard then click Search", C.subtle, C.bg)

  -- Get input from terminal
  term.setBackgroundColor(colours.black)
  term.setTextColor(colours.white)
  term.clear()
  term.setCursorPos(1,1)
  term.write("Search GooCraft: ")
  term.setCursorBlink(true)
  local query = read()
  term.setCursorBlink(false)

  -- Update search bar on monitor with the query
  mFill(boxX, boxY, boxW, 1, C.inputBg)
  mAt(boxX+1, boxY, "> "..trunc(query, boxW-4), C.inputFg, C.inputBg)

  return query
end

-- ============================================================
--  RESULTS SCREEN
-- ============================================================
local function resultsScreen(query, results)
  writeState({ mode="browser", status="searched" })
  mCls()
  clearButtons()
  drawTopbar("Search Results")

  -- Search bar at top (row 2)
  mFill(1, 2, W, 1, C.inputBg)
  mAt(2, 2, "> "..trunc(query, W-12), C.inputFg, C.inputBg)
  mkBtn(W-9, 2, " Search ", "new_search", C.accent, C.bg)

  -- Divider
  mFill(1, 3, W, 1, C.subtle)
  mAt(1, 3, string.rep("-", W), C.bg, C.subtle)

  -- Count
  local ct = #results.." result"..(#results~=1 and "s" or "").." for \""..query.."\""
  mAt(2, 4, trunc(ct, W-2), C.subtle, C.bg)

  if #results == 0 then
    local msg = "No results found. Try different keywords."
    mAt(mCx(msg), math.floor(H/2), msg, C.subtle, C.bg)
    local tip = "Only published sites appear in search."
    mAt(mCx(tip), math.floor(H/2)+1, tip, C.subtle, C.bg)
  else
    local y = 6
    for i, site in ipairs(results) do
      if y + 2 > H-1 then break end

      -- Number
      mAt(2, y, tostring(i)..".", C.subtle, C.bg)

      -- Type badge
      local badge = "[".. (site.fileType or "html"):upper().."]"
      local badgeCol = (site.fileType=="lua") and C.orange or C.accent
      mAt(5, y, badge, badgeCol, C.bg)

      -- Title (clickable to "visit")
      local titleMax = W - 6 - #badge - 1
      local titleStr = trunc(site.title or "Untitled", titleMax)
      mAt(5+#badge+1, y, titleStr, C.accent, C.bg)
      table.insert(BUTTONS, {
        x1=5+#badge+1, x2=5+#badge+#titleStr+1,
        y1=y, y2=y,
        id="visit_"..i
      })

      -- URL
      mAt(5, y+1, trunc(site.url or "", W-6), C.urlCol, C.bg)

      -- Description
      mAt(5, y+2, trunc(site.description or "", W-6), C.descCol, C.bg)

      y = y + 4
    end
  end

  -- Bottom bar
  mFill(1, H, W, 1, C.topBar)
  mkBtn(2, H, " New Search ", "new_search", C.btnBg, C.btnFg)
  mkBtn(16, H, " DevStudio ", "goto_devstudio", C.orange, C.bg)

  return results
end

-- ============================================================
--  VISIT SITE
-- ============================================================
local function visitSite(site)
  writeState({ mode="preview", currentSite=site, status="viewing" })
  mCls()
  clearButtons()
  drawTopbar("Viewing: "..trunc(site.title or "?", W-20))

  mFill(1, 2, W, 1, C.subtle)
  mAt(1, 2, string.rep("-", W), C.bg, C.subtle)

  if site.fileType == "lua" then
    -- Run on main terminal
    mAt(3, 3, "Running Lua site on terminal...", C.subtle, C.bg)
    mAt(3, 4, site.url, C.accent, C.bg)
    mkBtn(3, 6, " << Back ", "back", C.btnBg, C.btnFg)

    local path = site.filePath
    if path and fs.exists(path) then
      term.setBackgroundColor(colours.black)
      term.setTextColor(colours.white)
      term.clear()
      term.setCursorPos(1,1)
      local ok, err = pcall(function() shell.run(path) end)
      if not ok then
        term.setTextColor(colours.red)
        print("Error: "..tostring(err))
        print("Press any key...")
        os.pullEvent("key")
      end
    else
      term.clear()
      term.setCursorPos(1,1)
      term.setTextColor(colours.red)
      print("Site file not found: "..tostring(path))
      print("Has it been published?")
      print("Press any key...")
      os.pullEvent("key")
    end
    return

  else
    -- Render HTML (stripped) on monitor
    local path = site.filePath
    local content = ""
    if path and fs.exists(path) then
      local f = fs.open(path, "r")
      content = f.readAll()
      f.close()
    end

    local text = content
    text = text:gsub("<style[^>]*>.-</style>","")
    text = text:gsub("<script[^>]*>.-</script>","")
    text = text:gsub("<[hH]%d[^>]*>(.-)</%s*[hH]%d>","\n==%1==\n")
    text = text:gsub("<[bB][rR]%s*/?>","\n")
    text = text:gsub("<[pP][^>]*>(.-)</%s*[pP]>","\n%1\n")
    text = text:gsub("<li[^>]*>(.-)</li>","  * %1\n")
    text = text:gsub("<[^>]+>","")
    text = text:gsub("&nbsp;"," "):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&amp;","&")

    local y = 3
    for line in text:gmatch("[^\n]+") do
      if y >= H-1 then break end
      local t = line:match("^%s*(.-)%s*$")
      if t ~= "" then
        local fg = colours.white
        if t:sub(1,2) == "==" then fg = colours.cyan end
        if t:sub(1,2) == "  " then fg = colours.yellow end
        mAt(2, y, trunc(t, W-3), fg, C.bg)
        y = y+1
      end
    end
  end

  mFill(1, H, W, 1, C.topBar)
  mkBtn(2, H, " << Back to Results ", "back", C.btnBg, C.btnFg)

  while true do
    local ev, side, mx, my = os.pullEvent("monitor_touch")
    if hitTest(mx, my) == "back" then return end
  end
end

-- ============================================================
--  MAIN LOOP
-- ============================================================
while true do
  local query = homeScreen()
  if query == nil then query = "" end
  query = query:match("^%s*(.-)%s*$") or ""

  if query ~= "" then
    local results = doSearch(query)
    resultsScreen(query, results)

    -- Wait for monitor interaction on results
    local keepGoing = true
    while keepGoing do
      local ev, side, mx, my = os.pullEvent("monitor_touch")
      local hit = hitTest(mx, my)

      if hit == "new_search" or hit == nil and mx == nil then
        keepGoing = false  -- back to home

      elseif hit == "new_search" then
        keepGoing = false

      elseif hit == "goto_devstudio" then
        shell.run("devstudio")
        -- Rebuild results after returning
        results = doSearch(query)
        resultsScreen(query, results)

      else
        -- Check for visit_N buttons
        if hit then
          local idx = hit:match("^visit_(%d+)$")
          if idx then
            local site = results[tonumber(idx)]
            if site then
              visitSite(site)
              -- Redraw results after returning
              resultsScreen(query, results)
            end
          elseif hit == "back" then
            keepGoing = false
          end
        end
      end
    end
  end
end
