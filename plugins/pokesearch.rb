module PokeAccess
  # Voltseon's PokeSearch (PokeSearch_Scene): a panel of three slots over two buttons, its captions only in the
  # background picture. The focused slot is said with what it holds (the berry or repel and the effect text painted
  # under it, the Pokemon chosen) as the cursor moves, as the screen opens and when a slot is filled.
  module PokeSearch
    # The panel's places, by [@index_ver, @index_hor]: the caption key of each; the lower row's third column is the
    # Cancel button too (drawPresent moves the cursor back onto it).
    PLACES = { [0, 0] => :psrch_berry, [0, 1] => :psrch_pokemon, [0, 2] => :psrch_repel,
               [1, 0] => :psrch_search, [1, 1] => :psrch_cancel, [1, 2] => :psrch_cancel }

    # The focused place as [@index_ver, @index_hor].
    def self.place(scene)
      [PokeAccess.ivar(scene, :@index_ver).to_i, PokeAccess.ivar(scene, :@index_hor).to_i]
    end

    # The focused place's caption and what it holds.
    def self.focus_line(scene)
      at = place(scene)
      key = PLACES[at]
      return nil unless key
      caption = PokeAccess::I18n.t(key)
      case at
      when [0, 0] then slot(caption, PokeAccess.ivar(scene, :@current_berry), PokeAccess.sprite(scene, "berry_text"))
      when [0, 2] then slot(caption, PokeAccess.ivar(scene, :@current_repel), PokeAccess.sprite(scene, "repel_text"))
      when [0, 1] then mon(caption, PokeAccess.ivar(scene, :@current_mon))
      else caption
      end
    end

    # An item slot: its caption, the item in it or that it is empty, then the text the window under it paints.
    def self.slot(caption, item, window)
      held = item ? PokeAccess::Data.item_name(item) : PokeAccess::I18n.t(:psrch_empty)
      text = window ? PokeAccess.clean((window.text rescue "").to_s) : ""
      PokeAccess.sentences(["#{caption}: #{held}", text])
    end

    # The Pokemon slot: its caption and the species chosen, or that none is.
    def self.mon(caption, species)
      "#{caption}: #{species ? PokeAccess::Data.species_name(species) : PokeAccess::I18n.t(:psrch_empty)}"
    end

    # Speaks the focused place when it changed, interrupting.
    def self.read(scene)
      line = focus_line(scene)
      PokeAccess::Cursor.announce(scene, :psrch_focus, [place(scene), line]) { line }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Back on the panel from the bag or the species list a slot opened: the slot again, filled or not.
    def self.back(scene)
      PokeAccess::Cursor.reset(scene, :psrch_focus)
      read(scene)
    end

    # The panel as it opens: its title, then the place the cursor starts on, queued.
    def self.opening(scene)
      PokeAccess.speak(PokeAccess::I18n.t(:psrch_title), false)
      line = focus_line(scene)
      PokeAccess::Cursor.store(scene, :psrch_focus, [place(scene), line])
      PokeAccess.speak(line, false) if line
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokeSearch_Scene", :pbStartScene, :optional => true) do |scene, _r, _a|
  PokeAccess::PokeSearch.opening(scene)
end
PokeAccess::Hooks.after_hook("PokeSearch_Scene", :drawPresent, :optional => true) do |scene, _r, _a|
  PokeAccess::PokeSearch.read(scene)
end
# Back from the bag or the species list a slot opens, the slot is said again with what it now holds; containers, as
# the bag and the list run their own loops inside.
[:selectBerry, :selectMon, :selectRepel].each do |meth|
  PokeAccess::Hooks.after_hook("PokeSearch_Scene", meth, :optional => true, :hook_container => true) do |scene, _r, _a|
    PokeAccess::PokeSearch.back(scene)
  end
end
