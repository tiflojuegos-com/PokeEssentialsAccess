module PokeAccess
  # The gen-6 Pokedex entry scenes, all graphics: PokemonPokedexScene (info), PokedexFormScene (forms) and
  # PokemonNestMapScene (area). The modern PokemonPokedexInfo_Scene is PokedexInfoV21's (core/battle/v21).
  module DexEntry
    # A run of question marks for a withheld value ("????.? m", "???'??\"", unit and all), said as a word; a lone
    # "?" stays.
    UNKNOWN_MARKS = /\?[\?.'"]*\?(?:"|\s*(?:m|kg|lbs\.?))?/

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

    # Speaks the info page on each species change, as painted (painted_entry), else composed from the dummy pokemon;
    # browsing the entries, arriving at it from the list or another page adds its key hint.
    # param pairs the page's capture, taken around pbChangeToDexEntry, or nil
    # param species the species changed to, for pre-v16 copies (Insurgence's) that keep no dummy pokemon
    def self.gen6_info(scene, pairs = nil, species = nil)
      pk = PokeAccess.ivar(scene, :@dummypokemon)
      sp = pk ? (pk.species rescue nil) : species
      return if sp.nil?
      owned = PokeAccess::Util.dex_owned?(sp) ? true : false
      t = painted_entry(PokeAccess::PaintCapture.laid_out(pairs || []), owned, gen6_types(pk, sp, owned))
      t ||= gen6_composed(pk, sp, owned)
      t = PokeAccess.sentences([t, PokeAccess::I18n.t(:pdx_info_hint)]) if turn_to(:info) && PokeAccess::Verbosity.hints?
      PokeAccess.speak(t, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The type names the gen-6 page draws for an owned species: the dummy pokemon's, else those of the form an
    # engine's data provider says its Pokedex last showed, else the species data's.
    def self.gen6_types(pk, sp, owned)
      return [] unless owned
      return PokeAccess::Data.optional(:dex_shown_types, sp) || PokeAccess::Data.species_types(sp) if pk.nil?
      [(pk.type1 rescue nil), (pk.type2 rescue nil)].compact.uniq.map { |t| PokeAccess::Data.type_name(t) }.compact
    rescue StandardError => e
      PokeAccess.swallowed(e)
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

    # The marks a form can be named with alone (Unown's "?????" and "!!!!!"), by the key of the mark's name.
    MARK_FORMS = { "?" => :unown_question, "!" => :unown_exclaim }

    # Runs the entry browser (pbDexEntry) with its pages noting themselves as shown (turn_to); a capture's entry,
    # whose tabs are blanked, runs outside it.
    def self.browse
      was = @browsing
      @browsing = true
      @page = nil
      yield
    ensure
      @browsing = was
    end

    # Notes the entry page now shown while the entries are browsed; true when it is not the one shown before, as on
    # opening the entry or coming back from another page.
    def self.turn_to(page)
      return false unless @browsing
      was = @page
      @page = page
      was != page
    end

    # True while the form chooser runs.
    def self.choosing_form?; @choosing_form ? true : false; end

    # A form named with a mark alone, which a screen reader leaves unsaid, as the mark's name; any other name untouched.
    def self.form_name(name)
      key = name.to_s.strip =~ /\A([?!])\1*\z/ ? MARK_FORMS[$1] : nil
      key ? PokeAccess::I18n.t(key) : name
    end

    # The form page's line: its page's name after the species' (painted above the form line), then the form shown;
    # the species alone for a gender and form the page does not list, the form alone on a page that keeps no species.
    def self.form_line(scene)
      g = PokeAccess.ivar(scene, :@gender); f = PokeAccess.ivar(scene, :@form)
      av = (scene.instance_variable_get(:@available) rescue [])
      hit = (av.find { |i| i[1] == g && i[2] == f } rescue nil)
      sp = PokeAccess.ivar(scene, :@species)
      nm = (PBSpecies.getName(sp) rescue nil) if sp
      head = (nm.nil? || nm.to_s.empty?) ? nil : PokeAccess::I18n.t(:pdx_forms, :name => nm)
      t = PokeAccess::Util.join_parts([head, hit ? PokeAccess::I18n.t(:dex_form, :form => form_name(hit[0])) : nil])
      t.empty? ? nil : t
    end

    # Speaks the form page's line and keeps it for the info key; while the chooser is up it only notes the lines drawn.
    def self.gen6_form(scene)
      t = form_line(scene)
      if @choosing_form
        (@chooser_drawn ||= []).push(t)
        return
      end
      turn_to(:forms)
      return if t.nil?
      PokeAccess::Info.set_info(:text, t, t)
      PokeAccess.speak(t, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs the form chooser with the page reader standing down (chooser_closed after it).
    def self.choose_form(scene)
      @choosing_form = true
      @chooser_drawn = []
      begin
        r = yield
      ensure
        @choosing_form = false
      end
      chooser_closed(scene, (::Input.trigger?(::Input::B) rescue false))
      r
    end

    # Once a chooser that redrew the page closes, keeps the page's line for the info key; cancelled with B, which
    # redraws the form it puts back, says it when the last move drew another.
    def self.chooser_closed(scene, cancelled)
      drawn = @chooser_drawn || []
      @chooser_drawn = nil
      t = drawn.empty? ? nil : form_line(scene)
      return if t.nil?
      PokeAccess::Info.set_info(:text, t, t)
      PokeAccess.speak(t, true) if cancelled && drawn.length >= 2 && drawn[-2] != t
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Speaks the nest page under its page's name: its bottom bar as captured during pbStartScene (deduped rows, else
    # composed from its ivars), then the places the map lights; kept for the info key.
    # param regionmap the region pbStartScene was asked for, -1 or nil for the player's own
    # param species the species shown, whose name heads the page's; nil leaves the page's name out
    def self.gen6_area(scene, rows, regionmap = -1, species = nil)
      turn_to(:area)
      t = rows.is_a?(Array) ? rows.uniq.join(", ") : ""
      if t.strip.empty?
        mb = PokeAccess.sprite(scene, "mapbottom")
        return unless mb
        loc = (mb.maplocation rescue nil)
        det = (mb.instance_variable_get(:@mapdetails) rescue nil)
        t = PokeAccess::Util.join_parts([loc, det])
      end
      places = nest_places(scene, regionmap, species)
      t = "#{t}. #{PokeAccess::I18n.t(:pdx_places, :list => places.join(', '))}" unless places.empty?
      nm = species.nil? ? nil : (PBSpecies.getName(species) rescue nil)
      head = (nm.nil? || nm.to_s.empty?) ? nil : PokeAccess::I18n.t(:pdx_zone, :name => nm)
      t = PokeAccess.clean(PokeAccess::Util.join_parts([head, t]))
      PokeAccess::Info.set_info(:text, t, t)
      PokeAccess.speak(t, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The places the gen-6 nest page lights (lit_squares), named by the town map of the region on show: the scene's
    # own copy, else the one an engine's data provider keeps.
    # param species the species shown, for a page whose squares are worked out again from the game's data
    def self.nest_places(scene, regionmap, species = nil)
      region = nest_region(regionmap)
      points = (PokeAccess.ivar(scene, :@mapdata)[region][2] rescue nil) ||
               PokeAccess::Data.optional(:town_points, region) || []
      places_at(points, lit_squares(scene, species, region, points))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # The squares the gen-6 nest page lights, from its point sprites (each 2 px up and left of its square); a profile
    # whose page draws its points off the squares it means overrides it, given the species, region and town points.
    def self.lit_squares(scene, _species, _region, _points)
      map = PokeAccess.sprite(scene, "map")
      n = PokeAccess.ivar(scene, :@numpoints).to_i
      return [] unless map && n > 0
      w = nest_square(:SQUAREWIDTH)
      h = nest_square(:SQUAREHEIGHT)
      (0...n).map { |i| PokeAccess.sprite(scene, "point#{i}") }.compact.map do |s|
        [(s.x + 2 - map.x) / w, (s.y + 2 - map.y) / h]
      end
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
# The entry browser opened from the list, a loop: around, so the pages' hooks inside it still fire.
PokeAccess::Hooks.around_hook("PokemonPokedexScene", :pbDexEntry, :optional => true) do |_s, nxt, _a|
  PokeAccess::DexEntry.browse { nxt.call }
end
# The v16-v17 form page; older copies (Insurgence) and reworked ones (Reborn, Uranium) redraw it without pbRefresh.
PokeAccess::Hooks.after_hook("PokedexFormScene", :pbRefresh, :optional => true) { |s, _r, _a| PokeAccess::DexEntry.gen6_form(s) }

# The form chooser's window is read by the generic hook; the page reader stands down while it is up.
PokeAccess::Hooks.around_hook("PokedexFormScene", :pbChooseForm, :optional => true) do |s, nxt, _a|
  PokeAccess::DexEntry.choose_form(s) { nxt.call }
end
PokeAccess::Hooks.before_hook("PokemonNestMapScene", :pbStartScene) do |_s, _a|
  PokeAccess::PaintCapture.arm(:nest_area)
end
PokeAccess::Hooks.after_hook("PokemonNestMapScene", :pbStartScene) do |s, _r, args|
  PokeAccess::DexEntry.gen6_area(s, PokeAccess::PaintCapture.take(:nest_area), args[1], args[0])
end
