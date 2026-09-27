# Relict's difficulty picker (the description in full, kept on the info key until it closes) and Fire Ash's Grandeur
# Club card (its page number a position, a blank slot said as such), gamedata pass; the stand-ins come before the
# profiles load.
class PickDifficulty
  def initialize(diffs); @difficulties = diffs; @index = 0; end
  def update; :updated; end
  def run; update; :done; end
end

class GCCard_Scene
  def pbDrawGCCardOne
    pbDrawTextPositions(nil, [["ID No.", 0, 0], ["12345", 100, 0], ["Practice", 0, 40], ["Club", 0, 80]])
    :drawn
  end
end

load File.expand_path("../../../games/relict/difficulty.rb", File.dirname(__FILE__))
load File.expand_path("../../../games/fireash/gc_card.rb", File.dirname(__FILE__))

Suite.define("relict difficulty: the option, its description in full, and the info key keeps both until it closes") do
  t = PokeAccess::I18n
  picker = PickDifficulty.new([["NORMAL", "Normal difficulty."], ["HARD", "Harder battles."]])
  PokeAccess::Config.verbosity = :brief
  begin
    SpeakCapture.clear
    picker.update
    eq "brief: the heading once, then the option alone", SpeakCapture.last, "#{t.t(:rel_difficulty)}. NORMAL"
    eq "the info key keeps its description", PokeAccess::Info.info_text, "NORMAL. Normal difficulty."
    PokeAccess::Config.verbosity = :full
    picker.instance_variable_set(:@index, 1)
    SpeakCapture.clear
    picker.update
    eq "full: the next one with its description, and no heading again", SpeakCapture.last, "HARD. Harder battles."
    picker.run
    eq "the picker closing takes it off the info key", PokeAccess::Info.info_text, nil
    fresh = PickDifficulty.new([["NORMAL", "Normal difficulty."]])
    SpeakCapture.clear
    fresh.run
    eq "inside the picker's own loop the option is still said", SpeakCapture.last,
       "#{t.t(:rel_difficulty)}. NORMAL. Normal difficulty."
  ensure
    PokeAccess::Config.verbosity = :full
  end
end

Suite.define("fire ash card: the page number is a position, said from medium") do
  saved = $game_variables
  begin
    $game_variables = Hash.new(0).merge(91 => 2, 92 => 1)
    page = PokeAccess::I18n.t(:gc_page, :n => 1, :total => 4)
    rows = vb_levels do
      SpeakCapture.clear
      GCCard_Scene.new.pbDrawGCCardOne
      SpeakCapture.last.to_s
    end
    truthy "brief: the card without its page number", !rows[0].include?(page) && rows[0].include?("ID No.")
    truthy "medium: with the page first", rows[1].start_with?(page)
  ensure
    $game_variables = saved
  end
end

# A slot the card leaves blank shows no emblem and nothing else: a best Gauntlet streak under 10 or a zero anywhere
# says so, not that the challenge was never played.
Suite.define("fire ash card: a blank slot holds no emblem, which says nothing of having played") do
  t = PokeAccess::I18n
  gc = PokeAccess::FireAshGC
  blank = t.t(:gc_empty, :name => "Gauntlet")
  eq "a best Gauntlet streak of 5 has earned no emblem yet", gc.tier_text("Gauntlet", 5, [10, 25, 50]), blank
  eq "nor has one of 9", gc.tier_text("Gauntlet", 9, [10, 25, 50]), blank
  eq "10 is the first of the three", gc.tier_text("Gauntlet", 10, [10, 25, 50]),
     t.t(:gc_tier, :name => "Gauntlet", :n => 1, :max => 3)
  saved = $game_variables
  begin
    $game_variables = Hash.new(0).merge(91 => 2)
    SpeakCapture.clear
    GCCard_Scene.new.pbDrawGCCardOne
    truthy "a zero leaves the Club slot blank, and the card reads it that way",
           SpeakCapture.last.to_s.include?(t.t(:gc_empty, :name => "Club"))
  ensure
    $game_variables = saved
  end
end
