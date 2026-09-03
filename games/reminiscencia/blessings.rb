# Reminiscencia's roguelike blessing chooser (PickBlessing): after every KO and at battle start the player
# picks 1 of 3 buff cards. The cursor is a sprite (@sprites["selec"]) over @sprites["card#{@index}"], with no
# command window, so nothing is spoken. The card category and effect are drawn to a bitmap from
# BLESSINGS_HASH[@blessings[i]] ([0] = category 0..3, [3] = description). Read the focused card on open, on
# left/right (updateCursor runs for both) and after a re-roll (swapCard). Guarded: a no-op where absent.
PokeAccess::Game.define("reminiscencia") do
  # Category 0..3 spoken label, defined by the game's own comments (item/buff/mechanics/healing).
  cat_key = lambda do |c|
    { 0 => :rem_bless_item, 1 => :rem_bless_power, 2 => :rem_bless_mechanic, 3 => :rem_bless_heal }[c]
  end

  read = lambda do |scene|
    idx  = PokeAccess.ivar(scene, :@index)
    list = PokeAccess.ivar(scene, :@blessings)
    next unless list.is_a?(Array) && idx && idx >= 0 && idx < list.length
    next unless PokeAccess::Cursor.changed?(scene, :bless, idx)
    data = (BLESSINGS_HASH[list[idx]] rescue nil)
    next unless data.is_a?(Array)
    ck   = cat_key.call(data[0])
    cat  = ck ? PokeAccess::I18n.t(ck) : ""
    rar  = data[1].is_a?(Integer) ? PokeAccess::I18n.t(:bless_rarity, :n => data[1] + 1) : ""
    desc = PokeAccess.clean((_INTL(data[3].to_s) rescue data[3].to_s))
    PokeAccess.speak([cat, rar, desc].reject { |s| s.to_s.empty? }.join(". "), true)
  end

  after("PickBlessing", :updateCursor) { |scene, _r, _a| read.call(scene) }
  after("PickBlessing", :swapCard) do |scene, _r, _a|
    PokeAccess::Cursor.reset(scene, :bless)
    read.call(scene)
  end
end
