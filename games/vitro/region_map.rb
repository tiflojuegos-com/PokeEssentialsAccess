# Vitro's region map is its own copy of Marin's better one (0288_Marin Better Map), which pbShowMap and Fly open: it paints the
# places through the game's translations (its update_text, the patch), and an icon for each roaming Pokemon loose on the map
# (drawRoamingPosition), in sight from the start: each is said with its place as the map opens, and on its square as the
# cursor passes it.
module PokeAccess
  module VitroMap
    # A row of the map's data with its place and its point of interest as the screen paints them.
    def self.translated(row)
      return row unless row.is_a?(Array)
      out = row.dup
      out[2] = pbGetMessageFromHash(MessageTypes::PlaceNames, row[2])
      out[3] = pbGetMessageFromHash(MessageTypes::PlaceDescriptions, row[3]) if row[3] && !row[3].empty?
      out
    rescue StandardError => e
      PokeAccess.swallowed(e)
      row
    end

    # The roamers the map draws, as [species, square x, square y]: an icon scrolls with the map, its centre half a tile into
    # its square.
    def self.roamers(scene)
      win = PokeAccess.ivar(scene, :@window)
      out = []
      $PokemonGlobal.roamPosition.each do |index, _map|
        species = getID(PBSpecies, RoamingSpecies[index][0])
        icon = species && (win["roaming#{species}"] rescue nil)
        next unless icon
        out.push([species, ((icon.x - win.x - BetterRegionMap::TileWidth / 2) / BetterRegionMap::TileWidth).round,
                  ((icon.y - win.y - BetterRegionMap::TileHeight / 2) / BetterRegionMap::TileHeight).round])
      end
      out
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # The rows of a square's line for the roamers drawn on it.
    def self.square_rows(scene, x, y)
      here = roamers(scene).select { |_species, sx, sy| sx == x && sy == y }
      here.map { |species, _sx, _sy| [PokeAccess::Data.species_name(species), :brief] }
    end

    # A square's place as the screen names it, or its coordinates.
    def self.place(scene, x, y)
      rows = PokeAccess.ivar(scene, :@data)[2]
      row = rows.find { |e| e[0] == x && e[1] == y }
      name = row ? PokeAccess.clean(translated(row)[2].to_s) : ""
      name.empty? ? PokeAccess::I18n.t(:brm_square, :x => x, :y => y) : name
    end

    # Says each roamer at its place as the map opens, queued; nothing with none drawn.
    def self.opening(scene)
      list = roamers(scene).map do |species, x, y|
        PokeAccess::I18n.t(:rmap_roamer, :name => PokeAccess::Data.species_name(species), :place => place(scene, x, y))
      end
      PokeAccess.speak(PokeAccess::I18n.t(:rmap_roamers, :list => list.join(", ")), false) unless list.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  override("PokeAccess::BetterMap", :location) do |_mod, original, _args|
    PokeAccess::VitroMap.translated(original.call)
  end
  override("PokeAccess::BetterMap", :square_parts) do |_mod, original, args|
    original.call + PokeAccess::VitroMap.square_rows(*args)
  end
  before("BetterRegionMap", :main, :optional => true) { |scene, _a| PokeAccess::VitroMap.opening(scene) }
end
