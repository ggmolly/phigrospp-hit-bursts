-- osu! style hit bursts: 300, 100, 50 or a cross pops where each note is judged. timings are those of osu!'s legacy
-- judgements (LegacyJudgementPieceOld): fade in over 120 ms, out over 600 ms from 500 ms, the pop of a hit and the
-- drop of a miss

local UE = CS.UnityEngine
local TAB = "Hit bursts"
local FADE_IN, FADE_OUT_AT, FADE_OUT = 0.12, 0.5, 0.6 -- seconds
local LIFE = FADE_OUT_AT + FADE_OUT
local POOL = 32 -- texts, reused: nothing is made while a song plays
local STYLES = {
  ["osu!"] = { perfect = "300", good = "100", bad = "50", miss = "×" },
  kanji = { perfect = "激", good = "喝", bad = "50", miss = "×" },
}
local COLOURS = {
  perfect = { 0.4, 0.8, 1, 1 }, good = { 0.55, 0.9, 0.25, 1 }, bad = { 1, 0.67, 0.2, 1 }, miss = { 1, 0.25, 0.25, 1 },
}

local enabled = setting("Show hit bursts", true, TAB)
local style = setting("Style", "osu!", { "osu!", "kanji" }, TAB)
local perfects = setting("Show them on perfect hits", true, TAB)
local slides = setting("Show them on drags and flicks", false, TAB)
local size = setting("Size", 1.0, { 0.5, 2 }, TAB)

local bursts, live, cursor = {}, {}, 1

-- the texts, on a canvas over the game in screen pixels, like where hits are given
local function pool()
  local canvas = phigrospp.ui.overlay("hit-bursts", 100).transform
  local font = UE.Object.FindObjectOfType(UE.UI.Text).font
  for i = 1, POOL do
    local text = phigrospp.ui.text(canvas, "hit-burst", font, { 0, 0 }, { 0, 0 }, 100, 4, { 0.5, 0.5 }) -- MiddleCenter
    text.fontStyle = 1 -- Bold
    local outline = text.gameObject:AddComponent(UE.UI.Outline)
    outline.effectColor, outline.effectDistance = { 0, 0, 0, 0.7 }, { 3, -3 }
    text.gameObject:SetActive(false)
    bursts[i] = { text = text, transform = text.transform, object = text.gameObject }
  end
end

on("song", function()
  if #bursts == 0 or not il2cpp.alive(bursts[1].text) then pool() end
  live = {}
end)

on("leave", function()
  for _, b in ipairs(live) do b.object:SetActive(false) end
  live = {}
end)

on("hit", function(hit)
  if not enabled() or not hit.x or #bursts == 0 then return end
  local slide = hit.judgement ~= "miss" and not hit.offset
  if hit.judgement == "perfect" and not perfects() or slide and not slides() then return end
  local b = bursts[cursor]
  cursor = cursor % POOL + 1
  -- a third of the screen's height holds ten bursts, above the note so the finger doesn't hide it
  local height = UE.Screen.height / 30 * size()
  b.start, b.miss, b.colour = now(), hit.judgement == "miss", COLOURS[hit.judgement]
  b.scale, b.alpha = nil, nil -- both are set again on its first frame
  b.x, b.y, b.fall = hit.x, hit.y + height * 1.4, height * 0.8
  b.tilt = b.miss and (math.random() * 2 - 1) * 8.6 or 0 -- degrees, a miss turns to twice that as it falls
  b.text.text, b.text.fontSize = STYLES[style()][hit.judgement], math.floor(height)
  b.transform.anchoredPosition, b.transform.localEulerAngles = { b.x, b.y }, { 0, 0, b.tilt }
  if not b.live then
    b.live = true
    b.object:SetActive(true)
    live[#live + 1] = b
  end
end)

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

on("update", function()
  local t = now()
  for i = #live, 1, -1 do
    local b = live[i]
    local age = t - b.start
    if age >= LIFE then
      b.live = false
      b.object:SetActive(false)
      table.remove(live, i)
    else
      local s = scale(b, age)
      if s ~= b.scale then
        b.scale = s
        b.transform.localScale = { s, s, 1 }
      end
      local alpha = age < FADE_IN and age / FADE_IN or age > FADE_OUT_AT and 1 - (age - FADE_OUT_AT) / FADE_OUT or 1
      if alpha ~= b.alpha then
        b.alpha = alpha
        b.text.color = { b.colour[1], b.colour[2], b.colour[3], alpha }
      end
      if b.miss then
        local fallen = (age / LIFE) ^ 2
        b.transform.anchoredPosition, b.transform.localEulerAngles = { b.x, b.y - b.fall * fallen }, { 0, 0, b.tilt * (1 + fallen) }
      end
    end
  end
end)
