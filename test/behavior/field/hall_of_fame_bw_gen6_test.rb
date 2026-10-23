# The gen-6 BW Hall of Fame (plugins/hall_of_fame_bw_gen6.rb; Realidea, Uranium) through its scene's own methods: each
# entrant named as its slide starts, the closing card once it shows, the PC viewer's record and card as painted, and
# the accept key standing for a click on the front entrant while the viewer's loop runs. Neither those methods nor the
# mouse exist when this engine's harness loads the plugin, so its hooks are bound once more after the stand-ins below.

# The game's mouse, which never clicks here.
class Game_Mouse
  def inAreaLeft?(_x, _y, _w, _h); false; end
end

# The scene's methods the plugin reads, down to what they paint: an entrant's slide frame by frame, the closing card
# painted hidden, the PC viewer's record and card, one pass of the viewer's loop asking the mouse about each entrant
# (front first) and keeping the ones clicked, and the scene's end.
class HallOfFameScene
  attr_reader :clicked
  def moveSprite(i); i; end
  def createTrainerBattler
    pbDrawTextPositions(nil, [["¡Felicidades!", 256, 32, 2], ["Ayoub", 16, 320, 0], ["ID No. 12345", 256, 320, 2],
                              ["12:34", 442, 320, 2]])
  end
  def writeNormalDataPC
    n = @hallIndex + 1
    pbDrawTextPositions(nil, [["HALL DE LA FAMA No.", 16, 0, 0], [format("%03d", n), 192, 0, 0],
                              ["#{n}/3", 118, 344, 2]])
  end
  def writePokemonDataPC(_pokemon, hallNumber = -1); hallNumber; end
  def pbPCSelection
    @clicked = (0...@positions.length).select do |i|
      $mouse.inAreaLeft?(@positions[i][0] - 48, @positions[i][1] - 48, 96, 96)
    end
  end
  def pbEndScene; nil; end
end

