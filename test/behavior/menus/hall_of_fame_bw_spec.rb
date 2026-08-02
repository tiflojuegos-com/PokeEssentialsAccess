# The Hall of Fame PC viewer plugin. Entries are stored newest-last but NUMBERED by when they happened, so
# the number on screen is not the index: it is hallOfFameLastNumber + index - size + 1, the plugin's own
# formula, identical in both copies. Announcing the index instead would name the wrong run of the game.
require File.expand_path("../../../plugins/hall_of_fame_bw", File.dirname(__FILE__))

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
    spoke "where in the team", /#{PokeAccess::I18n.t(:hofbw_pos, :n => 2, :tot => 2)}/
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
