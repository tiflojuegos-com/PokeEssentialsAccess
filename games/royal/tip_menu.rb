# Royal's tip-card menu (TipMenu_Scene, Skyflyer's list of the groups seen): the focused group's title on each
# pbRedrawList, and again on the way back from the group it opened, which repaints nothing.
module PokeAccess
  module RoyalTipMenu
    @scene = nil

    # The focused group's title as the list paints it (_INTL of its :Title in Settings::TIP_CARDS_GROUPS), or nil.
    def self.title(scene)
      idx = PokeAccess.ivar(scene, :@index)
      els = PokeAccess.ivar(scene, :@elementos)
      el = (els.is_a?(Array) && idx) ? els[idx] : nil
      g = el ? (::Settings::TIP_CARDS_GROUPS[el] rescue nil) : nil
      return nil unless g && g[:Title]
      (_INTL(g[:Title].to_s) rescue g[:Title]).to_s
    end

    # Speaks the focused title when the cursor moved, or whenever force asks for it.
    def self.focus(scene, force = false)
      idx = PokeAccess.ivar(scene, :@index)
      return if idx.nil? || (!force && idx == PokeAccess.ivar(scene, :@access_tipmenu_idx))
      scene.instance_variable_set(:@access_tipmenu_idx, idx)
      PokeAccess.speak_clean(title(scene), true)
    end

    # Holds the menu while its selection loop runs, so a group closing knows it returns there.
    def self.hold(scene); @scene = scene; end
    def self.release; @scene = nil; end

    # Back from a group the menu opened: its focused title again.
    def self.returned
      focus(@scene, true) if @scene
    end
  end
end

PokeAccess::Game.define("royal") do
  after("TipMenu_Scene", :pbRedrawList, :optional => true) { |scene, _r, _a| PokeAccess::RoyalTipMenu.focus(scene) }
  around("TipMenu_Scene", :pbSelectElement, :optional => true) do |scene, nxt, _a|
    PokeAccess::RoyalTipMenu.hold(scene)
    begin; nxt.call; ensure; PokeAccess::RoyalTipMenu.release; end
  end
  kernel("pbShowTipCardsGrouped", :after) { |_args, _r| PokeAccess::RoyalTipMenu.returned }
end
