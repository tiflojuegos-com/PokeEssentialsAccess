# The hall of fame's reader on the modern screen and on the clones a profile binds it to: a panel or banner that paints
# nothing falls back to a composed line, a clone with no entry animation interrupts, a records hall keeps a figure it
# paints twice, and the closing trainer box leads the congratulation whatever window comes before it.

# Fire Ash's Gauntlet records hall: the record's number and its win count painted as rows of their own, which can be
# the same figure.
class Gauntlet_Scene
  attr_accessor :wins
  def writePokemonData(pk, hall = -1)
    rows = [["No. 025", 32, 298], ["#{pk ? pk.name : '?'} Lv. #{pk ? pk.level : 0}", 320, 298]]
    if hall > -1
      rows += [["Hall of Grandeur No.", 48, -6], [hall.to_s, 262, -6], ["Win count:", 360, -6], [@wins.to_s, 440, -6]]
    end
    pbDrawTextPositions(nil, rows)
    hall
  end
  def pbStartSceneEntry(*a); end
end

# Fire Ash's Practice records hall: each record keeps its run's region and difficulty as two numbers after the team,
# and its header is one row.
class PracticeHall_Scene
  def initialize(team, index); @hallEntry = team; @battlerIndex = index; end
  def writePokemonData(pk, hall = -1)
    rows = [["No. 025", 32, 298], ["#{pk.name} Lv. #{pk.level}", 320, 298]]
    rows += [["Kanto Practice Completion No.#{hall} - Veteran", 120, -6]] if hall > -1
    pbDrawTextPositions(nil, rows)
    hall
  end
  def pbStartSceneEntry(*a); end
end

# A clone whose closing builds an empty window ahead of its trainer box, and no box at all when it has none to show.
class Rematch_Scene
  attr_accessor :box
  def writePokemonData(_pk, hall = -1); hall; end
  def pbStartSceneEntry(*a); end
  def writeTrainerData
    Window_AdvancedTextPokemon.new
    Window_AdvancedTextPokemon.new(@box) if @box
  end
end

# A screen of the family with its banner and no member panel (a hall's title card).
class TitleCard_Scene
  def writeWelcome
    pbDrawTextPositions(nil, [["Hall of Grandeur", 256, 16, 2]])
  end
end

