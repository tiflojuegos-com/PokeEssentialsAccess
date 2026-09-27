module PokeAccess
  # Rejuvenation's Pokedex (PokedexScene.rb): list rows shaped [species, name, height, weight, base stats, number,
  # gender, form], a header with the dex's name and its seen and owned counts, and, once two dexes are open, a menu of
  # regions first, each its name, owned of total and a seen bar, turned with left and right.
  module RejuvDex
    # A list row as drawItem paints it: its number and name with the caught or seen ball, or its number and dashes;
    # nil for a row of another shape. The national dex counts a species seen in any form, a regional one or a search
    # only in the row's form.
    def self.row(win, c)
      return nil unless c.is_a?(Array) && c[4].is_a?(Array)
      species = c[0]
      form = c[-1]
      dex = $Trainer.pokedex
      scene = PokeAccess.ivar(win, :@scene)
      whole = ($PokemonGlobal.pokedexIndex rescue 0) == 0 && !(scene.searchResults rescue false)
      seen = dex.seen?(species, form) || (whole && dex.seen?(species)) ? true : false
      owned = dex.owned?(species, form) || (whole && dex.owned?(species)) ? true : false
      PokeAccess::Menus.dex_row(c[5].to_i, species, c[1], seen, owned)
    rescue StandardError
      nil
    end

    # The text a window of the list's sprites paints, or "".
    def self.window_text(scene, key)
      h = PokeAccess.ivar(scene, :@pokedexSprites)
      w = h.is_a?(Hash) ? h[key] : nil
      (w ? w.text : "").to_s
    rescue StandardError
      ""
    end

    # The header as pbRefreshMainMenu paints it, the dex's name (or the search's results) with its seen and owned
    # counts; said when it changes, queued behind what is being said.
    def self.header(scene)
      name = PokeAccess.clean(window_text(scene, "dexname"))
      seen = window_text(scene, "seen")[/\d+/]
      owned = window_text(scene, "owned")[/\d+/]
      return if name.empty? || seen.nil? || owned.nil?
      return unless PokeAccess::Cursor.changed?(scene, :rj_dex_head, [name, seen, owned])
      PokeAccess.speak(PokeAccess::I18n.t(:dex_region_counts, :name => name, :seen => seen, :owned => owned), false)
    rescue StandardError
      nil
    end

    # The region the menu shows: its name, seen and owned of its total, as its window, counters and bars paint it.
    def self.region_text(scene)
      entry = PokeAccess.ivar(scene, :@list)[PokeAccess.ivar(scene, :@regionMenuIndex)]
      return nil unless entry
      PokeAccess::I18n.t(:dex_region_counts_tot, :name => PokeAccess.clean(entry[:name]), :seen => entry[:seen],
                                                  :owned => entry[:owned], :tot => entry[:total])
    rescue StandardError
      nil
    end

    # Says the region under the menu when it opens, queued, and on each turn, cutting in.
    def self.follow_region(scene)
      return unless PokeAccess.ivar(scene, :@activeScene) == :region
      i = PokeAccess.ivar(scene, :@regionMenuIndex)
      PokeAccess::Cursor.announce(scene, :rj_dex_region, i, true, false) { region_text(scene) }
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  override("PokeAccess::Menus", :dex_list_row) do |_mod, original, args|
    PokeAccess::RejuvDex.row(args[0], args[1]) || original.call
  end

  after("PokemonPokedexScene", :pbRefreshMainMenu, :optional => true) do |scene, _r, _a|
    PokeAccess::RejuvDex.header(scene)
  end

  after("PokemonPokedexScene", :pbStartRegionScene, :optional => true) do |scene, _r, _a|
    PokeAccess::Cursor.reset(scene, :rj_dex_region)
    PokeAccess::RejuvDex.follow_region(scene)
  end

  before("PokemonPokedexScene", :pbUpdate, :optional => true) do |scene, _a|
    PokeAccess::RejuvDex.follow_region(scene)
  end
end
