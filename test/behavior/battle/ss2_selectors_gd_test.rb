# Soulstones 2's battle carousels (its edited Pokeball UI, games/soulstones2/battle_selectors.rb): the Poke Ball picker
# and the Quick party switch, rows of sprites under a painted caption, and the Yes/No question they ask. Gamedata pass.

module Battle
  class Scene
    def pbSelectBallInfo(_idx, _pocket); :picked; end
    def pbUpdateBallSelection(_items, _index, _show_desc = false); :drawn; end
    def pbSelectPartyInfo(_idx, _can_cancel); :switched; end
    # Paints the row: the key hints and the focused member's caption, and with the extra panel a row per move
    # (@panel_rows, a test's stand-in for what the panel draws).
    def pbUpdatePartySelection(party, index, show_desc = false)
      pk = party[index]
      caption = pk ? "#{pk.name} [Lv.#{pk.level}]" : "Return"
      hints = [["USE: Switch", 50, 0], [show_desc ? "ACT: Summary" : "SPC: Extra", 400, 0]]
      pbDrawTextPositions(nil, hints + [[caption, 256, 0]])
      (@panel_rows || ["[+] Placaje [o]"]).each { |row| drawTextEx(nil, 10, 0, 500, 2, row) } if show_desc && pk
      :drawn
    end
    def pbShowCommandsUpper(_msg, _commands, _default, _show_desc); 0; end
    def pbPartySummary(_index, _party, _inbattle = false); :summary; end
  end
end

path = File.join(Harness::ROOT, "games", "soulstones2", "battle_selectors.rb")
eval(Harness.source(path), TOPLEVEL_BINDING, path)

