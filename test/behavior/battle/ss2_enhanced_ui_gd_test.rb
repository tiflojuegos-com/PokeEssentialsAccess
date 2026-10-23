# Soulstones 2's Enhanced UI 1.1.2, old and edited, read from its profile through 1.1.2's signatures: the move panel,
# the battler panel and the selection grid, each said as the game paints it.
module Battle
  class Scene
    attr_accessor :moveUIToggle, :infoUIToggle, :battle
    attr_writer :figures, :description, :effect_frames, :flag_frames, :effect_rows, :text_rows

    # 1.1.2 as the game overrides it: (battler, index), where the current release takes (battler, specialAction, cw).
    # Draws the flag icons and the effectiveness strip, then the name, the labels and the power, accuracy and effect
    # chance last (text_rows, when given, is the whole batch instead), then the description underneath.
    def pbUpdateMoveInfoWindow(battler, index)
      return if !@moveUIToggle
      pbDrawMoveFlagIcons(0, 0, nil)
      pbDrawTypeEffectiveness(0, 0, nil, nil, battler)
      power, accuracy, chance = @figures || ["90", "100", "---"]
      rows = [["Placaje", 10, 8], ["Pot:", 20, 10], ["Prec:", 20, 39], ["Efec:", 30, 39],
              [power, 40, 10], [accuracy, 40, 39], [chance, 50, 39]]
      pbDrawTextPositions(nil, @text_rows || rows)
      drawTextEx(nil, 10, 70, 400, 2, @description || "Un ataque fisico de embestida.")
      index
    end

    # The strip over each foe as [file, x, y, frame * 64, 0, 64, 76] rows, the frame being the verdict; frames given
    # as anything but an Array come back as they are.
    def pbDrawTypeEffectiveness(_x, _y, _move, _type, _user)
      return @effect_frames unless @effect_frames.nil? || @effect_frames.is_a?(Array)
      (@effect_frames || []).map { |f| ["effectiveness_ss2", 0, 0, f * 64, 0, 64, 76] }
    end

    # The flag icons as [file, x, y, frame * 26, 0, 26, 28] rows in the order the panel draws them; frames given as
    # anything but an Array come back as they are.
    def pbDrawMoveFlagIcons(_x, _y, _move)
      return @flag_frames unless @flag_frames.nil? || @flag_frames.is_a?(Array)
      (@flag_frames || []).map { |f| ["icons", 5, 32, f * 26, 0, 26, 28] }
    end

    # 1.1.2: (battler), where the current release takes (battler, effects, idxEffect = 0).
    def pbUpdateBattlerInfo(battler)
      pbAddEffectsDisplay(0, 0, 0, battler)
      battler
    end

    # [images, text rows], a name row and a count row per effect; rows given as anything but an Array come back as
    # the text rows as they are.
    def pbAddEffectsDisplay(_x, _y, _panel_x, _battler)
      rows = @effect_rows || []
      return [[], rows] unless rows.is_a?(Array)
      [[], rows.map { |n, c| [[n, 321, 140, 2, nil, nil], [c, 425, 140, 2, nil, nil]] }.flatten(1)]
    end

    # Confirming, cancelling or ending the fight menu hides the move panel without repainting it.
    def pbHideMoveInfo; @moveUIToggle = false; end

    # 1.1.2: ([side, i], select), where the current release takes (idxSide, idxPoke, select).
    def pbUpdateBattlerSelection(index, select = false); [index, select]; end
    def pbSelectBattlerInfo; nil; end
    def pbToggleBattleInfo; nil; end
  end
end
eval(Harness.source(File.join(Harness::ROOT, "games/soulstones2/enhanced_ui.rb")), TOPLEVEL_BINDING,
     File.join(Harness::ROOT, "games/soulstones2/enhanced_ui.rb"))

