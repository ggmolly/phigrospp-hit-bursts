# Hit bursts

A mod for [Phigros++](https://github.com/ggmolly/PhigrosPlusPlus) that pops a word where each note is judged: Perfect, Good, Bad or Miss in the game's own colours, or 300, 100, 50 and a falling cross the way osu! shows them. Each one follows the timing of osu!'s classic judgements, popping in over a tenth of a second and fading out half a second later.

![Bursts popping on notes as they are hit, in the osu! style](preview.gif)

## Install

Open the **Mods** tab of the game's settings and pick Hit bursts in the catalog, or open [this link](phigrospp://install/ggmolly/phigrospp-hit-bursts) on the device.

## Settings

The mod adds a **Hit bursts** tab to the settings, with a preview of the four bursts as the style and the size make them.

| Setting | |
|---|---|
| Show hit bursts | Turns them all off without disabling the mod |
| Style | `Phigros` for Perfect, Good, Bad and Miss, `osu!` for 300, 100 and 50 |
| Show them on perfect hits | Off leaves only what went wrong on screen |
| Show them on drags and flicks | Off by default, a stream of drags fills the screen with them |
| Size | From half to twice their size |

## How it works

Phigros++ tells mods where each hit lands on screen (`hit.x` and `hit.y` in `on("hit")`), so the mod only draws: a pool of texts on a canvas over the game, moved and faded every frame. The animation is the one of osu!'s `LegacyJudgementPieceOld`.

It needs a Phigros++ newer than 0.1.0-beta.12, for where hits land and for the preview row of its settings.
