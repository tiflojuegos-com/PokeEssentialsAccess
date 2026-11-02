# Perseida's mystery gifts (0196_MysteryGifts), an older version of Clara's script than the plugin reads: three painted rows
# under a painted title, the cursor in @selected, and no album. A gift arrives through the game's own messages.
module PokeAccess
  module PerseidaGift
    READER = PokeAccess::SceneWatcher.reader("MysteryGiftScene", :pbMGCommands, :perseida_gift, :optional => true) do |scene|
      rows = PokeAccess.ivar(scene, :@text)
      sel = PokeAccess.ivar(scene, :@selected)
      rows.is_a?(Array) && sel.is_a?(Integer) && rows[sel] ? [sel, rows[sel]] : nil
    end
  end
end

PokeAccess::Game.define("perseida") do
  read_on_open("MysteryGiftScene", :pbStartScene, :optional => true, :hook_container => true) do |_scene|
    _INTL("Regalo misterioso")
  end
  # showHideItems(false) brings the rows back after a search: the row the cursor is on is said again.
  after("MysteryGiftScene", :showHideItems, :optional => true, :hook_container => true) do |_scene, _r, args|
    PokeAccess::Cursor.reset(PokeAccess::PerseidaGift::READER, :perseida_gift) if args[0] == false
  end
end
