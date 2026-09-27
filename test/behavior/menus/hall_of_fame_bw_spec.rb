# The Hall of Fame PC viewer plugin: an entry's number is the plugin's hallOfFameLastNumber + index - size + 1, not
# the index. Not required here: the harness loads it, and a second load reassigns its constants.

class FakeHofGlobal
  attr_accessor :hallOfFame, :hallOfFameLastNumber
  def initialize(entries, last); @hallOfFame = entries; @hallOfFameLastNumber = last; end
end

class FakeHofMon
  attr_reader :name, :speciesName, :level
  def initialize(name, species, level); @name = name; @speciesName = species; @level = level; end
end

Suite.define("hall of fame viewer: the entry number is the game's, and each member is placed in its team") do
  hof = PokeAccess::HallOfFameBW
  saved = $PokemonGlobal
  begin
    teams = [[FakeHofMon.new("Chispa", "Pikachu", 40)],
             [FakeHofMon.new("Bulbi", "Bulbasaur", 55), FakeHofMon.new("Rocoso", "Onix", 51)]]
    $PokemonGlobal = FakeHofGlobal.new(teams, 7)

    eq "the newest entry carries the latest number", hof.entry_number(1), 7
    eq "and the one before it is the run before", hof.entry_number(0), 6

    scene = Object.new
    scene.instance_variable_set(:@hallEntry, teams[1])
    scene.instance_variable_set(:@hallIndex, 1)
    scene.instance_variable_set(:@pokemonIndex, 1)

    SpeakCapture.clear
    hof.read(scene)
    spoke "the entry number", /#{PokeAccess::I18n.t(:hofbw_entry, :n => 7)}/
    spoke "where in the team", /#{PokeAccess::I18n.t(:list_pos, :i => 2, :n => 2)}/
    spoke "the nickname and the species, which differ here", /Rocoso.*Onix/
    spoke "and the level", /#{PokeAccess::I18n.t(:hofbw_level, :n => 51)}/

    SpeakCapture.clear
    hof.read(scene)
    silent "a redraw on the same member stays quiet"

    SpeakCapture.clear
    scene.instance_variable_set(:@pokemonIndex, 0)
    hof.read(scene)
    spoke "moving along the team speaks the next one", /Bulbi/
  ensure
    $PokemonGlobal = saved
  end
end

Suite.define("hall of fame viewer: a member at the Hall of Fame reading's level, the whole card on the info key") do
  hof = PokeAccess::HallOfFameBW
  saved = $PokemonGlobal
  begin
    team = [FakeHofMon.new("Bulbi", "Bulbasaur", 55), FakeHofMon.new("Rocoso", "Onix", 51)]
    $PokemonGlobal = FakeHofGlobal.new([team], 3)
    scene = Object.new
    scene.instance_variable_set(:@hallEntry, team)
    scene.instance_variable_set(:@hallIndex, 0)
    level = PokeAccess::I18n.t(:hofbw_level, :n => 51)
    rows = vb_levels do
      PokeAccess::Cursor.reset(scene, :hof)
      scene.instance_variable_set(:@pokemonIndex, 1)
      SpeakCapture.clear
      hof.read(scene)
      SpeakCapture.last
    end
    truthy "brief: the nickname and the species, not the level", rows[0] =~ /Rocoso.*Onix/ && !rows[0].include?(level)
    truthy "medium: and the level", rows[1].include?(level)
    truthy "the info key keeps the level", PokeAccess::Info.info_text.to_s.include?(level)

    entry = PokeAccess::I18n.t(:hofbw_entry, :n => 3)
    PokeAccess::Config.verbosity = :brief
    PokeAccess::Cursor.reset(scene, :hof)
    scene.instance_variable_set(:@pokemonIndex, 0)
    SpeakCapture.clear
    hof.read(scene)
    truthy "brief names the entry as the cursor reaches it", SpeakCapture.last.include?(entry)
    scene.instance_variable_set(:@pokemonIndex, 1)
    SpeakCapture.clear
    hof.read(scene)
    truthy "and leaves it out while the cursor stays in it", !SpeakCapture.last.include?(entry)
  ensure
    $PokemonGlobal = saved
    PokeAccess::Config.verbosity = :full
  end
end
