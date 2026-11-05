module PokeAccess
  # Tamas's DexNav: a map's wild species on a screen (PokemonDexNav_Scene), a grid of icons for land and another for
  # water beside a column of details, and the search on the map: grass that rustles near the player until they step on
  # it or it runs away, and an overlay with the Pokémon found.
  module TamasDexNav
    # Where the column of details starts.
    COLUMN_X = 347

    # Runs a repaint, the block, and says what it shows (say); answers the repaint's value.
    def self.draw(scene)
      ret = nil
      rows = PokeAccess::PaintCapture.sample { ret = yield }
      say(scene, rows)
      ret
    end

    # Says a repaint when the species or the grid changed, the first one queued and the next ones cutting in: on a map
    # with no species only the title and that, which is all the screen is left with. The info key keeps the line.
    # param rows what the repaint painted, as PaintCapture.sample gives it
    def self.say(scene, rows)
      species = PokeAccess.ivar(scene, :@active_species)
      first = PokeAccess::Cursor.pending?(scene, :tamas_dexnav)
      key = [species, PokeAccess.ivar(scene, :@is_grass), PokeAccess.ivar_i(scene, :@cursor)]
      PokeAccess::Cursor.announce(scene, :tamas_dexnav, key, true, false) do
        texts = rows.map { |r| r[0].to_s }
        lines = species ? captions(scene, texts, first) + species_lines(scene, species, rows) : [texts.first, texts.last]
        t = PokeAccess.clean(PokeAccess.sentences(lines))
        PokeAccess::Info.set_info(:text, t, t)
        t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What the screen paints before anything else, in this order: the title, said on opening; the grid's caption and the
    # key that changes it, the other's, said when the grid changed.
    def self.captions(scene, texts, first)
      out = first ? [texts[0]] : []
      return out unless PokeAccess::Cursor.changed?(scene, :tamas_dexnav_grid, PokeAccess.ivar(scene, :@is_grass))
      out.push(texts[1])
      out.push(texts[2]) if PokeAccess::Verbosity.hints?
      out
    end

    # The focused species: its name and place, its types once seen, then each label of the column with what is painted
    # under it, and the chain.
    def self.species_lines(scene, species, rows)
      top, groups = column(rows)
      chain, name = top
      total = PokeAccess.ivar(scene, :@act_list).length
      head = PokeAccess::Verbosity.list_entry(name, PokeAccess.ivar_i(scene, :@cursor) + 1, total)
      if ($player.pokedex.seen?(species) rescue false)
        types = GameData::Species.get(species).types.map { |ty| PokeAccess::Data.type_name(ty) }.join("/")
        head = "#{head}, #{types}"
      end
      [head] + groups.map { |g| "#{g[0]}: #{g[1..-1].join(', ')}" } + [chain]
    end

    # The column as it reads, top to bottom: the lines above the first label (the chain, the species' name), and each
    # label with the lines under it, those with only marks ("---", what the species does not show yet) left out and a
    # label with none left dropped.
    def self.column(rows)
      labels = PokeAccess.const_at("Constant::TEXTS_SMALL").values.map { |p| PokeAccess.clean(p[:text]) }
      top = []
      groups = []
      PokeAccess::PaintCapture.lines(rows) { |r| r[2] >= COLUMN_X }.each do |l|
        if labels.include?(l)
          groups.push([l])
        elsif l =~ /\A[\s\-]*\z/
          next
        else
          (groups.empty? ? top : groups.last).push(PokeAccess::Menus.unknown_row(l))
        end
      end
      [top, groups.select { |g| g.length > 1 }]
    end

    # The search found one, as the overlay shows it: the Pokémon, its ability and egg move where it has them, the item,
    # its perfect IVs and where its grass rustles from the player. Queued, after the search's message.
    def self.found(info)
      @found = true
      parts = [info.get_pkmn.name, info.get_ability, info.get_move].reject { |p| p.to_s =~ /\A[\s\-]*\z/ }
      parts.push(GameData::Item.get(info.get_item).name) if info.overlay_item
      parts.push(PokeAccess::I18n.t(:tdn_ivs, :n => info.get_ivs)) if info.get_ivs > 0
      @shown = PokeAccess.clean(PokeAccess::I18n.t(:tdn_found, :list => parts.join(", ")))
      PokeAccess.speak(found_line, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # What the search found and where its grass is from the player now.
    def self.found_line
      coords = safeAccessDexNav.coords
      PokeAccess.sentences([@shown, from_player(coords[0], coords[1])])
    end

    # The info key on the map while a search runs, as a step's rustle cuts in on what it found; nil with none running.
    def self.map_line
      @shown && safeAccessDexNav.is_active? ? found_line : nil
    end

    # Where a tile is from the player.
    def self.from_player(x, y)
      PokeAccess::Locator.dir_phrase(x - $game_player.x, y - $game_player.y)
    end

    # A step's rustle, which only shows where the grass is: said from where the player now stands. The search's first
    # one comes with what it found.
    def self.rustled(x, y, first)
      PokeAccess.speak(from_player(x, y), true) unless first
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs a search, the block: one that brought up no overlay found nothing, which the map shows only by staying still.
    def self.searching
      @found = false
      ret = yield
      PokeAccess.speak(PokeAccess::I18n.t(:tdn_nothing), false) unless @found
      ret
    end
  end
end

PokeAccess::Info.map_owner(:tamas_dexnav) { PokeAccess::TamasDexNav.map_line }

PokeAccess::Hooks.around_hook("PokemonDexNav_Scene", :updateInfoBox, :optional => true) do |scene, nxt, _a|
  PokeAccess::TamasDexNav.draw(scene) { nxt.call }
end
PokeAccess::Hooks.clear_info_on("PokemonDexNav_Scene", :pbEndScene)

PokeAccess::Hooks.wrap_singleton("MyOverlayModule", :pbShowMyOverlay, "tamas_dexnav_found", :before) do |args, _r|
  PokeAccess::TamasDexNav.found(args[0])
end
PokeAccess::Hooks.wrap_global("showGrassShaking", "tamas_dexnav_rustle", :after) do |args, _r|
  PokeAccess::TamasDexNav.rustled(args[0], args[1], args[2])
end
PokeAccess::Hooks.wrap_global("pbDexNavSearchEvent", "tamas_dexnav_search", :around) do |_args, call_next|
  PokeAccess::TamasDexNav.searching { call_next.call }
end
