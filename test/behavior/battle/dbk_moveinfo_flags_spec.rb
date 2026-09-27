# The DBK Move Info panel's other two readings: the bonus line pbGetFinalModifiers adds under the figures, caught
# from the same draw call, and the move-property icons pbDrawMoveFlagIcons draws, named in its order.
DBKFlagMove = Struct.new(:name, :flags, :target, :category, :power, :accuracy, :priority, :function_code, :type)

Suite.define("dbk move info: the bonus line painted with the figures is said, and forgotten with the panel") do
  mi = PokeAccess::DBKMoveInfo
  figures = [["Surf", 10, 12, :left], ["Poder:", 256, 40, :left], ["117", 309, 40, :center],
             ["Precisión:", 348, 40, :left], ["100", 401, 40, :center], ["Prioridad:", 442, 40, :left],
             ["---", 484, 40, :center], ["Efecto:", 428, 12, :left], ["---", 484, 12, :center]]
  begin
    mi.capture_on
    mi.note_draw(figures + [["Poder potenciado por Torrente.", 8, 226, :left]])
    eq "the left-aligned row after the figures is the bonus, its stop dropped", mi.bonus, "Poder potenciado por Torrente"
    mi.note_draw(figures)
    eq "a repaint without one clears it", mi.bonus, nil
    mi.note_draw(figures + [["Precisión reducida por Arena Profunda.", 8, 226, :left]])
    mi.note_draw([["algo", 0, 0, :left]])
    eq "a draw that is not the panel leaves it alone", mi.bonus, "Precisión reducida por Arena Profunda"
    mi.capture_on
    eq "and the next opening starts clean", mi.bonus, nil
  ensure
    mi.capture_off
    mi.instance_variable_set(:@painted, nil)
    mi.instance_variable_set(:@bonus, nil)
  end
end

Suite.define("dbk move info: the property icons are named as the panel draws them") do
  mi = PokeAccess::DBKMoveInfo
  t = PokeAccess::I18n
  punch = DBKFlagMove.new("Puño Fuego", ["Contact", "CanProtect", "CanMirrorMove", "Punching"], :NearOther, 0)
  eq "the flags with an icon, in the move's order", mi.flag_words(punch), [t.t(:dbkf_contact), t.t(:dbkf_punch)]
  crit = DBKFlagMove.new("Z", ["ZMove_ELECTRIC", "HighCriticalHitRate_1", "Unknown"], :NearOther, 1)
  eq "a family flag by its icon's name, one with no icon skipped", mi.flag_words(crit),
     [t.t(:dbkf_zmove), t.t(:dbkf_crit)]
  many = DBKFlagMove.new("X", %w[Contact Sound Wind Punching Biting Bomb Pulse Powder Dance Slicing], :NearOther, 0)
  eq "at most nine, as the panel's row", mi.flag_words(many).length, 9
  none = DBKFlagMove.new("Y", [], :NearOther, 2)
  eq "a move with no property says none", mi.flag_words(none), []
end

# A battler with one move, the fight menu's cursor on it.
DBKFlagBattler = Struct.new(:moves, :index)

Suite.define("dbk move info: the panel's line carries the bonus, and the properties from medium") do
  mi = PokeAccess::DBKMoveInfo
  t = PokeAccess::I18n
  move = DBKFlagMove.new("Puño Fuego", ["Contact", "Punching"], :NearOther, 0, 75, 100, 0, "BurnTarget", :FIRE)
  battler = DBKFlagBattler.new([move], 0)
  props = t.t(:dbk_flags, :list => [t.t(:dbkf_contact), t.t(:dbkf_punch)].join(", "))
  begin
    mi.capture_on
    mi.note_draw([["Puño Fuego", 10, 12, :left], ["Poder:", 256, 40, :left], ["90", 309, 40, :center],
                  ["Precisión:", 348, 40, :left], ["100", 401, 40, :center], ["Prioridad:", 442, 40, :left],
                  ["---", 484, 40, :center], ["Efecto:", 428, 12, :left], ["10%", 484, 12, :center],
                  ["Poder potenciado por Puño Férreo.", 8, 226, :left]])
    parts = mi.parts(battler, 0)
    truthy "the bonus follows the figures", parts.include?("Poder potenciado por Puño Férreo")
    truthy "and the properties close the line in full", parts.include?(props)
    PokeAccess::Config.verbosity = :brief
    falsy "brief leaves the properties out", mi.parts(battler, 0).include?(props)
    truthy "but not the bonus, which the panel writes out", mi.parts(battler, 0).include?("Poder potenciado por Puño Férreo")
  ensure
    PokeAccess::Config.verbosity = :full
    mi.capture_off
    mi.instance_variable_set(:@painted, nil)
    mi.instance_variable_set(:@bonus, nil)
  end
end

# The plugin's battler panel draws the same star for every shiny; only a copy that draws another (Royal's) says more.
Suite.define("dbk battler panel: the plugin's one star for every shiny") do
  pk = Object.new
  pk.define_singleton_method(:super_shiny?) { true }
  eq "a super shiny is still the panel's shiny", PokeAccess::DBKBattlerInfo.shiny_word(pk), PokeAccess::I18n.t(:dbk_shiny)
end
