# Essentials BES's region map draws an icon for each roaming Pokemon loose on it (drawRoamingPosition, its
# roaming<species> sprites), with no text and in sight from the start: each is said with its place as the map opens, and
# on its square as the cursor passes it.
module PokeAccess
  module BesRegionMap
    # The roamers the map draws, as [species, square x, square y], by species; an icon with no picture shows nothing. The
    # game sets an icon's corner half a square before its square's start on the screen, whatever the icon's size.
    def self.roamers(scene)
      map = PokeAccess.sprite(scene, "map")
      sprites = PokeAccess.ivar(scene, :@sprites)
      return [] unless map && sprites.is_a?(Hash) && scene.respond_to?(:drawRoamingPosition)
      w, h = PokeAccess::RegionMap.square_size(scene)
      left = (Graphics.width - map.bitmap.width) / 2
      top = (Graphics.height - map.bitmap.height) / 2
      out = []
      sprites.each do |key, icon|
        next unless icon && key.to_s =~ /\Aroaming(\d+)\z/ && icon.bitmap
        out.push([$1.to_i, (icon.x + w / 2 - left) / w, (icon.y + h / 2 - top) / h])
      end
      out.sort
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # The names of the roamers drawn on a square.
    def self.names_at(scene, x, y)
      here = roamers(scene).select { |_species, sx, sy| sx == x && sy == y }
      here.map { |species, _sx, _sy| PokeAccess::Data.species_name(species) }.compact
    end

    # A square's place as the map names it, or its coordinates; asked with the squares unsaid, as asking is what makes
    # the map's reader say one.
    def self.place(scene, x, y)
      name = nil
      PokeAccess::RegionMap.building { name = scene.pbGetMapLocation(x, y) }
      name = PokeAccess.clean(name.to_s)
      name.empty? ? PokeAccess::I18n.t(:brm_square, :x => x, :y => y) : name
    end

    # The line the map opens with, each roamer at its place; nil with none drawn.
    def self.opening(scene)
      list = roamers(scene).map do |species, x, y|
        name = PokeAccess::Data.species_name(species)
        name ? PokeAccess::I18n.t(:rmap_roamer, :name => name, :place => place(scene, x, y)) : nil
      end.compact
      list.empty? ? nil : PokeAccess::I18n.t(:rmap_roamers, :list => list.join(", "))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::RegionMap, :square_marks, :tag => "bes_region_map") do |_mod, original, args|
  original.call + PokeAccess::BesRegionMap.names_at(*args)
end

PokeAccess::Hooks.override(PokeAccess::RegionMap, :opened, :tag => "bes_region_map") do |_mod, original, args|
  original.call
  line = PokeAccess::BesRegionMap.opening(args[0])
  PokeAccess.speak(line, false) if line
end
