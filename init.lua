-- hit bursts: Perfect, Good, Bad or Miss pops where each note is judged, in the game's colours, or 300, 100, 50 and
-- a cross as osu! does. timings are those of osu!'s legacy judgements (LegacyJudgementPieceOld): fade in over 120 ms,
-- out over 600 ms from 500 ms, the pop of a hit and the drop of a miss

local UE = CS.UnityEngine
local TAB = "Hit bursts"
local FADE_IN, FADE_OUT_AT, FADE_OUT = 0.12, 0.5, 0.6 -- seconds
local LIFE = FADE_OUT_AT + FADE_OUT
local POOL = 32 -- texts, reused: nothing is made while a song plays
local JUDGEMENTS = { "perfect", "good", "bad", "miss" }
-- what each style writes, how big next to a "300", and its colours: the game's own for its words (the yellow of a
-- perfect, the blue of a good, the red of a bad note), osu!'s for its numbers
local STYLES = {
  Phigros = { perfect = "Perfect", good = "Good", bad = "Bad", miss = "Miss", scale = 0.8,
    colours = { perfect = { 1, 0.93, 0.63, 1 }, good = { 0.71, 0.88, 1, 1 }, bad = { 1, 0.42, 0.42, 1 }, miss = { 1, 1, 1, 0.7 } } },
  ["osu!"] = { perfect = "300", good = "100", bad = "50", miss = "×", scale = 1,
    colours = { perfect = { 0.4, 0.8, 1, 1 }, good = { 0.55, 0.9, 0.25, 1 }, bad = { 1, 0.67, 0.2, 1 }, miss = { 1, 0.25, 0.25, 1 } } },
}

local preview -- the bursts of the settings' preview row, while the settings show it

local enabled = setting("Show hit bursts", true, TAB)
local style = setting("Style", "Phigros", { "Phigros", "osu!" }, TAB)
local perfects = setting("Show them on perfect hits", true, TAB)
local slides = setting("Show them on drags and flicks", false, TAB)
local size = setting("Size", 1.0, { 0.5, 2 }, TAB)

local bursts, live, cursor = {}, {}, 1

-- a burst's text under parent, outlined to show on any background
local function burst(parent, font)
  local text = phigrospp.ui.text(parent, "hit-burst", font, { 0, 0 }, { 0, 0 }, 100, 4, { 0.5, 0.5 }) -- MiddleCenter
  text.fontStyle = 1 -- Bold
  local outline = text.gameObject:AddComponent(UE.UI.Outline)
  outline.effectColor = { 0, 0, 0, 0.7 }
  return { text = text, transform = text.transform, object = text.gameObject, outline = outline }
end

-- starts a burst over: what it says in the style picked, `height` high for a "300", at x, y of its parent
local function start(b, judgement, height, x, y)
  local look = STYLES[style()]
  b.start, b.miss, b.colour = now(), judgement == "miss", look.colours[judgement]
  b.scale, b.alpha = nil, nil -- both are set again on its first frame
  b.x, b.y, b.fall = x, y, height * 0.8
  b.tilt = b.miss and (math.random() * 2 - 1) * 8.6 or 0 -- degrees, a miss turns to twice that as it falls
  b.text.text, b.text.fontSize = look[judgement], math.floor(height * look.scale)
  b.outline.effectDistance = { height / 24, -height / 24 }
  b.transform.anchoredPosition, b.transform.localEulerAngles = { x, y }, { 0, 0, b.tilt }
end

-- a hit pops: 0.6 to 1.1 in 80% of the fade in, then 0.9 and back to 1. a miss shrinks from 1.6 in 100 ms
local function scale(b, t)
  if b.miss then return t < 0.1 and 1.6 - 0.6 * (t / 0.1) ^ 2 or 1 end
  local f = t / FADE_IN
  if f < 0.8 then return 0.6 + 0.5 * f / 0.8 end
  if f < 1 then return 1.1 end
  if f < 1.2 then return 1.1 - 0.2 * (f - 1) / 0.2 end
  if f < 1.4 then return 0.95 + 0.05 * (f - 1.2) / 0.2 end
  return 1
