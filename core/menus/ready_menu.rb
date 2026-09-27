module PokeAccess
  # Ready Menu (PokemonReadyMenu_Scene): sprite buttons whose focus lives in a hidden "cmdwindow", claimed from the
  # generic reader and read instead of @index (an Array where the screen is split in two lists).
  module ReadyMenu
    def self.poll(scene)
      win = PokeAccess.dedicate(PokeAccess.sprite(scene, "cmdwindow"))
      return unless win
      txt = PokeAccess.clean(PokeAccess::Menus.focused_text(win).to_s)
      return if txt.empty?
      PokeAccess::Cursor.announce(scene, :ready_last, [side(scene), (win.index rescue nil), txt], true) do
        row_text(scene, win, txt)
      end
    rescue StandardError
      nil
    end

    # Which of the two lists has focus, or nil on the single-list shape; part of the dedup key.
    def self.side(scene)
      idx = PokeAccess.ivar(scene, :@index)
      idx.is_a?(Array) ? idx[2] : nil
    end
  end
end

# pbUpdate runs each frame and re-syncs the hidden window; read the focus on change.
PokeAccess::Hooks.after_hook("PokemonReadyMenu_Scene", :pbUpdate) do |scene, _r, _a|
  PokeAccess::ReadyMenu.poll(scene)
end

module PokeAccess
  module ReadyMenu
    # The tuple behind the focused row, from the scene's @commands (the window holds names only): [moveTuples,
    # itemTuples] where the screen is split in two, a flat list of tuples where it is not.
    def self.focused_row(scene, win)
      cmds = PokeAccess.ivar(scene, :@commands)
      idx = (win.index rescue nil)
      return nil unless cmds.is_a?(Array) && idx
      s = side(scene)
      list = s.nil? ? cmds : cmds[s]
      row = list.is_a?(Array) ? list[idx] : nil
      (row.is_a?(Array) && row.length >= 2) ? row : nil
    rescue StandardError
      nil
    end

    # The focused row: a move ([id, name, true, party_index]) adds its owner, an item ([id, name]) the bag's real
    # count, even where the button paints ">99"; none for an important item.
    def self.row_text(scene, win, txt)
      e = focused_row(scene, win)
      return txt unless e
      if e[2]
        owner = (PokeAccess::Engine.player.party[e[3]].name rescue nil)
        return owner ? "#{txt}, #{owner}" : txt
      end
      qty = item_quantity(e[0])
      qty ? PokeAccess::I18n.t(:bag_item, :name => txt, :qty => qty) : txt
    rescue StandardError
      txt
    end

    # How many of an item the bag holds; nil for an important item, a count of zero or no answer.
    def self.item_quantity(itemid)
      return nil if itemid.nil? || PokeAccess::Menus.bag_hides_qty?(itemid)
      n = PokeAccess::Engine.bag_quantity(itemid)
      (n.nil? || n <= 0) ? nil : n
    rescue StandardError
      nil
    end
  end
end
