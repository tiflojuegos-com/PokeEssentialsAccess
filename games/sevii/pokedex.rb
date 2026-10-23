module PokeAccess
  # Sevii's Pokedex: its nest page lays every region's squares 24 to a row, so it draws Hoenn's (30 wide) past the
  # 24th column a row down at the left edge; its list's keys are painted in the background alone.
  module SeviiDex
    # The keys the list's background paints, left to right: what each does, the game's button for it, the mod's remap
    # action for that button (none moves the search) and the key painted, as a virtual-key code.
    LIST_KEYS = [[:quit, :B, :b, 0x58], [:search, :F5, nil, 0x74], [:up, :L, :l, 0x21], [:down, :R, :r, 0x22]]

    # The squares of the places the species lives in on the region, from the encounter data pbStartScene reads: each
    # map that holds it by the point of its own town-map position (the rest of its size can cover a place it is not
    # found in), laid on the region's own grid; [x, y] in the order of its rows, each once; nil when the encounter data
    # cannot be read.
    # param points the region's town map points, [x, y, name, ..., switch]
    def self.lit_squares(species, region, points)
      return nil if species.nil?
      data = PokeAccess::PokedexInfoG6.encounters
      lit = []
      data.keys.each do |map|
        next unless pbFindEncounter(data[map][1], species)
        pos = PokeAccess::PokedexInfoG6.position(map)
        next if !pos || pos[0] != region
        next if points.any? { |pt| pt[0] == pos[1] && pt[1] == pos[2] && pt[7] && !$game_switches[pt[7]] }
        lit.push([pos[1], pos[2]])
      end
      lit.uniq.sort_by { |sq| [sq[1], sq[0]] }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The list's keys as said, in the background's order, each with the keys that press it now.
    def self.list_keys
      args = {}
      LIST_KEYS.each { |act, button, sym, painted| args[act] = key_names(button, sym, painted) }
      PokeAccess::I18n.t(:sv_dex_keys, args)
    end

    # The names of the keys that press a game button now: those the game's Input reads for it (FL's Set the Controls
    # keeps the player's choice there), else the one painted; through KeyHints for a button the mod's remap moves.
    def self.key_names(button, sym, painted)
      codes = (::Input.buttonToKey(::Input.const_get(button)) rescue nil) || []
      names = codes.select { |c| c.to_i > 0 }.map { |c| PokeAccess::ConfigMenu.keyname(c) }.uniq
      names = [PokeAccess::ConfigMenu.keyname(painted)] if names.empty?
      t = names[-1]
      t = PokeAccess::I18n.t(:list_or, :rest => names[0..-2].join(", "), :last => t) if names.length > 1
      sym ? PokeAccess::KeyHints.key(sym, t) : t
    end

    # The list's key hint as a watcher pair once the list's first row has been read (its row reader holds a key),
    # while key hints are said; nil before.
    def self.keys_pair(scene)
      win = PokeAccess.sprite(scene, "pokedex")
      return nil if win.nil? || PokeAccess::Cursor.current(win, :cmd_focus).nil? || !PokeAccess::Verbosity.hints?
      t = list_keys
      [t, t]
    end
  end
end

PokeAccess::Game.define("sevii") do
  # The nest page's places come from each map's own point, the squares drawn kept for data it cannot read.
  override("PokeAccess::DexEntry", :lit_squares) do |_mod, original, args|
    PokeAccess::SeviiDex.lit_squares(args[1], args[2], args[3]) || original.call
  end
end

# The list's loop reads its focused row on its first frame; the key hint comes on a later frame, queued behind it.
PokeAccess::SceneWatcher.reader("PokemonPokedexScene", :pbPokedex, :sv_dex_keys) do |s|
  PokeAccess::SeviiDex.keys_pair(s)
end
