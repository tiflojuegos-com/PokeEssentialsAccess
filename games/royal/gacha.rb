# royal's Gacha screen ([ROYAL] Gacha -> class GachaScene): sprite buttons with @sel (0-4) as the cursor
# and @banner_sel into @banners for the current banner. refresh redraws on every cursor move and banner
# change, so read the focused button there (banner announced only when it actually changes), deduped.
module PokeAccess
  module GachaRoyal
    # Verbatim from the buttons the game draws (Magic Gachapon/002_Gacha_Scene), in cursor order: the
    # sprites are numbered 1, 2, 4, 5, 3, which is not the order they are read in.
    # Index 3 is the ULTRA ticket, not a reward chooser: a label invented by the reader sends the player to
    # the wrong item. The first one is drawn "Info.", not "Informacion", and verbatim means verbatim.
    BUTTONS = ["Info.", "Tirar x1", "Tirar x10", "Ticket ULTRA", "Salir"]
  end
end

PokeAccess::Game.define("royal") do
  after("GachaScene", :refresh) do |scn, _ret, _args|
    sel  = PokeAccess.ivar(scn, :@sel)
    bsel = PokeAccess.ivar(scn, :@banner_sel)
    next unless sel
    banner_changed = PokeAccess::Cursor.changed?(scn, :gacha_banner, bsel)
    next unless PokeAccess::Cursor.changed?(scn, :gacha, [sel, bsel])
    parts = []
    if banner_changed
      bn = (scn.instance_variable_get(:@banners)[bsel].name rescue nil)
      parts.push("Banner #{bn}") if bn && !bn.to_s.empty?
    end
    btn = PokeAccess::GachaRoyal::BUTTONS[sel]
    parts.push(btn) if btn
    PokeAccess.speak_clean(parts.join(". "), true) unless parts.empty?
  end
end
