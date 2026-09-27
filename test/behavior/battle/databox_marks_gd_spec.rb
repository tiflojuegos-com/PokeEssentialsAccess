# The marks a modern databox draws beside a battler's name (draw_owned_icon's icon_own, from the stock folder or a
# Deluxe Battle Kit style's own), read from the images its refresh paints through the v21 hook on the stub databox.
class MarksBattlerGD
  attr_accessor :name, :level, :hp, :totalhp, :gender, :status, :index, :pokemon
  def initialize(index)
    @index = index; @pokemon = Object.new; @name = "Pidgey"; @level = 12; @hp = 30; @totalhp = 30
    @gender = 0; @status = :NONE
  end
  def types; []; end
  def pbTypes(_withtype = false); []; end
end

Suite.define("battle boxes (modern): the caught icon a foe's box draws, from any style's folder, with its lines") do
  t = PokeAccess::I18n
  bt = PokeAccess::Battle
  foe = MarksBattlerGD.new(1)
  box = Battle::Scene::PokemonDataBox.new(foe)
  plain = bt.battler_state(foe, true)
  battle = Object.new
  battle.define_singleton_method(:battlers) { [nil, foe] }
  bt.set_battle(battle)
  begin
    eq "the box's refresh keeps its own result", box.refresh, :refreshed
    eq "no caught icon drawn, nothing added", bt.battler_state(foe, true), plain
    box.owned = true
    box.refresh
    eq "the stock icon_own is said", bt.battler_state(foe, true), "#{plain}, #{t.t(:dex_caught)}"
    box.style_path = "Graphics/Plugins/Deluxe Battle Kit/Databoxes/Style"
    box.refresh
    eq "and a style's own icon_own too", bt.battler_state(foe, true), "#{plain}, #{t.t(:dex_caught)}"
  ensure
    bt.clear_battle
  end
end

Suite.define("battle boxes (modern): a species' own Mega icon, ZUD's Dynamax and Ultra Burst, the kit's Hyper Mode") do
  t = PokeAccess::I18n
  bt = PokeAccess::Battle
  foe = MarksBattlerGD.new(3)
  box = Battle::Scene::PokemonDataBox.new(foe)
  box.extra = %w[icon_mega_Charizard icon_dynamax icon_ultra icon_hyper_mode]
  box.refresh
  eq "each by its word, in the order drawn", bt.shown_marks(foe),
     [t.t(:bt_mark_mega), t.t(:bt_m_dynamax), t.t(:bt_m_ultra), t.t(:dbk_mark_hyper)]
end
