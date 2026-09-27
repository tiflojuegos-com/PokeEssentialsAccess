# Soulstones 2's own databox icons, registered by its profile over the core's databox marks and read through the
# modern databox hook: a pinch ability at work and a wild foe's held item.
require File.expand_path("../../../games/soulstones2/battle_marks", File.dirname(__FILE__))

Suite.define("ss2 databox: a pinch ability at work and a wild foe's held item are said as marks") do
  t = PokeAccess::I18n
  bt = PokeAccess::Battle
  foe = Struct.new(:index, :name, :pokemon).new(1, "Pidgey", Object.new)
  box = Battle::Scene::PokemonDataBox.new(foe)
  box.extra = %w[icon_pinch icon_item]
  SpeakCapture.clear
  box.refresh
  marks = [t.t(:ss2_mark_pinch), t.t(:ss2_adv_holds)]
  eq "each by its word, in the order drawn", bt.shown_marks(foe), marks
  eq "said as the foe comes in", SpeakCapture.lines, [t.t(:bt_marks_entry, :name => "Pidgey", :marks => marks.join(", "))]
  box.extra = []
  box.refresh
  eq "and gone once the box stops drawing them", bt.shown_marks(foe), []
end