class Ss2EnhancedUiGdTest < PokeAccessTest
  I18n = PokeAccess::I18n
  Reader = PokeAccess::SS2EnhancedUI
  MALE = "♂"
  FEMALE = "♀"
  DESC = "Un ataque fisico de embestida."
  # The move panel's memory in the fight menu reader, which Reset leaves alone.
  PANEL_STATE = [:@fight_line, :@heard, :@panel_shut]

  # Each test starts with the panel memory of a fresh battle; teardown puts back what was there.
  def setup
    super
    @panel_state = PANEL_STATE.map { |v| PokeAccess::BattleScene.instance_variable_get(v) }
    PANEL_STATE.each { |v| PokeAccess::BattleScene.instance_variable_set(v, nil) }
  end

  def teardown
    PANEL_STATE.zip(@panel_state).each { |v, was| PokeAccess::BattleScene.instance_variable_set(v, was) }
    super
  end

  test "says the effect chance the panel paints, and none where it paints ---" do
    { "---" => nil, "30%" => I18n.t(:mv_effect, :n => "30%") }.each do |chance, part|
      SpeakCapture.clear
      open_panel(tackler, :figures => ["90", "100", chance])
      assert_equal [[panel_line(:chance => part), false]], SpeakCapture.log, "for #{chance.inspect}"
    end
  end

  test "words a power of --- as no damage, ??? as variable, and an accuracy of --- as never missing" do
    {
      ["---", "100"] => { :power => I18n.t(:mv_power, :p => I18n.t(:mv_power_none)) },
      ["???", "100"] => { :power => I18n.t(:mv_power, :p => I18n.t(:mv_power_var)) },
      ["90", "---"] => { :accuracy => I18n.t(:mv_acc, :a => I18n.t(:mv_acc_perfect)) }
    }.each do |(power, accuracy), parts|
      SpeakCapture.clear
      open_panel(tackler, :figures => [power, accuracy, "---"])
      assert_equal [[panel_line(parts), false]], SpeakCapture.log, "for #{power} and #{accuracy}"
    end
  end

  test "gives a status move no power" do
    open_panel(tackler(2))
    assert_equal [[panel_line(:category => I18n.t(:cat_status), :power => nil), false]], SpeakCapture.log
  end

  test "says the type the move calculates, else the one it lists" do
    { :ELECTRIC => "TypeELECTRIC", nil => "TypeNORMAL" }.each do |calc, name|
      SpeakCapture.clear
      open_panel(tackler(0, calc))
      assert_equal [[panel_line(:type => I18n.t(:mv_type, :t => name)), false]], SpeakCapture.log,
                   "calculated as #{calc.inspect}"
    end
  end

  test "ends the line at the verdict when the panel writes no description" do
    open_panel(tackler, :effect_frames => [3], :description => "")
    assert_equal [[panel_line(:verdict => I18n.t(:mv_eff_super), :description => nil), false]], SpeakCapture.log
  end

  test "takes the figures from the panel's last three rows, and says nothing for a panel that painted fewer" do
    figures = [["90", 40, 10], ["100", 40, 39], ["---", 50, 39]]
    { figures => [[panel_line, false]], figures.drop(1) => [] }.each do |rows, log|
      SpeakCapture.clear
      open_panel(tackler, :text_rows => rows)
      assert_equal log, SpeakCapture.log, "#{rows.length} rows painted"
    end
  end

  test "names a move the battler does not answer for by the name the panel painted" do
    open_panel(answering(:index => 0, :moves => []))
    assert_equal [[panel_line(:type => nil, :category => nil), false]], SpeakCapture.log
  end

  test "leaves out a move name that is blank" do
    blank = answering(:name => "", :category => 0, :type => :NORMAL, :pbCalcType => :NORMAL)
    open_panel(answering(:index => 0, :moves => [blank]))
    assert_equal [[panel_line(:name => nil), false]], SpeakCapture.log
  end

  test "says each frame of the strip as its verdict, and a frame past the seven as unknown" do
    { 0 => :mv_eff_unknown, 1 => :mv_eff_none, 2 => :mv_eff_weak, 3 => :mv_eff_super, 4 => :mv_eff_neutral,
      5 => :mv_eff_hyper, 6 => :mv_eff_barely, 7 => :mv_eff_unknown }.each do |frame, key|
      SpeakCapture.clear
      open_panel(tackler, :effect_frames => [frame])
      assert_equal [[panel_line(:verdict => I18n.t(key)), false]], SpeakCapture.log, "frame #{frame}"
    end
  end

  test "says the verdict alone when the strip covers a single foe, without naming it" do
    battle = answering(:allBattlers => [answering(:index => 0, :name => "Chispa", :fainted? => false),
                                        answering(:index => 1, :name => "Rival", :fainted? => false)])
    open_panel(tackler, :effect_frames => [3], :battle => battle)
    assert_equal [[panel_line(:verdict => I18n.t(:mv_eff_super)), false]], SpeakCapture.log
  end

  test "names each foe before its verdict when there are several, leaving out own and fainted ones and blank names" do
    battle = answering(:allBattlers => [answering(:index => 0, :name => "Chispa", :fainted? => false),
                                        answering(:index => 1, :name => "Rival", :fainted? => false),
                                        answering(:index => 3, :name => "Caido", :fainted? => true),
                                        answering(:index => 5, :name => "", :fainted? => false)])
    open_panel(tackler, :effect_frames => [3, 1], :battle => battle)
    verdict = [I18n.t(:mv_eff_vs, :name => "Rival", :eff => I18n.t(:mv_eff_super)), I18n.t(:mv_eff_none)].join(", ")
    assert_equal [[panel_line(:verdict => verdict), false]], SpeakCapture.log
  end

  test "counts as no foe a battler that cannot say its slot or whether it fainted" do
    battle = answering(:allBattlers => [answering(:name => "Anonimo", :fainted? => false),
                                        answering(:index => 1, :name => "Dudoso"),
                                        answering(:index => 3, :name => "Rival", :fainted? => false),
                                        answering(:index => 5, :name => "Otro", :fainted? => false)])
    open_panel(tackler, :effect_frames => [3, 1], :battle => battle)
    verdict = [I18n.t(:mv_eff_vs, :name => "Rival", :eff => I18n.t(:mv_eff_super)),
               I18n.t(:mv_eff_vs, :name => "Otro", :eff => I18n.t(:mv_eff_none))].join(", ")
    assert_equal [[panel_line(:verdict => verdict), false]], SpeakCapture.log
  end

  test "says the flag icons it drew in their order, leaving out the frames that name nothing" do
    {
      [2, 3, 4, 9] => [I18n.t(:dbk_flag_noprotect, :move => "MovePROTECT"),
                       I18n.t(:dbk_flag_nomirror, :move => "MoveMIRRORMOVE"), I18n.t(:dbk_flag_contact),
                       I18n.t(:dbk_flag_punch)],
      [5, 16] => [I18n.t(:dbk_flag_minimize, :move => "MoveMINIMIZE"), I18n.t(:dbk_flag_wind)],
      [0, 4, 1, 17] => [I18n.t(:dbk_flag_contact)]
    }.each do |frames, words|
      SpeakCapture.clear
      open_panel(tackler, :flag_frames => frames)
      assert_equal [[panel_line(:flags => I18n.t(:dbk_flags, :list => words.join(", "))), false]], SpeakCapture.log,
                   "frames #{frames.inspect}"
    end
  end

  test "says each frame of the flag icon sheet as its word, naming moves as the game names them" do
    {
      2 => I18n.t(:dbk_flag_noprotect, :move => "MovePROTECT"),
      3 => I18n.t(:dbk_flag_nomirror, :move => "MoveMIRRORMOVE"),
      4 => I18n.t(:dbk_flag_contact), 5 => I18n.t(:dbk_flag_minimize, :move => "MoveMINIMIZE"),
      6 => I18n.t(:dbk_flag_highcrit), 7 => I18n.t(:dbk_flag_thaw), 8 => I18n.t(:dbk_flag_sound),
      9 => I18n.t(:dbk_flag_punch), 10 => I18n.t(:dbk_flag_bite), 11 => I18n.t(:dbk_flag_bomb),
      12 => I18n.t(:dbk_flag_pulse), 13 => I18n.t(:dbk_flag_powder), 14 => I18n.t(:dbk_flag_dance),
      15 => I18n.t(:dbk_flag_slice), 16 => I18n.t(:dbk_flag_wind), 0 => nil, 1 => nil, 17 => nil
    }.each do |frame, word|
      SpeakCapture.clear
      open_panel(tackler, :flag_frames => [frame])
      flags = word && I18n.t(:dbk_flags, :list => word)
      assert_equal [[panel_line(:flags => flags), false]], SpeakCapture.log, "frame #{frame}"
    end
  end

  test "says nothing for the same panel drawn again" do
    user = tackler
    scene = open_panel(user, :effect_frames => [3])
    SpeakCapture.clear
    scene.pbUpdateMoveInfoWindow(user, 0)
    assert_nothing_spoken
  end

  test "says only what changed when the power and the verdict change under a still cursor" do
    user = tackler
    scene = open_panel(user, :effect_frames => [3])
    SpeakCapture.clear
    scene.figures = ["135", "100", "---"]
    scene.effect_frames = [1]
    scene.pbUpdateMoveInfoWindow(user, 0)
    assert_equal [[[I18n.t(:mv_power, :p => "135"), I18n.t(:mv_eff_none)].join(", "), false]], SpeakCapture.log
  end

  test "says nothing when a repaint only takes a part away" do
    user = tackler
    scene = open_panel(user, :effect_frames => [3])
    SpeakCapture.clear
    scene.effect_frames = []
    scene.pbUpdateMoveInfoWindow(user, 0)
    assert_nothing_spoken
  end

  test "leaves out what the fight line has just said for the move" do
    golpe = answering(:name => "Golpe", :category => 0, :type => :NORMAL, :pbCalcType => :NORMAL)
    user = answering(:index => 0, :moves => [tackler.moves[0], golpe])
    scene = open_panel(user)
    SpeakCapture.clear
    fight_line_said([0, 1, ["Golpe", "PP 10 de 10"]])
    scene.pbUpdateMoveInfoWindow(user, 1)
    assert_equal [[panel_line(:name => nil), false]], SpeakCapture.log
  end

  test "says nothing with the panel shut, and reads it whole when it opens again" do
    user = tackler
    scene = open_panel(user, :effect_frames => [3])
    scene.moveUIToggle = false
    scene.pbUpdateMoveInfoWindow(user, 0)
    scene.moveUIToggle = true
    scene.pbUpdateMoveInfoWindow(user, 0)
    line = panel_line(:verdict => I18n.t(:mv_eff_super))
    assert_equal [[line, false], [line, false]], SpeakCapture.log
  end

  test "reads the panel whole after hiding it, even what the fight line said" do
    user = tackler
    scene = open_panel(user, :effect_frames => [3])
    fight_line_said([0, 0, ["Placaje", "PP 35 de 35"]])
    scene.pbHideMoveInfo
    scene.moveUIToggle = true
    scene.pbUpdateMoveInfoWindow(user, 0)
    line = panel_line(:verdict => I18n.t(:mv_eff_super))
    assert_equal [[line, false], [line, false]], SpeakCapture.log
  end

  test "does not repeat an unchanged panel when the fight line is read again" do
    user = tackler
    scene = open_panel(user)
    fight_line_said([0, 0, ["Placaje"]])
    scene.pbUpdateMoveInfoWindow(user, 0)
    assert_equal [[panel_line, false]], SpeakCapture.log
  end

  test "leaves out the verdict and the properties when their icon rows come back unreadable" do
    open_panel(tackler, :effect_frames => true, :flag_frames => 7)
    assert_equal [[panel_line, false]], SpeakCapture.log
  end

  test "reads a foe's panel as it paints it, with a share of its hit points and no ability" do
    battle = answering(:turnCount => 2, :pbGetOwnerFromBattlerIndex => answering(:name => "Kai"))
    foe = answering(:name => "Rival", :index => 1, :level => 30, :hp => 20, :totalhp => 40, :status => :POISON,
                    :pbOwnedByPlayer? => false, :opposes? => true, :shiny? => true, :wild? => false,
                    :displayPokemon => answering(:name => "Rival", :gender => 0), :battle => battle,
                    :pbTypes => [:FIRE, :FLYING], :abilityName => "Secreta", :lastMoveUsed => :EMBER,
                    :effects => {}, :@stages => { :ATTACK => -1 })
    expected = ["Rival", MALE, I18n.t(:dbk_shiny), I18n.t(:dbk_trainer, :name => "Kai"), I18n.t(:dbk_turn, :n => 3),
                I18n.t(:dbk_level, :n => 30), I18n.t(:bt_hp_pct, :n => 50), "StatusPOISON",
                I18n.t(:mv_type, :t => "TypeFIRE/TypeFLYING"), I18n.t(:dbk_lastmove, :m => "MoveEMBER"),
                changes_part("StatATTACK -1")].join(", ")
    info_panel.pbUpdateBattlerInfo(foe)
    assert_equal [[expected, true]], SpeakCapture.log
  end

  test "leaves out a status or a last move the game has no data for" do
    foe = answering(:name => "Rival", :index => 1, :pbOwnedByPlayer? => false, :opposes? => true,
                    :status => :ROTTEN, :lastMoveUsed => :NOMOVE)
    with_missing(GameData::Status, :ROTTEN) do
      with_missing(GameData::Move, :NOMOVE) { info_panel.pbUpdateBattlerInfo(foe) }
    end
    assert_equal [["Rival", true]], SpeakCapture.log
  end

  test "names the trainer who owns a foe only for a trainer's battler whose trainer has a name" do
    {
      "a trainer's foe" => [{ :wild? => false }, "Kai", "Rival, #{I18n.t(:dbk_trainer, :name => "Kai")}"],
      "a wild foe" => [{ :wild? => true }, "Kai", "Rival"],
      "a foe that does not say" => [{}, "Kai", "Rival"],
      "a trainer with no name" => [{ :wild? => false }, "", "Rival"]
    }.each do |label, (fields, owner, line)|
      SpeakCapture.clear
      battle = answering(:pbGetOwnerFromBattlerIndex => answering(:name => owner))
      info_panel.pbUpdateBattlerInfo(answering({ :name => "Rival", :index => 1, :pbOwnedByPlayer? => false,
                                                 :opposes? => true, :battle => battle }.merge(fields)))
      assert_equal [[line, true]], SpeakCapture.log, label
    end
  end

  test "reads the player's own panel with exact hit points, ability and item" do
    own = answering(:name => "Chispa", :index => 0, :level => 12, :hp => 30, :totalhp => 35, :status => :NONE,
                    :pbOwnedByPlayer? => true, :opposes? => false,
                    :pokemon => answering(:name => "Chispa", :gender => 1), :pbTypes => [:ELECTRIC],
                    :abilityName => "Electricidad Estatica", :itemName => "Baya Aranja")
    expected = ["Chispa", FEMALE, I18n.t(:dbk_level, :n => 12), I18n.t(:dbk_hp, :hp => 30, :tot => 35),
                I18n.t(:mv_type, :t => "TypeELECTRIC"), I18n.t(:dbk_ability, :a => "Electricidad Estatica"),
                I18n.t(:dbk_item, :i => "Baya Aranja")].join(", ")
    info_panel.pbUpdateBattlerInfo(own)
    assert_equal [[expected, true]], SpeakCapture.log
  end

  test "reads a battler once while the panel stays on it, then the next one it moves to" do
    scene = info_panel
    scene.pbUpdateBattlerInfo(own_named("Chispa"))
    scene.pbUpdateBattlerInfo(own_named("Chispa"))
    scene.pbUpdateBattlerInfo(answering(:name => "Brasa", :index => 2, :pbOwnedByPlayer? => true))
    assert_equal [["Chispa", true], ["Brasa", true]], SpeakCapture.log
  end

  test "says nothing while the info panel is off, and reads the same battler again once it is back" do
    scene = info_panel
    scene.pbUpdateBattlerInfo(own_named("Chispa"))
    scene.infoUIToggle = false
    scene.pbUpdateBattlerInfo(own_named("Chispa"))
    scene.infoUIToggle = true
    scene.pbUpdateBattlerInfo(own_named("Chispa"))
    assert_equal [["Chispa", true], ["Chispa", true]], SpeakCapture.log
  end

  test "says a foe's ability only once the game records it revealed for that battler" do
    foe = answering(:name => "Rival", :index => 1, :pbOwnedByPlayer? => false, :opposes? => true,
                    :abilityName => "Presion")
    {
      "no record" => [nil, "Rival"],
      "the record of nils" => [{ 1 => { 0 => { :pkmn => nil, :abil => nil } } }, "Rival"],
      "another battler's record" => [{ 3 => { 0 => { :pkmn => foe, :abil => :PRESSURE } } }, "Rival"],
      "its own record, unreadable" => [{ 1 => unreadable_hash }, "Rival"],
      "its own record" => [{ 1 => { 0 => { :pkmn => foe, :abil => :PRESSURE } } },
                           "Rival, #{I18n.t(:dbk_ability, :a => "Presion")}"]
    }.each do |label, (record, line)|
      SpeakCapture.clear
      with_revealed(record) { info_panel.pbUpdateBattlerInfo(foe) }
      assert_equal [[line, true]], SpeakCapture.log, label
    end
  end

  test "says a raid boss's shields" do
    { true => "Jefe, #{I18n.t(:ss2_shields, :n => 2)}", false => "Jefe" }.each do |boss, line|
      SpeakCapture.clear
      info_panel.pbUpdateBattlerInfo(answering(:name => "Jefe", :index => 3, :pbOwnedByPlayer? => false,
                                               :opposes? => true, :isbossmon => boss, :shieldCount => 2))
      assert_equal [[line, true]], SpeakCapture.log, "a boss: #{boss}"
    end
  end

  test "under Illusion, signs and types a foe as the Pokemon it displays, plus a type a move added" do
    shown = answering(:name => "Absol", :gender => 1, :types => [:ELECTRIC])
    hidden = answering(:name => "Zoroark", :gender => 0, :types => [:DARK])
    {
      {} => "TypeELECTRIC",
      { PBEffects::Type3 => :GHOST } => "TypeELECTRIC/TypeGHOST"
    }.each do |extra, types|
      SpeakCapture.clear
      foe = answering(:name => "Zoroark", :index => 1, :pbOwnedByPlayer? => false, :opposes? => true,
                      :displayPokemon => shown, :pokemon => hidden, :pbTypes => [:DARK],
                      :effects => { PBEffects::Illusion => shown }.merge(extra))
      info_panel.pbUpdateBattlerInfo(foe)
      assert_equal [[["Absol", FEMALE, I18n.t(:mv_type, :t => types)].join(", "), true]], SpeakCapture.log,
                   "with #{extra.inspect}"
    end
  end

  test "names, signs and types the player's own battler as it is, Illusion or not" do
    shown = answering(:name => "Absol", :gender => 1, :types => [:ELECTRIC])
    hidden = answering(:name => "Zoroark", :gender => 0, :types => [:DARK])
    [{ PBEffects::Illusion => shown }, {}].each do |effects|
      SpeakCapture.clear
      own = answering(:name => "Absol", :index => 0, :pbOwnedByPlayer? => true, :opposes? => false,
                      :displayPokemon => shown, :pokemon => hidden, :pbTypes => [:WATER], :effects => effects)
      info_panel.pbUpdateBattlerInfo(own)
      assert_equal [[["Zoroark", MALE, I18n.t(:mv_type, :t => "TypeWATER")].join(", "), true]], SpeakCapture.log,
                   "with #{effects.inspect}"
    end
  end

  test "reads a foe with the types a move changed in battle" do
    mon = answering(:name => "Rival", :types => [:FIRE])
    info_panel.pbUpdateBattlerInfo(answering(:name => "Rival", :index => 1, :pbOwnedByPlayer? => false,
                                             :opposes? => true, :displayPokemon => mon, :pokemon => mon,
                                             :pbTypes => [:WATER]))
    assert_equal [["Rival, #{I18n.t(:mv_type, :t => "TypeWATER")}", true]], SpeakCapture.log
  end

  test "reads a terastallized battler with its original types, a foe under Illusion with its disguise's" do
    fire = answering(:name => "Rival", :types => [:FIRE])
    disguise = answering(:name => "Absol", :types => [:ELECTRIC])
    {
      "a foe" => [{ :index => 1, :pbOwnedByPlayer? => false, :opposes? => true, :displayPokemon => fire },
                  "Rival, #{I18n.t(:mv_type, :t => "TypeFIRE")}"],
      "a foe under Illusion" => [{ :index => 1, :pbOwnedByPlayer? => false, :opposes? => true,
                                   :displayPokemon => disguise, :effects => { PBEffects::Illusion => disguise } },
                                 "Absol, #{I18n.t(:mv_type, :t => "TypeELECTRIC")}"],
      "the player's own" => [{ :index => 0, :pbOwnedByPlayer? => true, :opposes? => false },
                             "Rival, #{I18n.t(:mv_type, :t => "TypeFIRE")}"]
    }.each do |label, (fields, line)|
      SpeakCapture.clear
      info_panel.pbUpdateBattlerInfo(answering({ :name => "Rival", :tera? => true, :pokemon => fire,
                                                 :pbTypes => [:WATER] }.merge(fields)))
      assert_equal [[line, true]], SpeakCapture.log, label
    end
  end

  test "says the ??? types as unknown for a celestial battler or a foe the Pokedex never met, else the real ones" do
    unknown = "Rival, #{I18n.t(:mv_type, :t => I18n.t(:pdx_unknown_short))}"
    known = "Rival, #{I18n.t(:mv_type, :t => "TypeFIRE")}"
    mon = answering(:name => "Rival", :species => :MEW)
    foe = { :name => "Rival", :index => 1, :pbOwnedByPlayer? => false, :opposes? => true, :displayPokemon => mon,
            :pbTypes => [:FIRE] }
    {
      "a celestial foe" => [foe.merge(:celestial? => true), dex_holder(true, 1), unknown],
      "a foe never owned nor battled" => [foe, dex_holder(false, 0), unknown],
      "a foe battled once" => [foe, dex_holder(false, 1), known],
      "a foe owned" => [foe, dex_holder(true, 0), known],
      "the player's own, never met" => [foe.merge(:pbOwnedByPlayer? => true, :opposes? => false, :pokemon => mon),
                                        dex_holder(false, 0), known],
      "a foe, with no Pokedex to ask" => [foe, answering(:name => "Tester"), unknown],
      "a foe whose battle count is no number" => [foe, dex_holder(false, Object.new), known]
    }.each do |label, (fields, player, line)|
      SpeakCapture.clear
      with_player(player) { info_panel.pbUpdateBattlerInfo(answering(fields)) }
      assert_equal [[line, true]], SpeakCapture.log, label
    end
  end

  test "reads a battler that cannot say its side or owner as the player's own, Illusion or not" do
    mon = answering(:name => "Rival", :species => :MEW, :types => [:WATER])
    disguise = answering(:name => "Absol", :types => [:ELECTRIC])
    line = ["Rival", I18n.t(:dbk_hp, :hp => 20, :tot => 40), I18n.t(:mv_type, :t => "TypeFIRE")].join(", ")
    [{}, { PBEffects::Illusion => disguise }].each do |effects|
      SpeakCapture.clear
      with_player(dex_holder(false, 0)) do
        info_panel.pbUpdateBattlerInfo(answering(:name => "Disfraz", :index => 1, :pokemon => mon, :hp => 20,
                                                 :totalhp => 40, :pbTypes => [:FIRE], :effects => effects))
      end
      assert_equal [[line, true]], SpeakCapture.log, "with #{effects.inspect}"
    end
  end

  test "reads the types the battler reports, a type a move added included, else its plain types" do
    {
      "a type added by a move" => [{ :pbTypes => lambda { |all| all ? [:GRASS, :GHOST] : [:GRASS] } },
                                   "TypeGRASS/TypeGHOST"],
      "no battle types to report" => [{ :types => [:FIRE] }, "TypeFIRE"]
    }.each do |label, (fields, types)|
      SpeakCapture.clear
      info_panel.pbUpdateBattlerInfo(answering({ :name => "Rival", :index => 1, :pbOwnedByPlayer? => false,
                                                 :opposes? => true }.merge(fields)))
      assert_equal [["Rival, #{I18n.t(:mv_type, :t => types)}", true]], SpeakCapture.log, label
    end
  end

  test "says a battler left with no type as unknown, as the panel paints ???" do
    info_panel.pbUpdateBattlerInfo(answering(:name => "Rival", :index => 1, :pbOwnedByPlayer? => false,
                                             :opposes? => true, :pbTypes => []))
    assert_equal [["Rival, #{I18n.t(:mv_type, :t => I18n.t(:pdx_unknown_short))}", true]], SpeakCapture.log
  end

  test "leaves out an ability or an item the panel paints blank" do
    {
      "the player's own, holding nothing" =>
        [{ :index => 0, :pbOwnedByPlayer? => true, :abilityName => "Presion", :itemName => "" },
         "Chispa, #{I18n.t(:dbk_ability, :a => "Presion")}"],
      "the player's own, with no ability" =>
        [{ :index => 0, :pbOwnedByPlayer? => true, :abilityName => "", :itemName => "Baya Aranja" },
         "Chispa, #{I18n.t(:dbk_item, :i => "Baya Aranja")}"],
      "a foe whose revealed ability is blank" =>
        [{ :index => 1, :pbOwnedByPlayer? => false, :opposes? => true, :abilityName => "" }, "Chispa"]
    }.each do |label, (fields, line)|
      SpeakCapture.clear
      with_revealed({ 1 => { 0 => { :pkmn => :revealed, :abil => :PRESSURE } } }) do
        info_panel.pbUpdateBattlerInfo(answering({ :name => "Chispa" }.merge(fields)))
      end
      assert_equal [[line, true]], SpeakCapture.log, label
    end
  end

  test "reads a never-met foe's types when the game is set to always show them" do
    foe = answering(:name => "Rival", :index => 1, :pbOwnedByPlayer? => false, :opposes? => true,
                    :displayPokemon => answering(:name => "Rival", :species => :MEW), :pbTypes => [:FIRE])
    with_player(dex_holder(false, 0)) do
      with_const(::Settings, :ALWAYS_DISPLAY_TYPES, true) { info_panel.pbUpdateBattlerInfo(foe) }
    end
    assert_equal [["Rival, #{I18n.t(:mv_type, :t => "TypeFIRE")}", true]], SpeakCapture.log
  end

  test "says the effects in play as the panel lists them, with the counts it paints, and no blank row" do
    {
      [["Reflect", "3/5"], ["Stealth Rocks", ""], ["Trick Room", "---"]] =>
        "Chispa, #{I18n.t(:ss2_effects, :list => "Reflect 3/5, Stealth Rocks, Trick Room")}",
      [["", ""]] => "Chispa",
      [] => "Chispa"
    }.each do |rows, line|
      SpeakCapture.clear
      info_panel(:effect_rows => rows).pbUpdateBattlerInfo(own_named("Chispa"))
      assert_equal [[line, true]], SpeakCapture.log, "rows #{rows.inspect}"
    end
  end

  test "leaves out the effects when their rows come back unreadable" do
    info_panel(:effect_rows => "Reflect").pbUpdateBattlerInfo(own_named("Chispa"))
    assert_equal [["Chispa", true]], SpeakCapture.log
  end

  test "says the Crit. Hit row's arrows after the stat changes, four at most" do
    with_const(PBEffects, :FocusEnergy, 901) do
      with_const(PBEffects, :CriticalBoost, 902) do
        crit = I18n.t(:dbk_crit)
        {
          [{ :ATTACK => 1 }, 2, 1] => changes_part("StatATTACK +1, #{crit} +3"),
          [{}, 0, 1] => changes_part("#{crit} +1"),
          [{}, 2, 0] => changes_part("#{crit} +2"),
          [{}, 2, 2] => changes_part("#{crit} +4"),
          [{}, 3, 2] => changes_part("#{crit} +4"),
          [{ :ATTACK => 1 }, 0, 0] => changes_part("StatATTACK +1"),
          [{}, 0, 0] => nil
        }.each do |(stages, focus, boost), part|
          SpeakCapture.clear
          mon = answering(:name => "Chispa", :index => 0, :pbOwnedByPlayer? => true, :@stages => stages,
                          :effects => { PBEffects::FocusEnergy => focus, PBEffects::CriticalBoost => boost })
          info_panel.pbUpdateBattlerInfo(mon)
          assert_equal [[["Chispa", part].compact.join(", "), true]], SpeakCapture.log,
                       "stages #{stages.inspect}, Focus Energy #{focus}, boost #{boost}"
        end
      end
    end
  end

  test "reads the battler under the selection, own side in order and the other side reversed" do
    battle = grid_battle
    { [0, 0] => "Chispa", [0, 1] => "Brasa", [1, 0] => "Otro", [1, 1] => "Rival" }.each do |pair, name|
      SpeakCapture.clear
      grid(battle).pbUpdateBattlerSelection(pair, false)
      assert_equal [[name, true]], SpeakCapture.log, "for #{pair.inspect}"
    end
  end

  test "signs the selected battler as its slot does and adds the trainer who owns it" do
    shown = answering(:name => "Absol", :gender => 1)
    hidden = answering(:name => "Zoroark", :gender => 0)
    foe = answering(:index => 1, :displayPokemon => shown, :pokemon => hidden)
    {
      "Kai" => I18n.t(:dbk_owner, :name => "Absol #{FEMALE}", :owner => "Kai"),
      "" => "Absol #{FEMALE}",
      nil => "Absol #{FEMALE}"
    }.each do |owner, line|
      SpeakCapture.clear
      trainer = owner && answering(:name => owner)
      battle = answering(:allSameSideBattlers => [], :allOtherSideBattlers => [foe],
                         :pbGetOwnerFromBattlerIndex => trainer)
      grid(battle).pbUpdateBattlerSelection([1, 0], false)
      assert_equal [[line, true]], SpeakCapture.log, "owned by #{owner.inspect}"
    end
  end

  test "reads each battler the selection moves to once" do
    scene = grid(grid_battle)
    scene.pbUpdateBattlerSelection([0, 0], false)
    scene.pbUpdateBattlerSelection([0, 0], false)
    scene.pbUpdateBattlerSelection([1, 0], false)
    assert_equal [["Chispa", true], ["Otro", true]], SpeakCapture.log
  end

  test "says nothing for a selection off the grid, on an empty slot or a nameless battler, or with no battle" do
    blank = answering(:index => 0, :pokemon => answering(:name => "", :gender => 1))
    nameless = answering(:allSameSideBattlers => [blank], :allOtherSideBattlers => [],
                         :pbGetOwnerFromBattlerIndex => nil)
    {
      "a bare index" => [grid_battle, 1, false],
      "an empty slot" => [grid_battle, [1, 5], false],
      "a battler with a blank name" => [nameless, [0, 0], false],
      "no battle, the grid opening" => [nil, [0, 0], true]
    }.each do |label, (battle, index, select)|
      SpeakCapture.clear
      grid(battle).pbUpdateBattlerSelection(index, select)
      assert_nothing_spoken label
    end
  end

  test "opening the grid says each trainer's lineup after the battler, the foes' first and queued, once" do
    battle = grid_battle(:opponent => [trainer("Kai", [ball, ball(:POISON), ball(:NONE, false), ball], 3),
                                       trainer("Nadie", [ball(:NONE, false)], 0)],
                         :player => [trainer("Tester", [ball], 1)])
    scene = grid(battle)
    scene.pbUpdateBattlerSelection([0, 0], true)
    scene.pbUpdateBattlerSelection([1, 0], false)
    kai = kai_lineup([:dbk_lineup_ok, 2], [:dbk_lineup_status, 1], [:dbk_lineup_fainted, 1])
    mine = I18n.t(:dbk_lineup, :name => "Tester", :list => I18n.t(:dbk_lineup_ok, :n => 1))
    assert_equal [["Chispa", true], ["#{kai}. #{mine}", false], ["Otro", true]], SpeakCapture.log
  end

  test "counts a lineup as its six balls show it, and draws none for a trainer with nobody able to fight" do
    {
      "healthy, with a status and fainted" =>
        [trainer("Kai", [ball, ball(:POISON), ball(:NONE, false), ball], 3),
         kai_lineup([:dbk_lineup_ok, 2], [:dbk_lineup_status, 1], [:dbk_lineup_fainted, 1])],
      "an empty slot" => [trainer("Kai", [ball, nil, ball(:NONE, false)], 1),
                          kai_lineup([:dbk_lineup_ok, 1], [:dbk_lineup_fainted, 1])],
      "a seventh member" => [trainer("Kai", Array.new(7) { ball }, 7), kai_lineup([:dbk_lineup_ok, 6])],
      "a member that cannot be asked" => [trainer("Kai", [answering(:status => :NONE)], 1),
                                          kai_lineup([:dbk_lineup_fainted, 1])],
      "a nameless trainer" => [trainer("", [ball, ball], 2), I18n.t(:dbk_lineup_ok, :n => 2)],
      "nobody able" => [trainer("Kai", [ball(:NONE, false)], 0), nil],
      "a trainer that cannot be asked" => [answering(:name => "Kai", :party => [ball]), nil]
    }.each do |label, (tr, line)|
      if line
        assert_equal line, Reader.lineup(tr), label
      else
        assert_nil Reader.lineup(tr), label
      end
    end
  end

  test "opening the grid says no lineups when no trainer has a ball to show" do
    battle = grid_battle(:opponent => [trainer("Nadie", [ball(:NONE, false)], 0)], :player => [])
    grid(battle).pbUpdateBattlerSelection([0, 0], true)
    assert_equal [["Chispa", true]], SpeakCapture.log
  end

  test "opening the grid with the info panel off says no lineups" do
    battle = answering(:allSameSideBattlers => [], :allOtherSideBattlers => [], :opponent => [],
                       :player => [trainer("Tester", [ball], 1)])
    scene = grid(battle)
    scene.infoUIToggle = false
    scene.pbUpdateBattlerSelection([0, 0], true)
    assert_nothing_spoken
  end

  test "opening the selection again reads the battler under it, even the same one" do
    scene = grid(grid_battle)
    scene.pbUpdateBattlerSelection([0, 0], false)
    scene.pbSelectBattlerInfo
    scene.pbUpdateBattlerSelection([0, 0], false)
    assert_equal [["Chispa", true], ["Chispa", true]], SpeakCapture.log
  end

  test "toggling the info panel lets the grid and the battler panel read the same battler again" do
    scene = grid(grid_battle)
    chispa = answering(:name => "Chispa", :index => 0, :level => 12, :pbOwnedByPlayer? => true)
    scene.pbUpdateBattlerSelection([0, 0], false)
    scene.pbUpdateBattlerInfo(chispa)
    scene.pbToggleBattleInfo
    scene.pbUpdateBattlerSelection([0, 0], false)
    scene.pbUpdateBattlerInfo(chispa)
    panel = "Chispa, #{I18n.t(:dbk_level, :n => 12)}"
    assert_equal [["Chispa", true], [panel, true], ["Chispa", true], [panel, true]], SpeakCapture.log
  end

  private

  # An engine object answering only the methods given, each with its value whatever the arguments (a Proc is called
  # with them); a key naming an instance variable (:@stages) sets it instead. Anything else raises, as a method the
  # engine lacks does.
  def answering(fields)
    obj = Object.new
    fields.each do |key, value|
      if key.to_s.start_with?("@")
        obj.instance_variable_set(key, value)
      elsif value.is_a?(Proc)
        obj.define_singleton_method(key) { |*args| value.call(*args) }
      else
        obj.define_singleton_method(key) { |*_args| value }
      end
    end
    obj
  end

  # A battler whose only move is Placaje, of the given category, listed as Normal and calculated as calc (nil: a
  # move that calculates no type).
  def tackler(category = 0, calc = :NORMAL)
    fields = { :name => "Placaje", :category => category, :type => :NORMAL }
    fields[:pbCalcType] = calc if calc
    answering(:index => 0, :moves => [answering(fields)])
  end

  # Draws the move panel for user's first move on a fresh scene with the given knobs (figures, description,
  # effect_frames, flag_frames, battle), the panel opening as after the game hid it; returns the scene.
  def open_panel(user, knobs = {})
    PokeAccess::BattleScene.panel_shut
    scene = Battle::Scene.new
    scene.moveUIToggle = true
    knobs.each { |k, v| scene.send("#{k}=", v) }
    scene.pbUpdateMoveInfoWindow(user, 0)
    scene
  end

  # The line the move panel says for Placaje as the stand-in paints it, each part replaceable (nil leaves it out).
  def panel_line(over = {})
    parts = { :name => "Placaje", :type => I18n.t(:mv_type, :t => "TypeNORMAL"), :category => I18n.t(:cat_physical),
              :power => I18n.t(:mv_power, :p => "90"), :accuracy => I18n.t(:mv_acc, :a => "100"), :chance => nil,
              :flags => nil, :verdict => nil, :description => DESC }.merge(over)
    [:name, :type, :category, :power, :accuracy, :chance, :flags, :verdict, :description].map { |k| parts[k] }
                                                                                        .compact.join(", ")
  end

  # Records line as the fight menu's last read ([battler index, move index, phrases]), as its reader does.
  def fight_line_said(line)
    PokeAccess::BattleScene.instance_variable_set(:@fight_line, line)
  end

  # The changes wording for list, without the sentence separator its key starts with.
  def changes_part(list)
    I18n.t(:bt_changes, :list => list).sub(/\A[.,]\s*/, "")
  end

  # A battle scene with the battler info panel up and the given knobs (effect_rows).
  def info_panel(knobs = {})
    scene = Battle::Scene.new
    scene.infoUIToggle = true
    knobs.each { |k, v| scene.send("#{k}=", v) }
    scene
  end

  # The player's own battler at index 0 that answers its name alone.
  def own_named(name)
    answering(:name => name, :index => 0, :pbOwnedByPlayer? => true)
  end

  # A battle scene with the info panel up over battle, for the selection grid.
  def grid(battle)
    scene = info_panel
    scene.battle = battle
    scene
  end

  # A double battle as the grid sees it: Chispa and Brasa on the player's side, Rival and Otro on the other, no owners,
  # and the trainers given in extra.
  def grid_battle(extra = {})
    own = lambda { |i, name| answering(:index => i, :pokemon => answering(:name => name)) }
    foe = lambda { |i, name| answering(:index => i, :displayPokemon => answering(:name => name)) }
    answering({ :allSameSideBattlers => [own.call(0, "Chispa"), own.call(2, "Brasa")],
                :allOtherSideBattlers => [foe.call(1, "Rival"), foe.call(3, "Otro")],
                :pbGetOwnerFromBattlerIndex => nil }.merge(extra))
  end

  # A trainer with a party and the able count the game keeps for it.
  def trainer(name, party, able)
    answering(:name => name, :party => party, :able_pokemon_count => able)
  end

  # A party member as its ball shows it: its status, and whether it can still fight.
  def ball(status = :NONE, able = true)
    answering(:status => status, :able? => able)
  end

  # Kai's lineup as the grid says it, from [count key, n] pairs.
  def kai_lineup(*counts)
    I18n.t(:dbk_lineup, :name => "Kai", :list => counts.map { |key, n| I18n.t(key, :n => n) }.join(", "))
  end

  # Runs the block with the game's record of revealed abilities set to record, put back after.
  def with_revealed(record)
    was = $RevealedAbility
    $RevealedAbility = record
    yield
  ensure
    $RevealedAbility = was
  end

  # A Hash every lookup of which raises, as a record the game left in a shape it cannot be read in.
  def unreadable_hash
    Class.new(Hash) { def [](_key); raise IndexError, "unreadable"; end }.new
  end

  # A player whose Pokedex answers owned? and battled_count as given.
  def dex_holder(owned, battled)
    answering(:name => "Tester", :pokedex => answering(:owned? => owned, :battled_count => battled))
  end

  # Runs the block with $player set to player, put back after.
  def with_player(player)
    was = $player
    $player = player
    yield
  ensure
    $player = was
  end

  # Runs the block with data.get raising for id, as GameData does for an id the game does not have; put back after.
  def with_missing(data, id)
    meta = data.singleton_class
    meta.send(:alias_method, :pa_test_get, :get)
    meta.send(:define_method, :get) { |i| i == id ? raise(ArgumentError, "Unknown ID #{i}") : pa_test_get(i) }
    yield
  ensure
    meta.send(:alias_method, :get, :pa_test_get)
    meta.send(:remove_method, :pa_test_get)
  end

  # Runs the block with mod::name set to value, put back as it was (or removed) after.
  def with_const(mod, name, value)
    had = mod.const_defined?(name, false)
    was = mod.const_get(name) if had
    mod.send(:remove_const, name) if had
    mod.const_set(name, value)
    yield
  ensure
    mod.send(:remove_const, name) if mod.const_defined?(name, false)
    mod.const_set(name, was) if had
  end
end
