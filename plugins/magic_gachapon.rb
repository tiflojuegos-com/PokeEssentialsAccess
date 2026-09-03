# Magic Gachapon ("Magico Sistema de Gacha", by Kyu and Clara; GachaScene in royal and awakening): rolls
# for rewards. @banner_sel picks the banner (left/right) and @sel the action within it; refresh redraws
# after every move and after each banner change, so the focus is read there. Banners and rewards are
# pictures, but every button carries its own painted word and the banner its name.
module PokeAccess
  module MagicGachapon
    # Button labels VERBATIM from what each copy paints, in cursor order. Royal's copy has five (sprites
    # numbered 1, 2, 4, 5, 3 -- not the read order; index 3 is the ULTRA ticket and "Info." is drawn
    # abbreviated), awakening's has three. The copy is told apart by its fifth button sprite.
    BUTTONS_FIVE  = ["Info.", "Tirar x1", "Tirar x10", "Ticket ULTRA", "Salir"]
    BUTTONS_THREE = ["Información", "Tirar", "Salir"]

    def self.buttons(scn)
      sprites = PokeAccess.ivar(scn, :@sprites)
      (sprites && sprites["button5"]) ? BUTTONS_FIVE : BUTTONS_THREE
    end

    # The focused banner (by name and place in the strip, only when it changed) and the focused button.
    def self.refresh(scn)
      sel  = PokeAccess.ivar(scn, :@sel)
      bsel = PokeAccess.ivar(scn, :@banner_sel)
      return unless sel
      banners = PokeAccess.ivar(scn, :@banners)
      banner_changed = PokeAccess::Cursor.changed?(scn, :gacha_banner, bsel)
      return unless PokeAccess::Cursor.changed?(scn, :gacha, [sel, bsel])
      parts = []
      if banner_changed && banners.is_a?(Array) && bsel.is_a?(Integer) && banners[bsel]
        name = PokeAccess.clean((banners[bsel].name rescue "").to_s).to_s.strip
        parts.push(PokeAccess::I18n.t(:list_entry, :name => name, :n => bsel + 1, :tot => banners.length)) unless name.empty?
      end
      btn = buttons(scn)[sel.to_i]
      parts.push(btn) if btn
      PokeAccess.speak_clean(parts.join(". "), true) unless parts.empty?
    rescue StandardError
      nil
    end

    # The Info button's panel: the banner description painted as a bitmap inside the panel's own blocking
    # loop -- no window, no message, no other reader. Spoken when the panel opens.
    def self.info(scn)
      sel = PokeAccess.ivar(scn, :@banner_sel).to_i
      b = (PokeAccess.ivar(scn, :@banners) || [])[sel]
      d = (b.description rescue nil)
      PokeAccess.speak_clean(d.to_s, true) if d && !d.to_s.empty?
    rescue StandardError
      nil
    end
  end
end

# refresh, not update: GachaScene#update IS the screen's blocking loop, so an after-hook on it fired once,
# on the way out, and the whole screen was silent to navigate.
PokeAccess::Hooks.after_hook("GachaScene", :refresh, :optional => true) { |s, _r, _a| PokeAccess::MagicGachapon.refresh(s) }
PokeAccess::Hooks.before_hook("GachaScene", :summaryWindow, :optional => true) { |s, _a| PokeAccess::MagicGachapon.info(s) }
