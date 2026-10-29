# World Frontier's own shops (Tiendas WF), grids of icons with no list window: the Pokemon shop (PokemonShop_Scene,
# pbPokemonShop at the Pokemon Center), which sells Pokemon for Battle Points, and its copy of the Battle Point shop
# (BattlePointShop_Scene), whose grid of item icons replaces the stock list. Each says its focused cell as the panel
# beside the grid paints it; the core reads the Battle Point shop's bag and points windows and its prompts.
module PokeAccess
  module WfShops
    # The Pokemon shop's focused cell: the name and price painted under the grid and its place in the list.
    def self.pokemon_line(scene)
      list = PokeAccess.ivar(scene, :@filtered_pokemon)
      idx = PokeAccess.ivar(scene, :@cursor_index)
      return nil unless list.is_a?(Array) && idx.is_a?(Integer)
      return PokeAccess::I18n.t(:wf_shop_empty) if list.empty?
      species = list[idx]
      return nil unless species
      name = (scene.shop_species_label(species) rescue PokeAccess::Data.species_name(species)).to_s
      price = (PokemonShop.get_price(species) rescue nil)
      row = price ? "#{name}, #{_INTL('PB: {1}', price)}" : name
      PokeAccess::Verbosity.list_entry(row, idx + 1, list.length)
    end

    # The Pokemon shop's header as painted: its title, the player's points and the order the grid follows.
    def self.pokemon_header(scene)
      points = (_INTL("PB: {1}", $player.battle_points) rescue nil)
      PokeAccess.sentences([_INTL("TIENDA DE POKÉMON"), points, sort_text(scene)])
    end

    # The order the grid follows, as painted.
    def self.sort_text(scene)
      PokeAccess.ivar(scene, :@sort_mode) == :pokedex ? _INTL("Orden: Nº Dex.") : _INTL("Orden: Alfab.")
    end

    # After each repaint of the Pokemon shop, but while the search is typed: the header and the keys as it opens; the
    # order when it changes, then the focused Pokemon queued after it, the cursor having followed it to its new place;
    # else the focused Pokemon when it moves.
    def self.pokemon(scene)
      return if PokeAccess.ivar(scene, :@access_typing)
      opening = PokeAccess::Cursor.pending?(scene, :wf_pshop_sort)
      if PokeAccess::Cursor.changed?(scene, :wf_pshop_sort, PokeAccess.ivar(scene, :@sort_mode))
        PokeAccess.speak_clean(opening ? pokemon_header(scene) : sort_text(scene), !opening)
        PokeAccess::Cursor.reset(scene, :wf_pshop)
      end
      text = pokemon_line(scene)
      return unless text
      list = PokeAccess.ivar(scene, :@filtered_pokemon)
      key = [PokeAccess.ivar(scene, :@cursor_index), (list.is_a?(Array) ? list[PokeAccess.ivar(scene, :@cursor_index)] : nil)]
      said = PokeAccess::Cursor.announce(scene, :wf_pshop, key, true, false) { text }
      return unless said && opening
      PokeAccess::WfHint.say(_INTL("[C]: Comprar   [D]: Buscar   [Z]: Orden   [{1}]: Salir",
                                   (KeybindingReader.key_name(:BACK) rescue "X")))
    end

    # The search ended: what it looks for, as painted while one is active, and the Pokemon it leaves focused.
    def self.searched(scene)
      search = PokeAccess.ivar(scene, :@search_text).to_s
      PokeAccess::Cursor.reset(scene, :wf_pshop)
      PokeAccess.speak_clean(_INTL("Buscar: {1}", search), true) unless search.empty?
      pokemon(scene)
    end

    # The Battle Point shop's focused cell, named and priced as the core says a shop row (the exit cell as a cancel
    # row), with its place in the grid.
    def self.bp(scene)
      idx = PokeAccess.ivar(scene, :@grid_cursor_index)
      stock = PokeAccess.ivar(scene, :@stock)
      return unless idx.is_a?(Integer) && stock.is_a?(Array)
      row = PokeAccess::Shops.row(scene, idx)
      return if row.nil? || row.to_s.empty?
      text = PokeAccess::Verbosity.list_entry(row.to_s, idx + 1, stock.length + 1)
      PokeAccess::Cursor.announce(scene, :wf_bpshop, idx, true, false) { text }
    end
  end
end

PokeAccess::Game.define("worldfrontier") do
  after("PokemonShop_Scene", :pbRefresh) { |scene, _r, _a| PokeAccess::WfShops.pokemon(scene) }
  # The search repaints the grid at each key; its result is said once the field closes.
  around("PokemonShop_Scene", :pbSearch) do |scene, nxt, _a|
    scene.instance_variable_set(:@access_typing, true)
    begin
      nxt.call
    ensure
      scene.instance_variable_set(:@access_typing, nil)
      begin
        PokeAccess::WfShops.searched(scene)
      rescue StandardError => e
        PokeAccess.swallowed(e)
      end
    end
  end
  after("BattlePointShop_Scene", :pbRefresh) { |scene, _r, _a| PokeAccess::WfShops.bp(scene) }
end