# The plugin's hooks, evaluated again: its module, which the harness's load of the file defined, and its hook on
# writeTrainerData, which that load bound to the stub's, are blanked out, the lines keeping their numbers.
bw6_path = File.join(Harness::ROOT, "plugins", "hall_of_fame_bw_gen6.rb")
bw6_blank = lambda { |code| "\n" * code.count("\n") }
bw6_trainer_data = /^PokeAccess::Hooks\.\w+\("HallOfFameScene", :writeTrainerData\b.*?^end\r?\n/m
bw6_hooks = Harness.source(bw6_path).sub(/\A.*?^end\r?\n/m, &bw6_blank).sub(bw6_trainer_data, &bw6_blank)
eval(bw6_hooks, TOPLEVEL_BINDING, bw6_path)

class HallOfFameBwGen6Test < PokeAccessTest
  # The viewer's entrants as the scene places them: the front one, one beside it and one behind it in its column.
  POSITIONS = [[256, 250, 1], [100, 200, 0], [256, 150, 0]]
  # The scene's methods the plugin hooks only where a copy has them.
  VIEWER_HOOKS = %w[HallOfFameScene#moveSprite HallOfFameScene#writePokemonDataPC HallOfFameScene#writeNormalDataPC
                    HallOfFameScene#pbPCSelection HallOfFameScene#createTrainerBattler HallOfFameScene#pbEndScene]

  test "an entrant is named as its slide starts, once, queued, however many frames the slide takes" do
    scene = entry_scene
    3.times { scene.moveSprite(0) }
    assert_equal [[t(:pc_slot, :name => "Chispa", :level => 30), false]], SpeakCapture.log
  end

  test "each entrant is named as its own slide starts" do
    scene = entry_scene
    scene.moveSprite(0)
    scene.moveSprite(1)
    assert_equal [t(:pc_slot, :name => "Chispa", :level => 30), t(:pc_slot, :name => "Especie25", :level => 5)],
                 SpeakCapture.lines
  end

  test "the trainer's slide names no one" do
    entry_scene.moveSprite(-1)
    assert_nothing_spoken
  end

  test "the viewer's card reads the species with its sign, the level, nickname, trainer and moves, interrupting" do
    HallOfFameScene.new.writePokemonDataPC(chispa)
    assert_equal [["Especie25 ♂, #{t(:hofbw_level, :n => 30)}, #{t(:hof_nickname, :name => 'Chispa')}, " \
                   "#{t(:hofbw_ot, :name => 'Ash')}, #{t(:sm_moves, :list => 'Mov1, Mov2')}", true]],
                 SpeakCapture.log
  end

  test "a card without a nickname names the Pokemon once, with no sign where none is drawn" do
    HallOfFameScene.new.writePokemonDataPC(plain)
    assert_equal [["Especie25, #{t(:hofbw_level, :n => 5)}", true]], SpeakCapture.log
  end

  test "an egg's card is the egg's word, with no sign and no level" do
    egg = entrant("Huevo", 1, 0, "Ash", [])
    def egg.isEgg?; true; end
    HallOfFameScene.new.writePokemonDataPC(egg)
    assert_equal [["#{t(:pty_egg)}, #{t(:hofbw_ot, :name => 'Ash')}", true]], SpeakCapture.log
  end

  test "brief says the species and the nickname, medium adds the level, full the rest and the sign" do
    level = t(:hofbw_level, :n => 30)
    nick = t(:hof_nickname, :name => "Chispa")
    rest = "#{t(:hofbw_ot, :name => 'Ash')}, #{t(:sm_moves, :list => 'Mov1, Mov2')}"
    assert_equal ["Especie25, #{nick}", "Especie25, #{level}, #{nick}", "Especie25 ♂, #{level}, #{nick}, #{rest}"],
                 vb_levels { PokeAccess::HallOfFameBWGen6.pc_card(chispa) }
  end

  test "the info key keeps the whole card, sign included, whatever the verbosity" do
    PokeAccess::Config.verbosity = :brief
    HallOfFameScene.new.writePokemonDataPC(chispa)
    assert_equal "Especie25 ♂, #{t(:hofbw_level, :n => 30)}, #{t(:hof_nickname, :name => 'Chispa')}, " \
                 "#{t(:hofbw_ot, :name => 'Ash')}, #{t(:sm_moves, :list => 'Mov1, Mov2')}",
                 PokeAccess::Info.info_text
  end

  test "the card leaves the info key when the scene ends" do
    scene = HallOfFameScene.new
    scene.writePokemonDataPC(plain)
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "the viewer's first record is read as painted with its team and the keys, queued" do
    viewer(0).writeNormalDataPC
    assert_equal [["HALL DE LA FAMA No. 001. 1/3. #{t(:hofbw_team, :list => 'Orchynx')}. #{t(:hofbw_pc_keys)}", false]],
                 SpeakCapture.log
  end

  test "the next record is read interrupting, without the keys" do
    scene = viewer(0)
    scene.writeNormalDataPC
    SpeakCapture.clear
    scene.instance_variable_set(:@hallIndex, 2)
    scene.writeNormalDataPC
    assert_equal [["HALL DE LA FAMA No. 003. 3/3. #{t(:hofbw_team, :list => 'Orchynx')}", true]], SpeakCapture.log
  end

  test "in brief the first record leaves the keys out" do
    PokeAccess::Config.verbosity = :brief
    viewer(0).writeNormalDataPC
    assert_equal [["HALL DE LA FAMA No. 001. 1/3. #{t(:hofbw_team, :list => 'Orchynx')}", false]], SpeakCapture.log
  end

  test "while the viewer's loop runs, the accept key clicks the front entrant and only it" do
    scene = viewer(0)
    with_mouse { with_accept { scene.pbPCSelection } }
    assert_equal [0], scene.clicked
  end

  test "without the accept key no entrant is clicked" do
    scene = viewer(0)
    with_mouse { scene.pbPCSelection }
    assert_equal [], scene.clicked
  end

  test "once a record is picked, the accept key clicks nothing" do
    scene = viewer(0)
    scene.instance_variable_set(:@selectedrecord, true)
    with_mouse { with_accept { scene.pbPCSelection } }
    assert_equal [], scene.clicked
  end

  test "an accept key check that fails in the engine clicks no entrant" do
    scene = viewer(0)
    with_mouse { with_failing_keys { scene.pbPCSelection } }
    assert_equal [], scene.clicked
  end

  test "outside the viewer's loop the accept key leaves the mouse alone" do
    scene = viewer(0)
    clicked = with_mouse do
      scene.pbPCSelection
      with_accept { $mouse.inAreaLeft?(208, 202, 96, 96) }
    end
    assert_equal false, clicked
  end

  test "the closing card painted hidden is said once it shows, queued, with the key that ends the scene" do
    scene = HallOfFameScene.new
    scene.createTrainerBattler
    PokeAccess::HallOfFameBWGen6.closing_card(scene)
    assert_equal [["¡Felicidades!, Ayoub, ID No. 12345, 12:34. #{t(:hofbw_card_key)}", false]], SpeakCapture.log
  end

  test "before the closing card is painted nothing is said" do
    PokeAccess::HallOfFameBWGen6.closing_card(HallOfFameScene.new)
    assert_nothing_spoken
  end

  test "the closing card is said once: the frames that follow say nothing" do
    scene = HallOfFameScene.new
    scene.createTrainerBattler
    PokeAccess::HallOfFameBWGen6.closing_card(scene)
    SpeakCapture.clear
    PokeAccess::HallOfFameBWGen6.closing_card(scene)
    assert_nothing_spoken
  end

  test "in brief the closing card leaves its key out" do
    PokeAccess::Config.verbosity = :brief
    scene = HallOfFameScene.new
    scene.createTrainerBattler
    PokeAccess::HallOfFameBWGen6.closing_card(scene)
    assert_equal [["¡Felicidades!, Ayoub, ID No. 12345, 12:34", false]], SpeakCapture.log
  end

  test "a copy without the PC viewer is not reported as a broken binding" do
    assert_equal [], PokeAccess::Hooks.missing & VIEWER_HOOKS
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # A hall entrant: nickname, level, gender number, original trainer and move ids, of species 25.
  def entrant(name, level, gender, ot, move_ids)
    pk = Poke.build(:name => name, :species => 25, :level => level, :gender => gender,
                    :moves => move_ids.map { |id| Struct.new(:id).new(id) })
    pk.define_singleton_method(:ot) { ot }
    pk
  end

  # A male entrant with a nickname, a trainer and two moves (a third slot empty).
  def chispa
    entrant("Chispa", 30, 0, "Ash", [1, 2, 0])
  end

  # A genderless entrant named as its species, with no trainer and no moves.
  def plain
    entrant("Especie25", 5, 2, "", [])
  end

  # The scene as the entry's slides run, with its two entrants.
  def entry_scene
    scene = HallOfFameScene.new
    scene.instance_variable_set(:@hallEntry, [chispa, plain])
    scene
  end

  # The PC viewer on a record (0 the first), its team and entrants placed, none picked yet.
  def viewer(index)
    scene = HallOfFameScene.new
    scene.instance_variable_set(:@hallIndex, index)
    scene.instance_variable_set(:@hallEntry, [Struct.new(:name).new("Orchynx")])
    scene.instance_variable_set(:@positions, POSITIONS)
    scene.instance_variable_set(:@selectedrecord, false)
    scene
  end

  # The block's value with the game's mouse in $mouse, put back after.
  def with_mouse
    saved = $mouse
    $mouse = Game_Mouse.new
    yield
  ensure
    $mouse = saved
  end

  # The block's value with the accept key pressed this frame, the stub's Input.trigger? put back after.
  def with_accept
    stub = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |*keys| keys == [Input::C] || stub.call(*keys) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, stub)
  end

  # The block's value with Input.trigger? raising, as an engine whose input fails; the stub's put back after.
  def with_failing_keys
    stub = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |*_keys| raise NoMethodError, "trigger?" }
    yield
  ensure
    Input.define_singleton_method(:trigger?, stub)
  end
end
