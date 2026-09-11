module PokeAccess
  # Ready Menu (registered key-items quick selector, PokemonReadyMenu_Scene): its buttons are sprites and the
  # focus lives in a hidden Window_CommandPokemon ("cmdwindow"). That window is read rather than @index,
  # which is an Array in the games that split the screen into two lists; the window always carries the list
  # with focus. It is CLAIMED from the generic command reader, and the side is in the dedup key so crossing
  # to the other list re-reads.
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

    # Which of the two lists has focus, or nil on the single-list shape. Part of the dedup key so crossing to
    # the other side speaks again even when both lists happen to show the same name at the same position.
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
    # The tuple behind the focused row, taken from the SCENE and never from the window. The window is handed
    # NAMES and nothing else -- the scene builds its lists out of tuple[1] alone (Essentials
    # 016_UI/016_UI_ReadyMenu.rb:108-113, and the same in every game that ships the screen) -- so a reader
    # that asked the window for a tuple got a String back and said nothing extra, in all of them.
    #
    # Two shapes, the same two the cursor has: @commands is [moveTuples, itemTuples] where the screen is
    # split in two, and a flat list of tuples where it is not.
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

    # The focused row as one spoken line: a move row adds the OWNER (there is one row per party member that
    # knows it, so the owner is the only thing being chosen) and an item row adds HOW MANY, worded as the
    # bag words it. The tuple is [id, name] for an item and [id, name, true, party_index] for a move; the
    # quantity is not in it, the screen asks the bag while it paints and hides it for an important item
    # exactly as the bag screen does.
    #
    # The screen paints ">99" when it will not fit in the button. This says the real count instead: the
    # number is the bag's own, the button's limit is a width in pixels, and a player who cannot see the
    # button gains nothing from its abbreviation.
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

    # How many of an item the bag holds, or nil when the screen would not paint a number: an important item
    # (one of a kind) shows none, and a bag that answers nothing is not guessed at.
    def self.item_quantity(itemid)
      return nil if itemid.nil? || PokeAccess::Menus.bag_hides_qty?(itemid)
      bag = (defined?($PokemonBag) && $PokemonBag) ? $PokemonBag : (PokeAccess::Engine.player.bag rescue nil)
      return nil unless bag
      n = (bag.pbQuantity(itemid) rescue nil)
      n = (bag.quantity(itemid) rescue nil) if n.nil?
      (n.nil? || n.to_i <= 0) ? nil : n.to_i
    rescue StandardError
      nil
    end
  end
end
