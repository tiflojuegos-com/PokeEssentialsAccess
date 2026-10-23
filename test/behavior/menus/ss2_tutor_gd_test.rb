# Soulstones 2's Tutor.net (games/soulstones2/tutor_net.rb): each party panel's tint said in words, and who each move
# browsed suits; and its own screen reader's notice of two voices (games/soulstones2/own_tts.rb).

# Tutor.net's party half, a grid of panel sprites with its own pbChangeSelection: each panel's icon tint (pkmn_comp: 1
# can learn the focused move, 2 cannot, 3 already knows it, 0 an egg or no move focused), and the move list it browses.
class PokemonTutorNet_Scene
  # A party panel, its tint repainted by the scene.
  Panel = Struct.new(:pkmn_comp)
  # The move list window.
  MoveList = Struct.new(:index, :commands)

  attr_reader :sprites
  attr_writer :last_mon_index

  def initialize(party, comps)
    @party = party
    @sprites = { "commands" => MoveList.new(0, ["Placaje", "Rayo", "Surf"]) }
    comps.each_with_index { |c, i| @sprites["pokemon#{i}"] = Panel.new(c) }
  end

  # The grid cursor's move, answering the new index.
  def pbChangeSelection(_key, currentsel); currentsel; end

  # The grid's loop, entered on the member chosen last.
  def pbChoosePokemon; :picked; end

  def update_indicators(_move_list = nil); :drawn; end
  def set_comp(i, v); @sprites["pokemon#{i}"].pkmn_comp = v; end
  def pbSetCommands(commands, index); @sprites["commands"].commands = commands; @sprites["commands"].index = index; end

  # The move list's loop: each step is one frame's tints on the grid and, where given, the move the list is on.
  def pbScene(steps, moves = nil)
    steps.each_with_index do |comps, n|
      @sprites["commands"].index = moves[n] if moves
      comps.each_with_index { |c, i| set_comp(i, c) }
      update_indicators
    end
    :chosen
  end
end

