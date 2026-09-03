module PokeAccess
  # Region map / fast travel: pbGetMapLocation(x,y) gives the place name under the cursor, announced on
  # change; pbGetMapDetails(x,y) gives that place's DESCRIPTION, offered on the info key.
  module RegionMap
    # Announces the place name under the cursor when the square changes (deduped per scene via Cursor;
    # pbStartScene resets the slot so reopening on the same square still reads). A nameless square still
    # consumes the dedup key, so leaving and returning to a named one re-reads it. The description is STORED
    # for the info key and never spoken: many towns carry one, and reading it on every cursor move would
    # bury the names the player is scanning for.
    #
    # It ends by marking the bottom bar's dedup slot with what it just said. All thirteen games have BOTH
    # this screen and a MapBottomSprite, so that reader fires on the same cursor move with the same name and
    # would interrupt this line with an identical one. Marked rather than removed, because on Arcky's
    # extended map screens nothing calls pbGetMapLocation and the bottom bar is the only voice there. Both
    # the spoken line and the mark are CLEANED, the line because a place name can carry colour codes, the
    # mark because that reader keys on cleaned text and a raw code would yield two keys for one name.
    # The mark passes through _INTL first: royal's fork assigns _INTL(name) to its bottom bar, so a
    # translation table entry would give the bar a DIFFERENT string than the one spoken here and both
    # would voice, cutting each other. In the twelve vanilla copies _INTL without a loaded translation
    # returns its argument, so the mark is byte-identical to before.
    def self.announce(scene, name, x, y)
      t = PokeAccess::Cursor.on_change(scene, :region_map, [x, y]) { name.to_s.strip }
      return if t.nil?
      remember_details(scene, x, y)
      speak_marked(t)
    end

    # Speaks a place line and marks the bottom-bar slot with the string that bar will paint for it (through
    # _INTL, see announce). Every map provider with a bottom bar goes through here, so the mark rule lives once.
    def self.speak_marked(raw)
      t = PokeAccess.clean(raw.to_s)
      return if t.empty?
      PokeAccess.speak(t, true)
      mark = PokeAccess.clean((_INTL(raw) rescue raw).to_s)
      PokeAccess::Cursor.changed?(nil, :regionmap, mark.empty? ? t : mark)
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

# Two class names in the wild for the same gen-6-style region map with pbGetMapLocation(x, y): the vanilla
# "PokemonRegionMapScene" and the underscore variant "PokemonRegionMap_Scene" used by Arcky's Region Map
# plugin and some fangames, each hook no-oping where its class is absent (v22 uses UI::TownMapVisuals, in
# nav/v22/town_map_v22). All three implementations expose the same three readers under the same names, so
# no per-engine adapter is needed here; what differs -- where the cursor lives, how the point list is
# stored -- only matters for MOVING the cursor, which this file does not do.
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
