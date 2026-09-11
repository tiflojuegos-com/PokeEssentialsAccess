# pbTopRightWindow, the modal panel Essentials blocks on until the confirm key. Vanilla raises it twice in a
# row for the stats a Pokemon gained: the increases, then the new totals. The battle scene's pbLevelUp is
# the one caller that already has a better line -- the same figures with the mod's own stat names -- so it
# mutes the panels for the length of its call; everywhere else (a Rare Candy levelling a Pokemon outside
# battle, where pbChangeExp builds the panels from local variables) the panel reads itself.
#
# pbTopRightWindow itself is in the engine stubs, where core can find it at load: a function defined in a
# spec file lands after the mod has already asked for it and nothing binds. The scene here is the engine's,
# calling the function twice with the two texts it composes.
class TopRightLevelUpScene
  def pbLevelUp(pkmn, _battler, _ohp, _oatk, _odef, _ospa, _ospd, _ospe)
    pbTopRightWindow("Max. HP<r>+3\r\nAttack<r>+2")
    pbTopRightWindow("Max. HP<r>44\r\nAttack<r>30")
    pkmn
  end
end

PokeAccess::Hooks.around_hook("TopRightLevelUpScene", :pbLevelUp) do |_s, nxt, _a|
  PokeAccess.speak("subio de nivel", false)
  PokeAccess::ModalPanel.muted { nxt.call }
end

Suite.define("top-right panel: reads itself, except where the caller already said it better") do
  SpeakCapture.clear
  pbTopRightWindow("Max. HP<r>+3\r\nAttack<r>+2")
  line = SpeakCapture.lines.join(" ")
  match "a panel raised on its own is read", line, /Max\. HP/
  truthy "with its markup and line breaks gone",
         !line.include?("<r>") && !line.include?("\r") && !line.include?("\n")

  SpeakCapture.clear
  TopRightLevelUpScene.new.pbLevelUp(nil, nil, 1, 2, 3, 4, 5, 6)
  eq "a caller that speaks for the panels silences them", SpeakCapture.lines, ["subio de nivel"]

  # The mute must not outlive the call, or every later panel in the session goes quiet.
  SpeakCapture.clear
  pbTopRightWindow("Speed<r>+1")
  spoke "and the next panel after it is read again", /Speed/

  # A caller that raises must not leave the reader muted either.
  begin
    PokeAccess::ModalPanel.muted { raise "boom" }
  rescue StandardError
    nil
  end
  SpeakCapture.clear
  pbTopRightWindow("Defense<r>+1")
  spoke "even when the muted call threw", /Defense/
end

# The mute rides its own hook so that the READING keeps the swallow every reader has: a body that throws
# must cost a line of speech, never the level-up itself. An around-hook body is logged and re-raised, which
# is right for a body that may decline to run the original and wrong for one that only talks.
class TopRightThrowingScene
  def pbLevelUp(*_a); pbTopRightWindow("Max. HP<r>+1"); :done; end
end

PokeAccess::Hooks.before_hook("TopRightThrowingScene", :pbLevelUp) { |_s, _a| raise "reader boom" }
PokeAccess::Hooks.around_hook("TopRightThrowingScene", :pbLevelUp) do |_s, nxt, _a|
  PokeAccess::ModalPanel.muted { nxt.call }
end

Suite.define("top-right panel: a reader that throws costs its line, not the level-up") do
  SpeakCapture.clear
  got = (begin; TopRightThrowingScene.new.pbLevelUp(nil); rescue StandardError; :propagated; end)
  eq "the original still ran and returned", got, :done
  silent "the panels stayed muted even though the reader threw"
end
