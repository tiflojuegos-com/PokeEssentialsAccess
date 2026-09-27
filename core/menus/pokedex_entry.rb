module PokeAccess
  # The gen-6 Pokedex entry scenes, all graphics: PokemonPokedexScene (info), PokedexFormScene (forms) and
  # PokemonNestMapScene (area). The modern PokemonPokedexInfo_Scene is PokedexInfoV21's (core/battle/v21).
  module DexEntry
    # A run of question marks for a withheld value ("????.? m", unit and all), said as a word; a lone "?" stays.
    UNKNOWN_MARKS = /\?[\?.'"]*\?(?:\s*(?:m|kg|lbs\.?))?/

    # A page's own label for the type icons (Royal's "Tipo"), in the builds' languages: the type names follow it bare.
    TYPE_LABEL = /\A(?:tipos?|types?|typ(?:en)?)\s*:?\z/i

    def self.unknown_marks(s)
      s.to_s.gsub(UNKNOWN_MARKS) { PokeAccess::I18n.t(:pdx_unknown_short) }
    end

    # An entry's painted info page plus its icons (owned mark, types); nil if nothing was painted. At the Pokedex
    # page reading's level: first row and owned mark always, category and types from medium, the rest at full.
    # param rows the painted texts in reading order (PaintCapture.laid_out)
    # param owned true, false, or nil when the era could not tell
    def self.painted_entry(rows, owned, types)
      rows = PokeAccess::PaintCapture.pair_labels((rows || []).map { |r| unknown_marks(PokeAccess.clean(r.to_s)) })
      return nil if rows.empty?
      parts = [[rows.shift, :brief]]
      parts.push([PokeAccess::I18n.t(:dex_caught), :brief]) if owned
      parts.push([rows.shift, :medium]) unless rows.empty?
      typed = []
      unless types.nil? || types.empty?
        at = rows.index { |r| r =~ TYPE_LABEL }
        if at
          rows.insert(at + 1, types.join(" "))
          typed = [at, at + 1]
        else
          parts.push([PokeAccess::I18n.t(:pdx_type, :t => types.join(" ")), :medium])
        end
      end
      rows.each_with_index { |r, i| parts.push([r, typed.include?(i) ? :medium : :full]) }
      PokeAccess::Verbosity.info_line(:dex_page, parts)
    end

    # Speaks the info page on each species change, as painted (painted_entry), else composed from the dummy pokemon.
    # param pairs the page's capture, taken around pbChangeToDexEntry, or nil
    # param species the species changed to, for pre-v16 copies (Insurgence's) that keep no dummy pokemon
    def self.gen6_info(scene, pairs = nil, species = nil)
      pk = PokeAccess.ivar(scene, :@dummypokemon)
      sp = pk ? (pk.species rescue nil) : species
      return if sp.nil?
      owned = PokeAccess::Util.dex_owned?(sp) ? true : false
      t = painted_entry(PokeAccess::PaintCapture.laid_out(pairs || []), owned, gen6_types(pk, sp, owned))
      t ||= gen6_composed(pk, sp, owned)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # The type names the gen-6 page draws for an owned species: the dummy pokemon's, else those of the form an
    # engine's data provider says its Pokedex last showed, else the species data's.
    def self.gen6_types(pk, sp, owned)
      return [] unless owned
      return PokeAccess::Data.optional(:dex_shown_types, sp) || PokeAccess::Data.species_types(sp) if pk.nil?
      [(pk.type1 rescue nil), (pk.type2 rescue nil)].compact.uniq.map { |t| PokeAccess::Data.type_name(t) }.compact
    rescue StandardError
      []
    end

    # The entry composed from the dummy pokemon when nothing was painted (the name alone without one), at the Pokedex
    # page reading's level.
    def self.gen6_composed(pk, sp, owned)
      nm = (PokeAccess::Data.species_name(sp) || sp.to_s)
      return PokeAccess::Verbosity.info_line(:dex_page, [[nm, :brief], [PokeAccess::I18n.t(:pdx_not_caught), :brief]], ". ") unless owned
      return PokeAccess::Verbosity.info_line(:dex_page, [[nm, :brief]]) if pk.nil?
      parts = [[nm, :brief], [PokeAccess::I18n.t(:dex_category, :cat => (pk.kind rescue "")), :medium]]
      h = (pk.height rescue 0) / 10.0
      w = (pk.weight rescue 0) / 10.0
      parts.push([PokeAccess::I18n.t(:dex_height, :h => PokeAccess::Pokedex.fmt_float(h), :n => h), :full])
      parts.push([PokeAccess::I18n.t(:dex_weight, :w => PokeAccess::Pokedex.fmt_float(w), :n => w), :full])
      e = (pk.dexEntry rescue nil)
      parts.push([PokeAccess.clean(e), :full]) if e && !e.to_s.empty?
      PokeAccess::Verbosity.info_line(:dex_page, parts, ". ")
    end

    # Set while the form chooser runs.
    def self.choosing_form!(v); @choosing_form = v; end

    # Speaks the shown form after its species name (painted above the form line); silent while the chooser is up.
    def self.gen6_form(scene)
      return if @choosing_form
      g = PokeAccess.ivar(scene, :@gender); f = PokeAccess.ivar(scene, :@form)
      av = (scene.instance_variable_get(:@available) rescue [])
      hit = (av.find { |i| i[1] == g && i[2] == f } rescue nil)
      return unless hit
      sp = PokeAccess.ivar(scene, :@species)
      nm = (PBSpecies.getName(sp) rescue nil) if sp
      t = PokeAccess::Util.join_parts([nm, PokeAccess::I18n.t(:dex_form, :form => hit[0])])
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # Speaks the nest page's bottom bar as captured during pbStartScene (deduped rows, else composed from its ivars),
    # then the places the map lights.
    # param regionmap the region pbStartScene was asked for, -1 or nil for the player's own
    def self.gen6_area(scene, rows, regionmap = -1)
      t = rows.is_a?(Array) ? rows.uniq.join(", ") : ""
      if t.strip.empty?
        mb = PokeAccess.sprite(scene, "mapbottom")
        return unless mb
        loc = (mb.maplocation rescue nil)
        det = (mb.instance_variable_get(:@mapdetails) rescue nil)
        t = PokeAccess::Util.join_parts([loc, det])
      end
      places = nest_places(scene, regionmap)
      t = "#{t}. #{PokeAccess::I18n.t(:pdx_places, :list => places.join(', '))}" unless places.empty?
      PokeAccess.speak_clean(t, true)
    rescue StandardError
      nil
    end

    # The places the gen-6 nest page lights, from its point sprites (each 2 px up and left of its square), named by
    # the town map of the region on show: the scene's own copy, else the one an engine's data provider keeps.
    def self.nest_places(scene, regionmap)
      map = PokeAccess.sprite(scene, "map")
      n = PokeAccess.ivar(scene, :@numpoints).to_i
      return [] unless map && n > 0
      w = nest_square(:SQUAREWIDTH)
      h = nest_square(:SQUAREHEIGHT)
      squares = (0...n).map { |i| PokeAccess.sprite(scene, "point#{i}") }.compact.map do |s|
        [(s.x + 2 - map.x) / w, (s.y + 2 - map.y) / h]
      end
      region = nest_region(regionmap)
      points = (PokeAccess.ivar(scene, :@mapdata)[region][2] rescue nil) ||
               PokeAccess::Data.optional(:town_points, region) || []
      places_at(points, squares)
    rescue StandardError
      []
    end

    # A town map square's size in pixels: the region map scene's constant, else the 16 the pre-v16 nest page
    # (Insurgence's) lays its points on, whose region map defines none.
    def self.nest_square(name)
      k = PokemonRegionMapScene
      k.const_defined?(name) ? k.const_get(name) : 16
    end

    # The region on show: the one pbStartScene was asked for, else the player's current one, from an engine's data
    # provider where it keeps its map data, else from the metadata.
    def self.nest_region(regionmap)
      r = regionmap.nil? ? -1 : regionmap.to_i
      return r if r >= 0
      pos = $game_map ? PokeAccess::Data.optional(:map_position, $game_map.map_id) : nil
      pos ||= (($game_map ? pbGetMetadata($game_map.map_id, MetadataMapPosition) : nil) rescue nil)
      pos ? pos[0] : 0
    end

    # The town map's names for the lit squares, in order, once each; a point behind a switch still off is skipped.
    # param points the town map's points, [x, y, name, ..., switch] in every era
    # param squares [x, y] pairs
    def self.places_at(points, squares)
      names = []
      squares.each do |x, y|
        loc = points.find { |pt| pt[0] == x && pt[1] == y && !(pt[7] && !$game_switches[pt[7]]) }
        next unless loc
        nm = place_name(loc[2])
        names.push(nm) unless nm.empty? || names.include?(nm)
      end
      names
    end

    # A town map point's name in the game's language, through whichever message table this era keeps them in.
    def self.place_name(raw)
      n = (pbGetMessageFromHash(MessageTypes::REGION_LOCATION_NAMES, raw) rescue nil)
      n = (pbGetMessageFromHash(MessageTypes::PlaceNames, raw) rescue nil) if n.nil? || n.to_s.empty?
      (n.nil? || n.to_s.empty? ? raw : n).to_s
    end
  end
end

PokeAccess::Hooks.before_hook("PokemonPokedexScene", :pbChangeToDexEntry) { |_s, _a| PokeAccess::PaintCapture.arm(:dex6_info) }
PokeAccess::Hooks.after_hook("PokemonPokedexScene", :pbChangeToDexEntry) do |s, _r, args|
  PokeAccess::DexEntry.gen6_info(s, PokeAccess::PaintCapture.take_pairs(:dex6_info), args[0])
end
# The v16-v17 form page; older copies (Insurgence) and reworked ones (Reborn, Uranium) redraw it without pbRefresh.
PokeAccess::Hooks.after_hook("PokedexFormScene", :pbRefresh, :optional => true) { |s, _r, _a| PokeAccess::DexEntry.gen6_form(s) }

# The form chooser's window is read by the generic hook; the page reader stands down while it is up.
PokeAccess::Hooks.around_hook("PokedexFormScene", :pbChooseForm, :optional => true) do |_s, nxt, _a|
  PokeAccess::DexEntry.choosing_form!(true)
  begin
    nxt.call
  ensure
    PokeAccess::DexEntry.choosing_form!(false)
  end
end
PokeAccess::Hooks.before_hook("PokemonNestMapScene", :pbStartScene) do |_s, _a|
  PokeAccess::PaintCapture.arm(:nest_area)
end
PokeAccess::Hooks.after_hook("PokemonNestMapScene", :pbStartScene) do |s, _r, args|
  PokeAccess::DexEntry.gen6_area(s, PokeAccess::PaintCapture.take(:nest_area), args[1])
end
