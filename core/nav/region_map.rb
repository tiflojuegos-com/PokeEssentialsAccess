module PokeAccess
  # Region map / fast travel: pbGetMapLocation(x,y) gives the place name under the cursor, announced on
  # change; pbGetMapDetails(x,y) gives the detail the bar paints beside it (a point of interest), said after the
  # place where descriptions are said and kept for the info key.
  module RegionMap
    # Announces the square under the cursor when it changes, stores its description for the info key, and marks the
    # bottom bar's dedup slot with the name (speak_marked) so the bar does not repeat it.
    def self.announce(scene, name, x, y)
      return if building?
      first = PokeAccess.ivar(scene, :@access_first_sq).nil?
      scene.instance_variable_set(:@access_first_sq, [x, y]) if first
      scene.instance_variable_set(:@access_player_sq, [x, y]) if first && PokeAccess.ivar(scene, :@access_you_later)
      t = PokeAccess::Cursor.on_change(scene, :region_map, [x, y]) { square_text(scene, name, x, y) }
      return if t.nil?
      remember_details(scene, x, y)
      speak_marked(t, !first, name)
    end

    # The square's line: its place, or its coordinates where it has none (a move over blank sea is still heard), the
    # detail beside it where descriptions are said, and the marks drawn on it.
    def self.square_text(scene, name, x, y)
      place = PokeAccess.clean(name.to_s)
      parts = [place.empty? ? PokeAccess::I18n.t(:brm_square, :x => x, :y => y) : place]
      parts.push(details(scene, x, y)) if PokeAccess::Verbosity.descriptions?
      parts.compact!
      parts.push(PokeAccess::I18n.t(:brm_fly)) if fly_here?(scene, x, y)
      parts.push(PokeAccess::I18n.t(:rmap_you)) if player_square?(scene, x, y)
      parts.concat(square_marks(scene, x, y))
      parts.join(", ")
    end

    # What a map draws on a square beyond its place, the fly icon and the player's head (a roaming Pokemon's icon), as
    # words; none on a stock map, and a profile whose map draws more overrides it.
    def self.square_marks(_scene, _x, _y)
      []
    end

    # Whether the square is the one the map opened on, where the player's head is drawn; a map screen whose squares
    # repeat across several maps overrides it in its profile.
    def self.player_square?(scene, x, y)
      PokeAccess.ivar(scene, :@access_player_sq) == [x, y]
    end

    # Whether the screen draws the fly icon on this square: in fly mode, on a square whose healing spot was visited.
    def self.fly_here?(scene, x, y)
      pt = PokeAccess.sprite(scene, "point0")
      return false unless pt && (pt.visible rescue true)
      spot = PokeAccess::TownMap.healing_spot(scene, [x, y])
      spot ? PokeAccess::TownMap.visited?(spot) : false
    end

    # Once the map is up with the player's head drawn, marks the opening square as the player's and says so; after a
    # silent build (building), the first square's line says it instead.
    def self.opened(scene)
      return unless PokeAccess.sprite(scene, "player")
      sq = PokeAccess.ivar(scene, :@access_first_sq)
      return scene.instance_variable_set(:@access_you_later, true) unless sq
      scene.instance_variable_set(:@access_player_sq, sq)
      PokeAccess.speak(PokeAccess::I18n.t(:rmap_you), false)
    end

    # Runs a map screen's build with its squares and bottom bar unsaid, for a screen that asks for a square's place
    # before it settles (Armonia's second map).
    def self.building
      @building = true
      yield
    ensure
      @building = false
    end

    def self.building?; @building ? true : false; end

    # Speaks a place line and marks the bottom bar's dedup slot with the name that bar will paint (through _INTL).
    # param place the bare place name the bar paints, when the line says more
    def self.speak_marked(raw, interrupt = true, place = nil)
      t = PokeAccess.clean(raw.to_s)
      return if t.empty?
      PokeAccess.speak(t, interrupt)
      bare = place.nil? ? raw : place
      mark = PokeAccess.clean((_INTL(bare) rescue bare).to_s)
      PokeAccess::Cursor.changed?(nil, :regionmap, mark.empty? ? t : mark)
    end

    # The detail the bar paints for a square, cleaned, or nil where it paints none.
    def self.details(scene, x, y)
      d = (scene.pbGetMapDetails(x, y) rescue nil)
      d = PokeAccess.clean(d.to_s) if d
      (d.nil? || d.empty?) ? nil : d
    rescue StandardError
      nil
    end

    # Keeps the focused place's detail for the info key, or clears it where there is none.
    def self.remember_details(scene, x, y)
      PokeAccess::Info.set_info(:text, details(scene, x, y))
    rescue StandardError
      nil
    end

    # Resets the cursor dedup and the square marks and drops the stored description, as the map opens and closes.
    def self.forget(scene)
      PokeAccess::Cursor.reset(scene, :region_map)
      scene.instance_variable_set(:@access_first_sq, nil)
      scene.instance_variable_set(:@access_player_sq, nil)
      scene.instance_variable_set(:@access_you_later, nil)
      PokeAccess::Info.clear_text
    rescue StandardError
      nil
    end
  end
end

# The region map under both class names (PokemonRegionMapScene, and PokemonRegionMap_Scene of Arcky's plugin and
# some fangames); v22's is in nav/v22/town_map_v22.
PokeAccess::Engine.scene_classes("PokemonRegionMapScene", "PokemonRegionMap_Scene").each do |cn|
  PokeAccess::Hooks.after_hook(cn, :pbGetMapLocation) do |s, ret, args|
    PokeAccess::RegionMap.announce(s, ret, args[0], args[1])
  end
  # Opening and closing tell TownMap the screen is up (J/K/L/I jump between flyable places). The after hook on
  # pbStartScene is a container: it runs the whole map loop, and a guarded one would mute every reader inside.
  PokeAccess::Hooks.before_hook(cn, :pbStartScene) do |s, _a|
    PokeAccess::RegionMap.forget(s)
    PokeAccess::TownMap.opened(s)
  end
  PokeAccess::Hooks.after_hook(cn, :pbStartScene, :hook_container => true) do |s, _r, _a|
    PokeAccess::RegionMap.opened(s)
  end
  PokeAccess::Hooks.after_hook(cn, :pbEndScene) do |s, _r, _a|
    PokeAccess::RegionMap.forget(s)
    PokeAccess::TownMap.closed(s)
  end
end
