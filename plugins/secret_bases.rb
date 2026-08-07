# Secret base decorating (the "Secret Bases Remade" plugin and its Spanish fork "Granja decorable"). Three
# steps, none of which the generic reader can see:
#
#   * Window_BasePocketsList     -> the decoration categories, named by SecretBag.pocket_names
#   * Window_BaseDecorationsList -> what is in the focused category, named by GameData::SecretBaseDecoration
#   * PlaceDecoration_Scene      -> a free cursor over the map, choosing where the piece goes
#
# Both list windows are the same code in both copies, so one extractor serves both.
#
# The placing step diverges: the fork rewrote can_place_here? against the tileset and added a fourth
# argument, the tile's position within the piece. The call is therefore shaped by the method's own arity --
# the wrong one raises every frame and the "it fits" answer, which a blind player cannot get any other way,
# is never spoken. The walls-and-floors variant exists in one copy only and simply never binds in the other.
module PokeAccess
  module SecretBases
    # A category row: its name and how full it is.
    def self.pocket_text(win, i, bag_module)
      count = (bag_module.pocket_count rescue 0)
      return PokeAccess::I18n.t(:pc_cancel) if i >= count
      nm = (bag_module.pocket_names[i] rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      bag = win.instance_variable_get(:@bag)
      cur = (bag.current_pocket_size(i + 1) rescue nil)
      mx  = (bag.max_pocket_size(i + 1) rescue 0)
      return nm.to_s if cur.nil?
      qty = (mx && mx > 0) ? PokeAccess::I18n.t(:sb_qty, :cur => cur, :max => mx) : cur.to_s
      "#{nm}, #{qty}"
    rescue StandardError
      nil
    end

    # A decoration row: its name, and whether it is already placed in the base.
    def self.decoration_text(win, i, decoration_class)
      bag    = win.instance_variable_get(:@bag)
      pocket = win.instance_variable_get(:@pocket)
      items  = (bag.pockets[pocket] rescue nil)
      return nil unless items.is_a?(Array)
      return PokeAccess::I18n.t(:pc_cancel) if i >= items.length
      return nil unless items[i]
      nm = (decoration_class.get(items[i][0]).name rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      (bag.is_placed?(pocket, i) rescue false) ? PokeAccess::I18n.t(:sb_placed, :name => nm) : nm.to_s
    rescue StandardError
      nil
    end

    # One tile of the check, called the way this copy declares it.
    # param pos the tile's position within the piece, which only the fork takes
    def self.tile_ok?(scene, data, x, y, pos)
      m = (scene.method(:can_place_here?) rescue nil)
      return nil if m.nil?
      ((m.arity == 4) ? m.call(data, x, y, pos) : m.call(data, x, y)) ? true : false
    rescue StandardError
      nil
    end

    # Whether the whole piece fits at (x, y): true, false, or nil when it cannot be decided. Walks the
    # footprint in the plugin's own order, so the answer cannot disagree with what the confirm key does.
    def self.fits?(scene, data, x, y)
      size = (data.tile_size rescue nil)
      return nil unless size.is_a?(Array) && size.length == 2
      width, height = size[0].to_i, size[1].to_i
      return nil if width < 1 || height < 1
      pos = 0
      ok = true
      (0...height).to_a.reverse.each do |h|
        (0...width).to_a.reverse.each do |w|
          tile = tile_ok?(scene, data, x + w - width + 1, y + h - height + 1, pos)
          return nil if tile.nil?
          ok = false unless tile
          pos += 1
        end
      end
      ok
    end

    # Voices the cursor tile and whether the held decoration can go there.
    def self.focus(scene)
      x = PokeAccess.ivar(scene, :@cursor_x)
      y = PokeAccess.ivar(scene, :@cursor_y)
      return if x.nil? || y.nil?
      PokeAccess::Cursor.announce(scene, :sb_place, [x, y], true) do
        parts = [PokeAccess::I18n.t(:mg_rowcol, :row => y.to_i, :col => x.to_i)]
        item = PokeAccess.ivar(scene, :@item)
        if item
          data = (GameData::SecretBaseDecoration.get(item[0]) rescue nil)
          nm = (data.name rescue nil)
          parts.push(nm.to_s) if nm && !nm.to_s.empty?
          ok = fits?(scene, data, x, y)
          parts.push(PokeAccess::I18n.t(ok ? :sb_can_place : :sb_blocked)) unless ok.nil?
        end
        parts.join(", ")
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_BasePocketsList") do |win, i|
  PokeAccess::SecretBases.pocket_text(win, i, SecretBag)
end
PokeAccess::Menus.def_extractor("Window_BaseDecorationsList") do |win, i|
  PokeAccess::SecretBases.decoration_text(win, i, GameData::SecretBaseDecoration)
end
PokeAccess::Menus.def_extractor("Window_BasePocketsListParedSuelo") do |win, i|
  PokeAccess::SecretBases.pocket_text(win, i, SecretBagParedesSuelos)
end
PokeAccess::Menus.def_extractor("Window_BaseDecorationsParedSueloList") do |win, i|
  PokeAccess::SecretBases.decoration_text(win, i, GameData::SecretBaseDecorationParedSuelo)
end

PokeAccess::Hooks.after_hook("PlaceDecoration_Scene", :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::SecretBases.focus(scene)
end
