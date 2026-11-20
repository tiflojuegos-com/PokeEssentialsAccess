module PokeAccess
  # Infinite Fusion's PC, in both games: the multi-select mode draws a rectangle from its first corner to the cursor
  # (PokemonStorageScene#pbUpdateSelectionRect, redrawn after each move) and a filtered box dims the icons its filter
  # leaves out (PokemonBoxIcon#apply_filter: opacity 80, @enabled false), as the Hoenn Safari's release screen does with
  # every Pokemon not caught on that Safari. Each redraw of the rectangle over a slot says, queued after the slot, how
  # many Pokemon it covers and how many of them are dimmed; one over the box name or a button (a negative selection)
  # says nothing. A dimmed Pokemon's slot says so, in the box and in the party column (Party.slot_marks and
  # Party.party_slot_marks). The rest of that release screen
  # (SafariReleaseStorageScreen, preventive: no 1.3.2 map calls release_caught_pokemon) is the PC the core reads; once
  # the Safari maps ship, check it still opens in multi-select with the catches as its filter.
  module IFStorageSelection
    # The party column's box index, as the game's selection names it (SelectionConstants::BOX_NAME).
    PARTY = -1

    # Says how many Pokemon the rectangle covers now, while a multi-selection is open.
    def self.redrawn(scene, box, selected)
      screen = PokeAccess.ivar(scene, :@screen)
      return unless selected.is_a?(Integer) && selected >= 0
      return unless screen && (screen.multiSelectRange rescue nil)
      storage = PokeAccess.ivar(scene, :@storage)
      held = (screen.getMultiSelection(box, selected) || []).select { |i| pokemon_at(storage, box, i) }
      dim = held.select { |i| dimmed?(scene, box, i) }.length
      t = PokeAccess::I18n
      line = t.t(:if_pc_sel, :n => held.length)
      line = "#{line}, #{t.t(:if_pc_sel_dim, :n => dim)}" if dim > 0
      PokeAccess.speak(line, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    def self.pokemon_at(storage, box, i)
      box == PARTY ? (storage.party[i] rescue nil) : (storage[box, i] rescue nil)
    end

    # The words a slot's line takes for its icon: unavailable while the filter dims it.
    def self.marks(scene, box, i)
      i.is_a?(Integer) && dimmed?(scene, box, i) ? [PokeAccess::I18n.t(:if_pc_dim)] : []
    end

    # Whether the icon of slot i (in the box shown, or the party column) is dimmed by the screen's filter.
    def self.dimmed?(scene, box, i)
      sprites = PokeAccess.ivar(scene, :@sprites)
      holder = sprites ? sprites[box == PARTY ? "boxparty" : "box"] : nil
      icons = PokeAccess.ivar(holder, :@pokemonsprites)
      icon = icons ? icons[i] : nil
      !icon.nil? && PokeAccess.ivar(icon, :@enabled) == false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  after("PokemonStorageScene", :pbUpdateSelectionRect, :optional => true) do |scene, _r, a|
    PokeAccess::IFStorageSelection.redrawn(scene, a[0], a[1])
  end
  override("PokeAccess::Party", :slot_marks) do |_mod, original, a|
    original.call + PokeAccess::IFStorageSelection.marks(a[0], nil, a[1])
  end
  override("PokeAccess::Party", :party_slot_marks) do |_mod, original, a|
    original.call + PokeAccess::IFStorageSelection.marks(a[0], PokeAccess::IFStorageSelection::PARTY, a[1])
  end
end
