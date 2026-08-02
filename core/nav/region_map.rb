module PokeAccess
  # Region map / fast travel: pbGetMapLocation(x,y) gives the place name under the cursor, announced on
  # change; pbGetMapDetails(x,y) gives that place's DESCRIPTION, offered on the info key.
  module RegionMap
    # Announces the place name under the cursor when the square changes (deduped per scene via Cursor;
    # pbStartScene resets the slot so reopening on the same square still reads). A nameless square still
    # consumes the dedup key, so leaving and returning to a named one re-reads it.
    #
    # The description is STORED, never spoken: many towns carry one ("Pueblo Lienzo" -> "Laboratorio
    # Flare") and reading it on every cursor move would bury the names the player is scanning for. Stored
    # for the info key, it costs nothing until asked for -- the same shape as the Options screen's help.
    def self.announce(scene, name, x, y)
      t = PokeAccess::Cursor.on_change(scene, :region_map, [x, y]) { name.to_s.strip }
      return if t.nil?
      remember_details(scene, x, y)
      PokeAccess.speak(t, true) unless t.empty?
    end

    # Keeps the focused place's description for the info key, or clears it where there is none -- most
    # points have no description (routes, towers), and a stale one would answer for the wrong place.
    def self.remember_details(scene, x, y)
      d = (scene.pbGetMapDetails(x, y) rescue nil)
      d = PokeAccess.clean(d).to_s.strip if d
      PokeAccess::Info.set_info(:text, (d.nil? || d.empty?) ? nil : d)
    rescue StandardError
      nil
    end

    # Drops the stored description when the map closes, so the info key does not answer with a place the
    # player left behind.
    def self.forget(scene)
      PokeAccess::Cursor.reset(scene, :region_map)
      PokeAccess::Info.set_info(:text, nil)
    rescue StandardError
      nil
    end
  end
end

# Two class names in the wild for the same gen-6-style region map with pbGetMapLocation(x, y): the
# vanilla "PokemonRegionMapScene" and the underscore variant "PokemonRegionMap_Scene" used by Arcky's
# Region Map plugin and some fangames. Each hook no-ops where its class is absent. (v22 uses
# UI::TownMapVisuals, handled in nav/v22/town_map_v22.)
#
# All three implementations -- gen-6 vanilla, the v21+ UI rework and Arcky's -- expose the same three
# readers under the same names (location, details, healing spot), so no per-engine adapter is needed here;
# what differs between them (where the cursor lives, how the point list is stored) only matters for MOVING
# the cursor, which this file does not do.
PokeAccess::Engine.scene_classes("PokemonRegionMapScene", "PokemonRegionMap_Scene").each do |cn|
  PokeAccess::Hooks.after_hook(cn, :pbGetMapLocation) do |s, ret, args|
    PokeAccess::RegionMap.announce(s, ret, args[0], args[1])
  end
  # The same two moments tell TownMap whether the screen is up, which is what lets J/K/L/I mean "jump to a
  # flyable place" here and keep meaning the locator's actions everywhere else. pbStartScene is a container:
  # it drives the whole map loop, and guarding it would silence every reader inside.
  PokeAccess::Hooks.before_hook(cn, :pbStartScene) do |s, _a|
    PokeAccess::RegionMap.forget(s)
    PokeAccess::TownMap.opened(s)
  end
  PokeAccess::Hooks.after_hook(cn, :pbEndScene) do |s, _r, _a|
    PokeAccess::RegionMap.forget(s)
    PokeAccess::TownMap.closed(s)
  end
end
