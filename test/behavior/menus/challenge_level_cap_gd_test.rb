# Level Caps EX's mode chooser in Challenge Modes (plugins/challenge_rules.rb, Eternal Emerald): its title said on the
# chooser's first frame, then the focused mode, then that mode's description, which the info key keeps while the
# chooser is up. The plugin's registration is evaluated again over the stand-in below, which holds the game's name only
# while it binds.

# ChallengeModes.select_level_cap_mode as the game runs it: an info window given "", the modes' command window, the
# title window painting its text, the first mode's description, then the loop. Each frame pulses, moves the cursor to
# the row moves gives it and updates the list, the description following the cursor, and yields; the last frame's row
# is chosen.
module LevelCapChooser
  TITLE = "Select Level Cap Mode"
  MODES = ["Hard Cap", "EXP Cap", "Obedience Cap"]
  DESCS = ["Your Pokémon cannot level up or gain experience past the level cap. Most restrictive mode.",
           "Your Pokémon gain reduced EXP (1/10th) when above the level cap. They can still level slowly.",
           "Your Pokémon will disobey you in battle when above the level cap, similar to traded Pokémon."]

  module_function

  def select_level_cap_mode(moves = [0, 0])
    info = Window_AdvancedTextPokemon.new("")
    list = Window_CommandPokemon.new(MODES)
    drawTextEx(nil, 0, -2, 480, 0, TITLE)
    info.text = DESCS[0]
    moves.each do |row|
      PokeAccess::Frame.run_pollers
      old = list.index
      list.index = row
      list.update
      info.text = DESCS[list.index] if old != list.index
      yield if block_given?
    end
    list.index + 1
  end
end

challenge = File.join(Harness::ROOT, "plugins", "challenge_rules.rb")
challenge_src = Harness.source(challenge)
cap_at = challenge_src.index('PokeAccess::Hooks.wrap_singleton("ChallengeModes", :select_level_cap_mode')
cap_end = challenge_src.index("\n", challenge_src.index(/^end\s*$/, cap_at)) + 1
modes_held = Object.const_defined?(:ChallengeModes) ? ChallengeModes : nil
begin
  Object.send(:remove_const, :ChallengeModes) if modes_held
  Object.const_set(:ChallengeModes, LevelCapChooser)
  eval(challenge_src[cap_at...cap_end], TOPLEVEL_BINDING, challenge, challenge_src[0, cap_at].count("\n") + 1)
ensure
  Object.send(:remove_const, :ChallengeModes)
  Object.const_set(:ChallengeModes, modes_held) if modes_held
end

class ChallengeLevelCapGdTest < PokeAccessTest
  Chooser = LevelCapChooser

  test "opening says the title, then the first mode, then its description, all queued" do
    Chooser.select_level_cap_mode
    assert_equal [[Chooser::TITLE, false], ["Hard Cap", false], [Chooser::DESCS[0], false]], SpeakCapture.log
  end

  test "a move says the new mode, cutting in, and its description after it" do
    Chooser.select_level_cap_mode([0, 0, 1])
    assert_equal [["EXP Cap", true], [Chooser::DESCS[1], false]], SpeakCapture.log.last(2)
  end

  test "the info key keeps the focused mode's description while the chooser is up, and lets it go as it closes" do
    held = []
    Chooser.select_level_cap_mode([0, 0, 2]) { held.push(PokeAccess::Info.info_text) }
    assert_equal [Chooser::DESCS[0], Chooser::DESCS[0], Chooser::DESCS[2]], held
    assert_nil PokeAccess::Info.info_text, "once it closes"
  end

  test "at medium the descriptions are left to the info key, the title and the modes still said" do
    PokeAccess::Config.verbosity = :medium
    held = []
    Chooser.select_level_cap_mode([0, 0, 1]) { held.push(PokeAccess::Info.info_text) }
    assert_equal [[Chooser::TITLE, false], ["Hard Cap", false], ["EXP Cap", true]], SpeakCapture.log
    assert_equal Chooser::DESCS[1], held.last
  end

  test "the title is said once, however many frames the chooser runs" do
    Chooser.select_level_cap_mode([0, 0, 0, 0])
    assert_equal 1, SpeakCapture.lines.count(Chooser::TITLE)
  end

  test "the chooser keeps the mode the game returns" do
    assert_equal 3, Chooser.select_level_cap_mode([0, 2])
  end
end
