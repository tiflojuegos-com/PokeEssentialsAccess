module PokeAccess
  # The region map of the engine Reborn, Rejuvenation and Desolation share, which draws an icon for each roaming
  # Pokemon: its roaming<i> sprites, one per RoamingSpecies entry, each centred on its square of the map.
  module RegionMapRV
    # The roaming Pokemon whose icons the map draws on a square, by species.
    def self.roamers_at(scene, x, y)
      map = PokeAccess.sprite(scene, "map")
      return [] unless map && defined?(RoamingSpecies) && RoamingSpecies.is_a?(Array)
      w = scene.class::SQUAREWIDTH
      h = scene.class::SQUAREHEIGHT
      left = ((Graphics.width rescue 512) - map.bitmap.width) / 2
      top = ((Graphics.height rescue 384) - map.bitmap.height) / 2
      out = []
      RoamingSpecies.each_with_index do |entry, i|
        s = PokeAccess.sprite(scene, "roaming#{i}")
        next unless s && entry.is_a?(Hash) && (s.visible rescue true)
        sx = (s.x + s.bitmap.width / 2 - left) / w
        sy = (s.y + s.bitmap.height / 2 - top) / h
        name = PokeAccess::Data.species_name(entry[:species])
        out.push(name) if [sx, sy] == [x, y] && name
      end
      out
    rescue StandardError
      []
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::RegionMap, :square_marks, :tag => "rv_common") do |_mod, original, args|
  original.call + PokeAccess::RegionMapRV.roamers_at(*args)
end