class Ss2SelectorsGdTest < PokeAccessTest
  # The ball row as the picker passes it: an empty entry at both ends, the way back.
  BALLS = [[nil], [:POKEBALL, 12], [:ULTRABALL, 3], [:PREMIERBALL, 1], [nil]]

  # The item data the engine answers for those balls: [name, description].
  BALL_DATA = { :POKEBALL => ["Poké Ball", "Una Ball para atrapar Pokémon."],
                :ULTRABALL => ["Ultra Ball", "Una Ball de alto rendimiento."], :PREMIERBALL => ["Honor Ball", ""] }

  Item = Struct.new(:name, :description)
  Foe = Struct.new(:index, :name)
  FoeBattle = Struct.new(:allBattlers)

  test "opening the ball picker queues the focused ball with how many are left" do
    ball_picker do |scene|
      scene.pbUpdateBallSelection(BALLS, 1, false)
      assert_equal [[ball(:POKEBALL, 12), false]], SpeakCapture.log
    end
  end

  test "moving along the ball row reads the next ball, interrupting" do
    ball_picker do |scene|
      scene.pbUpdateBallSelection(BALLS, 1, false)
      SpeakCapture.clear
      scene.pbUpdateBallSelection(BALLS, 2, false)
      assert_equal [[ball(:ULTRABALL, 3), true]], SpeakCapture.log
    end
  end

  test "the details toggle adds the ball's description without a move" do
    ball_picker do |scene|
      scene.pbUpdateBallSelection(BALLS, 2, false)
      SpeakCapture.clear
      scene.pbUpdateBallSelection(BALLS, 2, true)
      assert_equal [["#{ball(:ULTRABALL, 3)}. Una Ball de alto rendimiento.", true]], SpeakCapture.log
    end
  end

  test "a ball with no description is said alone with the details on" do
    ball_picker do |scene|
      scene.pbUpdateBallSelection(BALLS, 3, true)
      assert_equal [ball(:PREMIERBALL, 1)], SpeakCapture.lines
    end
  end

  test "the empty entries at both ends of the row are the way back" do
    [0, 4].each do |index|
      ball_picker do |scene|
        SpeakCapture.clear
        scene.pbUpdateBallSelection(BALLS, index, false)
        assert_equal [t(:dbk_back)], SpeakCapture.lines, "entry #{index}"
      end
    end
  end

  test "a ball whose name the engine cannot give is skipped, and the next one is read" do
    broken = Object.new
    def broken.name; raise NoMethodError, "name"; end
    row = [[nil], [:BROKENBALL, 2], [:POKEBALL, 12]]
    ball_picker(:BROKENBALL => broken) do |scene|
      scene.pbUpdateBallSelection(row, 1, false)
      scene.pbUpdateBallSelection(row, 2, false)
      assert_equal [ball(:POKEBALL, 12)], SpeakCapture.lines
    end
  end

  test "a redraw on the same ball says nothing" do
    ball_picker do |scene|
      scene.pbUpdateBallSelection(BALLS, 1, false)
      SpeakCapture.clear
      scene.pbUpdateBallSelection(BALLS, 1, false)
      assert_nothing_spoken
    end
  end

  test "reopening the picker reads its ball again, queued" do
    ball_picker do |scene|
      scene.pbUpdateBallSelection(BALLS, 1, false)
      SpeakCapture.clear
      scene.pbSelectBallInfo(0, 3)
      scene.pbUpdateBallSelection(BALLS, 1, false)
      assert_equal [[ball(:POKEBALL, 12), false]], SpeakCapture.log
    end
  end

  test "opening the quick switch queues the member's caption, its hit points and the key hints" do
    scene = quick_switch
    scene.pbUpdatePartySelection(party, 1, false)
    assert_equal [["Pika [Lv.20], #{hp(45, 60)}, USE: Switch, SPC: Extra", false]], SpeakCapture.log
  end

  test "moving to a fainted member says it fainted, without the hints again, interrupting" do
    scene = quick_switch
    scene.pbUpdatePartySelection(party, 1, false)
    SpeakCapture.clear
    scene.pbUpdatePartySelection(party, 2, false)
    assert_equal [["Onix [Lv.22], #{t(:pk_fainted)}", true]], SpeakCapture.log
  end

  test "the way back at the end of the row is said as painted" do
    scene = quick_switch
    scene.pbUpdatePartySelection(party, 1, false)
    SpeakCapture.clear
    scene.pbUpdatePartySelection(party, 3, false)
    assert_equal [["Return", true]], SpeakCapture.log
  end

  test "a redraw of the same member says nothing" do
    scene = quick_switch
    scene.pbUpdatePartySelection(party, 1, false)
    SpeakCapture.clear
    scene.pbUpdatePartySelection(party, 1, false)
    assert_nothing_spoken
  end

  test "a member is fainted at zero hit points, not at one" do
    { 1 => "Pika [Lv.20], #{hp(1, 60)}", 0 => "Pika [Lv.20], #{t(:pk_fainted)}" }.each do |now, want|
      scene = quick_switch
      pika = Poke.build(:name => "Pika", :level => 20, :hp => now, :totalhp => 60)
      scene.pbUpdatePartySelection([nil, pika], 1, false)
      assert_equal "#{want}, USE: Switch, SPC: Extra", SpeakCapture.last, "#{now} hit points"
    end
  end

  test "a member whose hit points cannot be read is passed over, and the next one is read as the first" do
    broken = Poke.build(:name => "Pika", :level => 20)
    def broken.hp; raise NoMethodError, "hp"; end
    row = [nil, broken, party[2]]
    scene = quick_switch
    scene.pbUpdatePartySelection(row, 1, false)
    assert_nothing_spoken "the member with no readable hit points"
    scene.pbUpdatePartySelection(row, 2, false)
    assert_equal [["Onix [Lv.22], #{t(:pk_fainted)}, USE: Switch, SPC: Extra", false]], SpeakCapture.log,
                 "the next member, queued with the key hints as on opening"
  end

  test "a member's status problem is said in place of its Pokerus" do
    { 0 => "Pika [Lv.20], #{hp(45, 60)}, #{t(:pk_pokerus)}", :NONE => "Pika [Lv.20], #{hp(45, 60)}, #{t(:pk_pokerus)}",
      :POISON => "Pika [Lv.20], #{hp(45, 60)}, #{GameData::Status.get(:POISON).name}" }.each do |status, want|
      pika = Poke.build(:name => "Pika", :level => 20, :hp => 45, :totalhp => 60, :status => status)
      def pika.pokerusStage; 1; end
      scene = quick_switch
      scene.pbUpdatePartySelection([nil, pika], 1, false)
      assert_equal "#{want}, USE: Switch, SPC: Extra", SpeakCapture.last, "status #{status.inspect}"
    end
  end

  test "the quick switch is said at the party reading's level" do
    pika = Poke.build(:name => "Pika", :level => 20, :hp => 45, :totalhp => 60)
    def pika.pokerusStage; 1; end
    scene = quick_switch
    rows = vb_levels do
      scene.pbSelectPartyInfo(0, true)
      SpeakCapture.clear
      scene.pbUpdatePartySelection([nil, pika], 1, false)
      SpeakCapture.last
    end
    assert_equal ["Pika, #{hp(45, 60)}",
                  "Pika [Lv.20], #{hp(45, 60)}, USE: Switch, SPC: Extra",
                  "Pika [Lv.20], #{hp(45, 60)}, #{t(:pk_pokerus)}, USE: Switch, SPC: Extra"], rows,
                 "brief: the name and the hit points; medium: the caption and the keys; full: and the Pokerus"
  end

  test "the extra panel adds each move's verdict on each foe, and the hints it changed" do
    scene = quick_switch
    scene.pbUpdatePartySelection(party, 1, false)
    SpeakCapture.clear
    scene.pbUpdatePartySelection(party, 1, true)
    assert_equal [["Pika [Lv.20], #{hp(45, 60)}, Placaje: #{versus('Rival A', :mv_eff_super)}, " \
                   "#{versus('Rival B', :mv_eff_neutral)}, USE: Switch, ACT: Summary", true]], SpeakCapture.log
  end

  test "each mark the extra panel draws says its effectiveness" do
    { "[x]" => :mv_eff_none, "[--]" => :mv_eff_barely, "[-]" => :mv_eff_weak, "[o]" => :mv_eff_neutral,
      "[+]" => :mv_eff_super, "[++]" => :mv_eff_hyper, "[?]" => :mv_eff_unknown }.each do |mark, key|
      assert_equal with_panel("Placaje: #{t(key)}"), panel(["#{mark} Placaje"]), "mark #{mark}"
    end
  end

  test "the extra panel names only the foes' side, in order" do
    unplaced = Struct.new(:name).new("Sin sitio")
    foes = [Foe.new(0, "Pika"), unplaced, Foe.new(1, "Rival A"), nil, Foe.new(2, "Chu"), Foe.new(3, "Rival B")]
    assert_equal with_panel("Placaje: #{versus('Rival A', :mv_eff_weak)}, #{versus('Rival B', :mv_eff_none)}"),
                 panel(["[-] Placaje [x]"], foes)
  end

  test "a foe with no name leaves its verdict bare" do
    assert_equal with_panel("Placaje: #{versus('Rival A', :mv_eff_super)}, #{t(:mv_eff_neutral)}"),
                 panel(["[+] Placaje [o]"], [Foe.new(1, "Rival A"), Foe.new(3, "")])
  end

  test "a panel row with no mark is left out" do
    assert_equal with_panel("Placaje: #{t(:mv_eff_super)}, Danza Espada: #{t(:mv_eff_none)}"),
                 panel(["PP 35/35", "[+] Placaje", "[x] Danza Espada"], [Foe.new(1, "Rival A")])
  end

  test "coming back from a member's summary says that member again, queued" do
    scene = quick_switch
    scene.pbUpdatePartySelection(party, 1, true)
    scene.pbPartySummary(1, party, true)
    SpeakCapture.clear
    scene.pbUpdatePartySelection(party, 1, true)
    assert_equal [["Pika [Lv.20], #{hp(45, 60)}, Placaje: #{versus('Rival A', :mv_eff_super)}, " \
                   "#{versus('Rival B', :mv_eff_neutral)}", false]], SpeakCapture.log
  end

  test "the focused member is what the info key describes" do
    pika = party[1]
    scene = quick_switch
    scene.pbUpdatePartySelection([nil, pika], 1, false)
    assert_equal PokeAccess::Info.pokemon_info(pika), PokeAccess::Info.info_text
  end

  test "the switch question is read before its Yes and No, queued" do
    Battle::Scene.new.pbShowCommandsUpper("Would you like to switch in Pika?", %w[Yes No], 1, false)
    assert_equal [["Would you like to switch in Pika?", false]], SpeakCapture.log
  end

  test "the switch question still answers what the game's does" do
    assert_equal 0, Battle::Scene.new.pbShowCommandsUpper("Would you like to switch in Onix?", %w[Yes No], 1, false)
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  # The hit points as the member's bar shows them.
  def hp(now, total); PokeAccess::Battle.hp_phrase(now, total, true); end

  def ball(id, count); t(:dbk_ball, :name => BALL_DATA[id][0], :n => count); end

  def versus(name, key); t(:mv_eff_vs, :name => name, :eff => t(key)); end

  # The row the quick switch shows: the way back at both ends, Pika and a fainted Onix between.
  def party
    [nil, Poke.build(:name => "Pika", :level => 20, :hp => 45, :totalhp => 60, :gender => 1),
     Poke.build(:name => "Onix", :level => 22, :hp => 0, :totalhp => 70), nil]
  end

  # A scene with the ball picker just opened, given to the block while the engine answers BALL_DATA for the balls,
  # extra's own objects for its ids, and nil for anything else, as it does for an id it does not have.
  def ball_picker(extra = {})
    meta = GameData::Item.singleton_class
    meta.send(:alias_method, :pa_ss2_try_get, :try_get)
    meta.send(:define_method, :try_get) { |id| extra[id] || ((d = BALL_DATA[id]) ? Item.new(*d) : nil) }
    scene = Battle::Scene.new
    scene.pbSelectBallInfo(0, 3)
    yield scene
  ensure
    meta.send(:alias_method, :try_get, :pa_ss2_try_get)
    meta.send(:remove_method, :pa_ss2_try_get)
  end

  # A scene with the quick switch just opened, against Rival A and Rival B.
  def quick_switch(foes = [Foe.new(1, "Rival A"), Foe.new(3, "Rival B")])
    scene = Battle::Scene.new
    scene.instance_variable_set(:@battle, FoeBattle.new(foes))
    scene.pbSelectPartyInfo(0, true)
    scene
  end

  # What the quick switch says for Pika with the extra panel open, its rows painted as given, against foes.
  def panel(rows, foes = [Foe.new(1, "Rival A"), Foe.new(3, "Rival B")])
    scene = quick_switch(foes)
    scene.instance_variable_set(:@panel_rows, rows)
    scene.pbUpdatePartySelection(party, 1, true)
    SpeakCapture.last
  end

  # Pika's line on opening with the extra panel: caption, hit points, the panel's verdicts and the key hints.
  def with_panel(verdicts)
    "Pika [Lv.20], #{hp(45, 60)}, #{verdicts}, USE: Switch, ACT: Summary"
  end
end
