# Reborn's own screens and what rv_common reads of its engine: the map names the engine keeps in $cache, the Inspect
# report on the info key, the randomizer's opening line and the Move Tutor app of the Pokegear.
Harness.load_common("rv_common")
module RebornScreensSpec
  Cache = Struct.new(:pkmn, :moves, :abil, :mapinfos)
  MapInfo = Struct.new(:name)
  MoveData = Struct.new(:move, :type, :maxpp)
  Member = Struct.new(:name)
  Trainer = Struct.new(:party)
  Window = Struct.new(:text)

  class List
    attr_accessor :index, :active
    def initialize; @index = 0; @active = true; end
  end
end

class MoveTutorScene
  def initialize(moves)
    @moves = moves
    @sprites = { "commands" => RebornScreensSpec::List.new }
  end

  def pbUpdate; nil; end
end

class PokemonBag
  def self.pbPartyCanLearnThisMove?(move)
    move == :SURF ? [1, 2, 0] : [0, 0, 0]
  end
end

Suite.define("reborn: map names, the Inspect report, the randomizer and the Move Tutor app") do
  had_cache = $cache
  had_trainer = $Trainer
  loc = PokeAccess::Locator
  had_infos = loc.instance_variable_get(:@mapinfos)
  begin
    $cache = RebornScreensSpec::Cache.new({}, { :SURF => RebornScreensSpec::MoveData.new(:SURF, :WATER, 15),
                                               :CUT => RebornScreensSpec::MoveData.new(:CUT, :NORMAL, 30) }, {},
                                          { 5 => RebornScreensSpec::MapInfo.new("Opal Ward") })
    loc.instance_variable_set(:@mapinfos, nil)
    eq "the engine's map infos come from its $cache", PokeAccess::DataRV.map_infos[5].name, "Opal Ward"
    Harness.with_provider(PokeAccess::DataRV) do
      eq "and the locator names a map through them, the engine's provider serving", loc.map_name(5), "Opal Ward"
    end

    rows = ["Type: Water", "Attack:               55  ", nil, "Crit. Rate:    4.2%    +0/3", "Revealed Moves:", "Surf:  15 PP left"]
    eq "the Inspect report reads whole, its message first and each line without its padding",
       PokeAccess::InspectRV.report_text(RebornScreensSpec::Window.new("Inspecting Lapras:"), rows),
       "Inspecting Lapras: Type: Water. Attack: 55. Crit. Rate: 4.2% +0/3. Revealed Moves: Surf: 15 PP left"

    SpeakCapture.clear
    PokeAccess::RandomizerRV.announce
    eq "the randomizer says its keys and how to leave", SpeakCapture.lines,
       [PokeAccess::I18n.t(:rv_randomizer_keys)]

    base = File.expand_path("../../../games/reborn", File.dirname(__FILE__))
    load File.join(base, "move_tutor.rb")
    $Trainer = RebornScreensSpec::Trainer.new([RebornScreensSpec::Member.new("Lapras"),
                                               RebornScreensSpec::Member.new("Vaporeon"),
                                               RebornScreensSpec::Member.new("Pidgey")])
    scene = MoveTutorScene.new([:SURF, :CUT])
    list = scene.instance_variable_get(:@sprites)["commands"]
    SpeakCapture.clear
    scene.pbUpdate
    spoke "the focused move's PP follows its name", /PP 15/
    spoke "and who can learn it", /#{Regexp.escape(PokeAccess::I18n.t(:tut_can_list, :names => "Lapras"))}/
    spoke "and who knows it", /#{Regexp.escape(PokeAccess::I18n.t(:tut_knows_list, :names => "Vaporeon"))}/
    eq "queued behind the name", SpeakCapture.log.map { |l| l[1] }, [false]
    SpeakCapture.clear
    scene.pbUpdate
    silent "once per move"
    list.index = 1
    scene.pbUpdate
    spoke "a move nobody can learn says so", /#{Regexp.escape(PokeAccess::I18n.t(:tut_nobody))}/
    SpeakCapture.clear
    list.active = false
    list.index = 0
    scene.pbUpdate
    silent "nothing while the list is not the one with the cursor"
  ensure
    $cache = had_cache
    $Trainer = had_trainer
    loc.instance_variable_set(:@mapinfos, had_infos)
  end
end
