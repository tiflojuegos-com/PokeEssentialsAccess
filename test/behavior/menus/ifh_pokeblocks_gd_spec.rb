# Infinite Fusion Hoenn's Pokeblocks: the case row with the panel's flavour marks, and the condition screen's graph,
# both following the game's two settings. Gamedata pass; the profile is loaded over a stub condition scene.
class IFHConditionStub
  def initialize(party); @party = party; @index = 0; end
  def pbDrawPokemonInfo; :drawn; end
  def move(i); @index = i; pbDrawPokemonInfo; end
  # Feeding as the game runs it: the values change, then the bars move.
  def pbAtePokeblock; @party[@index].cool += 20; pbUpdateConditionBars; :ate; end
  def pbUpdateConditionBars; end
end

IFHMon = Struct.new(:name, :gender, :level, :nature, :cool, :beauty, :cute, :smart, :tough, :sheen) do
  def shiny?; false; end
  def hp; 20; end
  def totalhp; 20; end
  def item; nil; end
  def status; 0; end
end

Suite.define("ifh pokeblocks: a case row says what the block panel marks, and the condition screen its Pokemon") do
  t = PokeAccess::I18n
  made = !Object.const_defined?(:PokeblockSettings)
  saved = Object.const_defined?(:PokeblockCondition_Scene) ? PokeblockCondition_Scene : nil
  verbose = $VERBOSE
  begin
    Object.const_set(:PokeblockSettings, Module.new) if made
    PokeblockSettings.const_set(:SIMPLIFIED_BERRY_BLENDING, false)
    PokeblockSettings.const_set(:DONT_USE_SHEEN, false)
    Object.send(:remove_const, :PokeblockCondition_Scene) if saved
    Object.const_set(:PokeblockCondition_Scene, IFHConditionStub)
    $VERBOSE = nil
    load File.expand_path("../../../games/infinitefusion_hoenn/pokeblocks.rb", File.dirname(__FILE__))
    $VERBOSE = verbose
    pk = PokeAccess::HoennPokeblocks

    block = Struct.new(:name, :level, :flavor, :smoothness).new("Red Pokeblock", 12, [3, 0, 0, 0, 1], 20)
    win = Object.new
    win.instance_variable_set(:@list, [block])
    eq "the block, its level, the flavours marked and its feel", pk.case_row(win, 0),
       ["Red Pokeblock", t.t(:dbk_level, :n => 12),
        t.t(:pbk_flavors, :list => "#{t.t(:bdx_fl_spicy)}, #{t.t(:bdx_fl_sour)}"), t.t(:pbk_feel, :n => 20)].join(", ")
    eq "the row past the blocks closes the case", pk.case_row(win, 1), "CLOSE CASE"
    rows = vb_levels { pk.case_row(win, 0) }
    eq "brief: the block's name alone", rows[0], "Red Pokeblock"
    eq "medium: what the panel marks, as full says it", rows[1], rows[2]
    PokeAccess::Config.verbosity = :brief
    pk.case_row(win, 0)
    PokeAccess::Config.verbosity = :full
    eq "the info key keeps the whole row", PokeAccess::Info.info_text, rows[2]
    pk.case_row(win, 1)
    eq "and the close row takes it off, for T and Ctrl+T alike", [PokeAccess::Info.info_text.to_s.include?("Red"),
                                                                 PokeAccess::Info.row_text], [false, nil]

    mon = IFHMon.new("Zigzagoon", 0, 5, Struct.new(:name).new("Firme"), 10, 255, 0, 0, 0, 30)
    scene = PokeblockCondition_Scene.new([mon, IFHMon.new("Wurmple", 2, 3, Struct.new(:name).new("Seria"), 0, 0, 0, 0, 0, 0)])
    SpeakCapture.clear
    eq "the screen keeps its own return", scene.pbDrawPokemonInfo, :drawn
    conds = [t.t(:cnd_cool) + " 10", "#{t.t(:cnd_beauty)} 255 #{t.t(:cnd_max)}", t.t(:cnd_cute) + " 0",
             t.t(:cnd_smart) + " 0", t.t(:cnd_tough) + " 0", t.t(:cnd_sheen) + " 30"].join(", ")
    eq "the Pokemon with its sign, level and nature, then every condition, the maximum flagged, queued",
       SpeakCapture.log,
       [["Zigzagoon \xE2\x99\x82, #{t.t(:dbk_level, :n => 5)}, #{t.t(:sm_nature, :n => "Firme")}, " \
         "#{t.t(:pbk_conditions, :list => conds)}", false]]
    levels = vb_levels do
      PokeAccess::Cursor.reset(scene, :pbk_cond)
      SpeakCapture.clear
      scene.pbDrawPokemonInfo
      SpeakCapture.last
    end
    eq "brief: the name and the conditions, which stand for the hit points here", levels[0],
       "Zigzagoon, #{t.t(:pbk_conditions, :list => conds)}"
    eq "medium: and the level", levels[1],
       "Zigzagoon, #{t.t(:dbk_level, :n => 5)}, #{t.t(:pbk_conditions, :list => conds)}"
    PokeAccess::Config.verbosity = :brief
    PokeAccess::Cursor.reset(scene, :pbk_cond)
    scene.pbDrawPokemonInfo
    PokeAccess::Config.verbosity = :full
    match "the info key says the Pokemon", PokeAccess::Info.info_text.to_s, /\AZigzagoon/
    eq "and Ctrl+T its row whole, whatever the level", PokeAccess::Info.row_text, levels[2]

    SpeakCapture.clear
    eq "feeding keeps its own return", scene.pbAtePokeblock, :ate
    eq "the bars move and the condition that rose is said with where it is now, queued", SpeakCapture.log,
       [[t.t(:pbk_rose, :list => t.t(:cnd_cool) + " 30"), false]]

    SpeakCapture.clear
    PokeblockSettings.send(:remove_const, :SIMPLIFIED_BERRY_BLENDING)
    PokeblockSettings.const_set(:SIMPLIFIED_BERRY_BLENDING, true)
    scene.move(1)
    line = SpeakCapture.lines.join(" ")
    truthy "the next Pokemon interrupts, with no sign for a genderless one", SpeakCapture.log[0][1] && line.start_with?("Wurmple, ")
    falsy "and with the simplified blending there is no sheen", line.include?(t.t(:cnd_sheen))
    eq "nor a level or feel in the case row", pk.case_row(win, 0),
       ["Red Pokeblock", t.t(:pbk_flavors, :list => "#{t.t(:bdx_fl_spicy)}, #{t.t(:bdx_fl_sour)}")].join(", ")

    alike = IFHMon.new("Zigzagoon", 0, 5, Struct.new(:name).new("Firme"), 0, 0, 0, 0, 0, 0)
    twins = PokeblockCondition_Scene.new([alike, alike.dup])
    twins.pbDrawPokemonInfo
    SpeakCapture.clear
    twins.move(1)
    eq "a second member that reads like the first, every condition at zero, is said all the same",
       SpeakCapture.lines.length, 1
  ensure
    $VERBOSE = verbose
    Object.send(:remove_const, :PokeblockCondition_Scene) if Object.const_defined?(:PokeblockCondition_Scene)
    Object.const_set(:PokeblockCondition_Scene, saved) if saved
    if made
      Object.send(:remove_const, :PokeblockSettings)
    else
      [:SIMPLIFIED_BERRY_BLENDING, :DONT_USE_SHEEN].each { |c| PokeblockSettings.send(:remove_const, c) if PokeblockSettings.const_defined?(c) }
    end
  end
end
