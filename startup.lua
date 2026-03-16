-- startup.lua
-- GooCraft Suite launcher
-- Just run: startup  (or rename to 'startup' for auto-boot)
-- Both goocraft and devstudio now run directly on the monitor.

if not term.isColour() then
  print("GooCraft requires an Advanced Computer!")
  return
end

-- Check monitor
local monFound = false
for _, side in ipairs({"top","back","left","right","front","bottom"}) do
  if peripheral.isPresent(side) and peripheral.getType(side) == "monitor" then
    monFound = true; break
  end
end

if not monFound and not peripheral.find("monitor") then
  print("No monitor found!")
  print("Attach a monitor to this computer,")
  print("then run 'startup' again.")
  print("")
  print("Tip: A 3-wide x 2-tall monitor works great.")
  return
end

-- Clear terminal - it's just used for text input when typing searches/site names
term.setBackgroundColor(colours.black)
term.setTextColor(colours.cyan)
term.clear()
term.setCursorPos(1,1)
print("GooCraft Suite")
term.setTextColor(colours.grey)
print("Monitor: active")
print("Keyboard: use for typing in search/forms")
print("")
term.setTextColor(colours.white)
print("Starting browser...")
os.sleep(0.5)

shell.run("goocraft")