class HallOfFameFamilyGdTest < PokeAccessTest
  # Each clone bound once for the process, as its profile binds it, with whether its panel reader took.
  BOUND = %w[Duet_Scene Challenge_Scene Gauntlet_Scene Rematch_Scene TitleCard_Scene NoSuchHall_Scene].map do |cname|
    [cname, PokeAccess::HallOfFame.bind(cname)]
  end.to_h
  # Fire Ash's Practice records hall, bound apart from the clones above.
  PRACTICE = PokeAccess::HallOfFame.bind("PracticeHall_Scene")

  test "a records hall that keeps its run's numbers after the team counts only the team in the member's place" do
    team = [member("Chispa", 50), member("Lumbre", 50), 1, 1]
    PracticeHall_Scene.new(team, 1).writePokemonData(team[1], 3)
    assert_equal [["No. 025, Lumbre Lv. 50, Kanto Practice Completion No.3 - Veteran, " \
                   "#{PokeAccess::Verbosity.position(2, 2)}", true]], SpeakCapture.log
  end

  test "the modern screen reads its painted panel, queued in the entry" do
    HallOfFame_Scene.new.writePokemonData(member("Chispa", 50), -1)
    assert_equal [["No. 025, Chispa Lv. 50", false]], SpeakCapture.log
  end

  test "what only the sprite shows follows the panel: the form's name, the first form's too, and none without one" do
    { "Plant Cloak" => "No. 025, Chispa Lv. 50, Plant Cloak", " " => "No. 025, Chispa Lv. 50",
      nil => "No. 025, Chispa Lv. 50" }.each do |form, want|
      SpeakCapture.clear
      pk = member("Chispa", 50)
      pk.define_singleton_method(:species_data) { Struct.new(:form_name).new(form) }
      HallOfFame_Scene.new.writePokemonData(pk, -1)
      assert_equal [[want, false]], SpeakCapture.log, "for #{form.inspect}"
    end
  end

  test "binding answers whether the panel reader took: on each clone, not on a screen without panels or one absent" do
    assert_equal({ "Duet_Scene" => true, "Challenge_Scene" => true, "Gauntlet_Scene" => true, "Rematch_Scene" => true,
                   "TitleCard_Scene" => false, "NoSuchHall_Scene" => false }, BOUND)
  end

  test "a clone missing the panel, the banner or the trainer box is not reported as a broken binding" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/Challenge_Scene|Rematch_Scene|TitleCard_Scene/)
  end

  test "a screen with a banner and no member panel still reads its banner" do
    TitleCard_Scene.new.writeWelcome
    assert_equal [["Hall of Grandeur", false]], SpeakCapture.log
  end

  test "a clone whose panel paints nothing names the member by nickname, species and level" do
    t = PokeAccess::I18n
    egg = member("Huevo", 1)
    def egg.egg?; true; end
    [["a nickname", member("Chispa", 50), t.t(:hof_member, :who => "Chispa, Species25", :level => 50)],
     ["no nickname", member("Species25", 50), t.t(:hof_member, :who => "Species25", :level => 50)],
     ["no level", member("Chispa", nil), "Chispa, Species25"],
     ["an egg", egg, t.t(:hof_egg)],
     ["no egg flag at all", Struct.new(:name, :level, :species).new("Chispa", 50, 25),
      t.t(:hof_member, :who => "Chispa, Species25", :level => 50)]].each do |what, pk, want|
      SpeakCapture.clear
      Duet_Scene.new.writePokemonData(pk, 3)
      assert_equal [[want, true]], SpeakCapture.log, "for #{what}"
    end
  end

  test "a clone whose banner paints nothing says the mod's own welcome, queued" do
    Duet_Scene.new.writeWelcome
    assert_equal [[PokeAccess::I18n.t(:hof_welcome), false]], SpeakCapture.log
  end

  test "a clone with no entry animation interrupts, as it is only ever browsed" do
    Challenge_Scene.new.writePokemonData(member("Chispa", 50))
    assert_equal [["Chispa Lv. 50", true]], SpeakCapture.log
  end

  test "a records hall keeps a figure it paints twice, its record's header leading" do
    hall = Gauntlet_Scene.new
    hall.wins = 3
    hall.writePokemonData(member("Chispa", 50), 3)
    assert_equal [["Hall of Grandeur No. 3. No. 025, Chispa Lv. 50, Win count:, 3", true]], SpeakCapture.log
  end

  test "the modern closing trainer box is read row by row, leading its congratulation" do
    HallOfFame_Scene.new.writeTrainerData
    assert_equal [["Name Tester, ID No. 12345, Time 1h 23m, Pokédex 10/20: League champion! Congratulations!", false]],
                 SpeakCapture.log
  end

  test "an empty window built ahead of the trainer box leaves the box to be read" do
    scene = Rematch_Scene.new
    scene.box = "Name<r>Tester<br>Time<r>2h 05m<br>"
    scene.writeTrainerData
    assert_equal [["Name Tester, Time 2h 05m", false]], SpeakCapture.log
  end

  test "a closing with no trainer box leaves the windows built after it alone" do
    Rematch_Scene.new.writeTrainerData
    Window_AdvancedTextPokemon.new("Name<r>Otro<br>")
    assert_nothing_spoken
  end

  private

  # A hall member as the panels read it: nickname, level and species 25, of the usual kind (no egg).
  def member(name, level)
    pk = Poke.build(:name => name, :species => 25)
    pk.level = level
    def pk.egg?; false; end
    pk
  end
end