end

-- a burst as it is `age` seconds after its start
local function pose(b, age)
  local s = scale(b, age)
  if s ~= b.scale then
    b.scale = s
    b.transform.localScale = { s, s, 1 }
  end
  local alpha = age < FADE_IN and age / FADE_IN or age > FADE_OUT_AT and math.max(0, 1 - (age - FADE_OUT_AT) / FADE_OUT) or 1
  if alpha ~= b.alpha then
    b.alpha = alpha
    b.text.color = { b.colour[1], b.colour[2], b.colour[3], b.colour[4] * alpha }
  end
  if b.miss then
    local fallen = math.min(1, age / LIFE) ^ 2
    b.transform.anchoredPosition, b.transform.localEulerAngles = { b.x, b.y - b.fall * fallen }, { 0, 0, b.tilt * (1 + fallen) }
  end
end

-- the texts, on a canvas over the game in screen pixels, like where hits are given
local function pool()
  local canvas = phigrospp.ui.overlay("hit-bursts", 100).transform
  local font = UE.Object.FindObjectOfType(UE.UI.Text).font
  for i = 1, POOL do
    bursts[i] = burst(canvas, font)
    bursts[i].object:SetActive(false)
  end
end

on("song", function()
  if #bursts == 0 or not il2cpp.alive(bursts[1].text) then pool() end
  live = {}
end)

-- the bursts die with the level's scene, some before this runs
on("leave", function() live = {} end)

on("hit", function(hit)
  if not enabled() or not hit.x or #bursts == 0 then return end
  -- a drag or a flick only says something when it's missed, unless asked
  local slide = hit.judgement ~= "miss" and (hit.note == "drag" or hit.note == "flick")
  if hit.judgement == "perfect" and not perfects() or slide and not slides() then return end
  local b = bursts[cursor]
  cursor = cursor % POOL + 1
  -- a third of the screen's height holds ten bursts, above the note so the finger doesn't hide it
  local height = UE.Screen.height / 30 * size()
  start(b, hit.judgement, height, hit.x, hit.y + height * 1.4)
  if not b.live then
    b.live = true
    b.object:SetActive(true)
    live[#live + 1] = b
  end
end)

-- the settings show one burst of each judgement, over and over, as the style and the size picked make them
row(190, function(area)
  local font = UE.Object.FindObjectOfType(UE.UI.Text).font
  preview = {}
  for i = 1, #JUDGEMENTS do
    preview[i] = burst(area, font)
    -- spread along the row, wherever its width ends up
    preview[i].transform.anchorMin, preview[i].transform.anchorMax = { i / (#JUDGEMENTS + 1), 0.5 }, { i / (#JUDGEMENTS + 1), 0.5 }
  end
  preview.scale = area:GetComponentInParent(UE.Canvas, true).scaleFactor -- the row isn't in screen pixels
end, TAB)

on("update", function()
  local t = now()
  for i = #live, 1, -1 do
    local b = live[i]
    if t - b.start >= LIFE then
      b.live = false
      b.object:SetActive(false)
      table.remove(live, i)
    else
      pose(b, t - b.start)
    end
  end
  if not preview or not il2cpp.alive(preview[1].text) then return end
  -- one after the other, then again once the last is gone
  local round = math.floor(t / (LIFE + 0.8))
  for i, b in ipairs(preview) do
    if b.round ~= round and t % (LIFE + 0.8) >= (i - 1) * 0.12 then
      b.round = round
      start(b, JUDGEMENTS[i], UE.Screen.height / 30 * size() / preview.scale, 0, 0)
    end
    if b.start then pose(b, t - b.start) end
  end
end)
