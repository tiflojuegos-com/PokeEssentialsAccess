# Placing furniture in the decorable base (PlaceDecoration_Scene, _PluginScripts/Granja decorable). The
# existing granja reader only covers the two LISTS (pockets and decorations); this is the step after picking
# one, where a free cursor moves over the map to choose the spot. Nothing about it is spoken: not the tile
# under the cursor, not what is already there, and not whether the piece actually fits -- so a blind player
# could only place things by luck.
#
# pbUpdate runs once per frame from the scene's own loop, so reading there covers every cursor move. Whether
# the piece fits comes from the scene's own can_place_here?, which is the same check the game uses to decide,
# so the answer can never disagree with what pressing the button would do.
module PokeAccess
  module RoyalDecorating
    # Voices the cursor tile and whether the held decoration can go there.
    def self.focus(scene)
      x = PokeAccess.ivar(scene, :@cursor_x)
      y = PokeAccess.ivar(scene, :@cursor_y)
      return if x.nil? || y.nil?
      PokeAccess::Cursor.announce(scene, :roy_deco, [x, y], true) do
        parts = [PokeAccess::I18n.t(:mg_rowcol, :row => y.to_i, :col => x.to_i)]
        item = PokeAccess.ivar(scene, :@item)
        if item
          data = (GameData::SecretBaseDecoration.get(item[0]) rescue nil)
          nm = (data.name rescue nil)
          parts.push(nm.to_s) if nm && !nm.to_s.empty?
          ok = (scene.can_place_here?(data, x, y, nil) rescue nil)
          parts.push(PokeAccess::I18n.t(ok ? :roy_deco_ok : :roy_deco_no)) unless ok.nil?
        end
        parts.join(", ")
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  after("PlaceDecoration_Scene", :pbUpdate) { |s, _r, _a| PokeAccess::RoyalDecorating.focus(s) }
end