["tutor_net.rb", "own_tts.rb"].each do |f|
  path = File.join(Harness::ROOT, "games", "soulstones2", f)
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class Ss2TutorGdTest < PokeAccessTest
  # The party's names, in party order.
  NAMES = %w[Chispa Brasa Roca Hoja].freeze
  # The name the engine's MapInfos give map 40.
  MAP_40 = "Mapa 40"
  # What a repaint of the tints says in a new session, before the move list first opens: heard as this file loads,
  # ahead of every test, since a visit to the list always leaves it closed.
  FRESH_REPAINT = begin
    SpeakCapture.clear
    PokemonTutorNet_Scene.new([Poke.build(:name => "Chispa")], [1]).update_indicators
    SpeakCapture.log.dup
  ensure
    SpeakCapture.clear
  end

  test "says the focused member by its name and whether it can learn the move, interrupting" do
    { 1 => :tut_can, 2 => :tut_cannot, 3 => :tut_knows }.each do |comp, verdict|
      SpeakCapture.clear
      grid([comp]).pbChangeSelection(nil, 0)
      assert_equal [["Chispa, #{t(verdict)}", true]], SpeakCapture.log, "tint #{comp}"
    end
  end

  test "says the name alone for a panel with no tint, an egg's or with no move focused" do
    grid([0]).pbChangeSelection(nil, 0)
    assert_equal [["Chispa", true]], SpeakCapture.log
  end

  test "says nothing while the cursor stays on the same member" do
    scene = grid([1, 2])
    scene.pbChangeSelection(nil, 1)
    SpeakCapture.clear
    scene.pbChangeSelection(nil, 1)
    assert_nothing_spoken
  end

  test "says the member again when its tint changes under a still cursor" do
    scene = grid([1])
    scene.pbChangeSelection(nil, 0)
    SpeakCapture.clear
    scene.set_comp(0, 3)
    scene.pbChangeSelection(nil, 0)
    assert_equal [["Chispa, #{t(:tut_knows)}", true]], SpeakCapture.log
  end

  test "says nothing for a member with no name, tinted or not" do
    [0, 1].each do |comp|
      PokemonTutorNet_Scene.new([Poke.build(:name => "")], [comp]).pbChangeSelection(nil, 0)
      assert_nothing_spoken "tint #{comp}"
    end
  end

  test "says nothing for a member whose name cannot be read, and the grid keeps its return" do
    scene = PokemonTutorNet_Scene.new([nameless], [1])
    assert_equal 0, scene.pbChangeSelection(nil, 0)
    assert_nothing_spoken
  end

  test "says the cancel entry for a cursor past the members" do
    grid([1]).pbChangeSelection(nil, 1)
    assert_equal [[t(:pc_cancel), true]], SpeakCapture.log
  end

  test "entering the grid says the member chosen last, even when it was the last one said" do
    scene = grid([1, 2])
    scene.pbChangeSelection(nil, 1)
    scene.last_mon_index = 1
    SpeakCapture.clear
    scene.pbChoosePokemon
    assert_equal [["Brasa, #{t(:tut_cannot)}", true]], SpeakCapture.log
  end

  test "entering the grid with no member chosen before says the first" do
    grid([1, 2]).pbChoosePokemon
    assert_equal [["Chispa, #{t(:tut_can)}", true]], SpeakCapture.log
  end

  test "keeps the grid's own returns" do
    scene = grid([1, 2])
    assert_equal [1, :picked], [scene.pbChangeSelection(nil, 1), scene.pbChoosePokemon]
  end

  test "browsing the moves says who can learn each one and who knows it, queued" do
    grid([0, 0, 0]).pbScene([[1, 2, 3]])
    assert_equal [["#{t(:tut_can_list, :names => 'Chispa')}. #{t(:tut_knows_list, :names => 'Roca')}", false]],
                 SpeakCapture.log
  end

  test "names every member a move suits, in party order" do
    grid([0, 0, 0, 0]).pbScene([[1, 3, 1, 3]])
    assert_equal [["#{t(:tut_can_list, :names => 'Chispa, Roca')}. #{t(:tut_knows_list, :names => 'Brasa, Hoja')}", false]],
                 SpeakCapture.log
  end

  test "a move nobody in the party can learn says so, eggs aside" do
    grid([0, 0]).pbScene([[2, 0]])
    assert_equal [[t(:tut_nobody), false]], SpeakCapture.log
  end

  test "a move whose panels all carry no tint says nothing" do
    grid([0, 0]).pbScene([[0, 0]])
    assert_nothing_spoken
  end

  test "leaves a slot with no member out of the names" do
    PokemonTutorNet_Scene.new([Poke.build(:name => "Chispa"), nil], [0, 0]).pbScene([[1, 1]])
    assert_equal [[t(:tut_can_list, :names => "Chispa"), false]], SpeakCapture.log
  end

  test "a member whose name cannot be read leaves the move list running" do
    scene = PokemonTutorNet_Scene.new([Poke.build(:name => "Chispa"), nameless], [0, 0])
    assert_equal :chosen, scene.pbScene([[1, 1]])
  end

  test "a repaint of the same move and tints says nothing" do
    grid([0, 0]).pbScene([[1, 2], [1, 2]])
    assert_equal [[t(:tut_can_list, :names => "Chispa"), false]], SpeakCapture.log
  end

  test "a change of tints on the same move is said again" do
    grid([0, 0]).pbScene([[1, 2], [2, 2]])
    assert_equal [[t(:tut_can_list, :names => "Chispa"), false], [t(:tut_nobody), false]], SpeakCapture.log
  end

  test "the same tints on the next move are said again" do
    grid([0, 0]).pbScene([[2, 2], [2, 2]], [0, 1])
    assert_equal [[t(:tut_nobody), false], [t(:tut_nobody), false]], SpeakCapture.log
  end

  test "the same tints on a list refilled under a still cursor are said again" do
    scene = grid([2, 2])
    PokeAccess::SS2TutorNet.browsing do
      scene.update_indicators
      scene.sprites["commands"].commands = ["Rayo", "Surf"]
      scene.update_indicators
    end
    assert_equal [[t(:tut_nobody), false], [t(:tut_nobody), false]], SpeakCapture.log
  end

  test "a new visit to the move list says its tints even when they match the last visit's" do
    scene = grid([0, 0])
    scene.pbScene([[1, 2]])
    SpeakCapture.clear
    scene.pbScene([[1, 2]])
    assert_equal [[t(:tut_can_list, :names => "Chispa"), false]], SpeakCapture.log
  end

  test "before the move list first opens, a repaint of the tints says nothing" do
    assert_equal [], FRESH_REPAINT
  end

  test "once the move list closes, a repaint of the tints says nothing" do
    scene = grid([0, 0])
    scene.pbScene([[1, 2]])
    SpeakCapture.clear
    scene.set_comp(0, 3)
    scene.update_indicators
    assert_nothing_spoken
  end

  test "a repaint handed its move list, the filter's, says nothing" do
    scene = grid([1])
    PokeAccess::SS2TutorNet.browsing { scene.update_indicators(["RAYO"]) }
    assert_nothing_spoken
  end

  test "leaves the list window to no reader as the filter refills it" do
    scene = grid([1])
    assert_equal false, PokeAccess.dedicated?(scene.sprites["commands"]), "before the refill the list has its reader"
    scene.pbSetCommands(["Rayo"], 0)
    assert_equal true, PokeAccess.dedicated?(scene.sprites["commands"])
  end

  test "keeps the move list's and the repaint's own returns" do
    scene = grid([1])
    assert_equal [:chosen, :drawn], [scene.pbScene([[1]]), scene.update_indicators]
  end

  test "says nothing of two voices while the game's own reader is off" do
    with_game_reader(false) { PokeAccess::SS2OwnTTS.warn_once }
    assert_nothing_spoken
  end

  test "says nothing of two voices in a game with no reader switch" do
    with_game_reader(nil) { PokeAccess::SS2OwnTTS.warn_once }
    assert_nothing_spoken
  end

  test "warns of two voices, queued, while the game's own reader is on" do
    with_game_reader(true) { PokeAccess::SS2OwnTTS.warn_once }
    assert_equal [[t(:ss2_two_voices), false]], SpeakCapture.log
  end

  test "warns of two voices once a session" do
    with_game_reader(true) do
      PokeAccess::SS2OwnTTS.warn_once
      SpeakCapture.clear
      PokeAccess::SS2OwnTTS.warn_once
    end
    assert_nothing_spoken
  end

  test "warns again once the notice is forgotten, as a reloaded game does" do
    with_game_reader(true) do
      PokeAccess::SS2OwnTTS.warn_once
      PokeAccess::SS2OwnTTS.forget
      SpeakCapture.clear
      PokeAccess::SS2OwnTTS.warn_once
    end
    assert_equal [[t(:ss2_two_voices), false]], SpeakCapture.log
  end

  test "entering a map, the notice of two voices follows the map's name" do
    with_game_reader(true) do
      $game_map.map_id = 40
      PokeAccess::Locator.announce_map_change
    end
    assert_equal [[MAP_40, false], [t(:ss2_two_voices), false]], SpeakCapture.log
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # A Tutor.net scene whose party, named from NAMES, carries these tints.
  def grid(comps)
    PokemonTutorNet_Scene.new(comps.each_index.map { |i| Poke.build(:name => NAMES[i]) }, comps)
  end

  # A party member whose name raises, as one of a species the game's data has lost does.
  def nameless
    pk = Poke.build
    pk.define_singleton_method(:name) { raise NoMethodError, "undefined method 'name' for nil" }
    pk
  end

  # Runs the block with the game's own reader switch, TTS_ENABLED, at on (nil: a game without one) and the notice not
  # yet given; the switch is put back and the notice forgotten after.
  def with_game_reader(on)
    had = Object.const_defined?(:TTS_ENABLED, false)
    was = had ? Object.const_get(:TTS_ENABLED, false) : nil
    switch(on)
    PokeAccess::SS2OwnTTS.forget
    yield
  ensure
    switch(was)
    PokeAccess::SS2OwnTTS.forget
  end

  # Sets TTS_ENABLED to on, or takes it away for nil.
  def switch(on)
    Object.send(:remove_const, :TTS_ENABLED) if Object.const_defined?(:TTS_ENABLED, false)
    Object.const_set(:TTS_ENABLED, on) unless on.nil?
  end
end
