# Secret base decorating ("Secret Bases Remade" and its fork "Granja decorable"): the category and decoration
# lists, PlaceDecoration_Scene's free cursor and the decoration shop; the fork's can_place_here? takes a fourth
# argument.
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

    # A decoration row: its name, whether it is already placed in the base and, while descriptions are said, the
    # description the screen's description window shows, which the info key always adds.
    def self.decoration_text(win, i, decoration_class)
      bag    = win.instance_variable_get(:@bag)
      pocket = win.instance_variable_get(:@pocket)
      items  = (bag.pockets[pocket] rescue nil)
      return nil unless items.is_a?(Array)
      return PokeAccess::I18n.t(:pc_cancel) if i >= items.length
      return nil unless items[i]
      data = (decoration_class.get(items[i][0]) rescue nil)
      nm = (data.name rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      row = (bag.is_placed?(pocket, i) rescue false) ? PokeAccess::I18n.t(:sb_placed, :name => nm) : nm.to_s
      desc = PokeAccess.clean((data.description rescue nil).to_s)
      whole = PokeAccess.sentences([row, desc])
      PokeAccess::Info.set_info(:text, whole, whole)
      PokeAccess::Verbosity.descriptions? ? whole : row
    rescue StandardError
      nil
    end

    # Whether a decoration anchored at (ax, ay), its bottom-right tile, is found at the tile (x, y), as the plugin's
    # own find_decorations_at walks a footprint: every row of a tileset piece, only the bottom row of one without a
    # tile offset (an event's sprite).
    def self.covers?(data, ax, ay, x, y)
      size = (data.tile_size rescue nil)
      return false unless size.is_a?(Array) && size.length == 2
      top = (data.tile_offset rescue nil) ? ay.to_i - size[1].to_i + 1 : ay.to_i
      x.between?(ax.to_i - size[0].to_i + 1, ax.to_i) && y.between?(top, ay.to_i)
    end

    # The shop's money window while it shows, said (queued) when its text changes: on opening, and after each purchase
    # or sale; the sale's window only shows around its question.
    def self.money(scene)
      win = PokeAccess.sprite(scene, "moneywindow")
      return unless win && (win.visible rescue false)
      t = PokeAccess.clean_fields((win.text rescue nil).to_s)
      return if t.empty? || t == PokeAccess.ivar(scene, :@access_money)
      scene.instance_variable_set(:@access_money, t)
      PokeAccess.speak(t, false, :menu)
    rescue StandardError
      nil
    end

    # The description the buy list shows beside the focused decoration (the shop adapter's, which the mod's item data
    # does not know): said once per decoration after its row while descriptions are said, and kept for the info key
    # with the name and for Ctrl+T with the row. Selling runs the base's own list, which says its own.
    def self.mart_description(scene)
      return if PokeAccess.ivar(scene, :@subscene)
      item = (PokeAccess.sprite(scene, "itemwindow").item rescue nil)
      return unless PokeAccess::Cursor.changed?(scene, :sb_mart_desc, [item])
      return if item.nil?
      ad = PokeAccess.ivar(scene, :@adapter)
      desc = PokeAccess.clean((ad.getDescription(item) rescue nil).to_s)
      return if desc.empty?
      name = PokeAccess.clean((ad.getDisplayName(item) rescue nil).to_s)
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([name, desc]),
                                PokeAccess.sentences([PokeAccess::Info.row_text, desc]))
      PokeAccess.speak(desc, false, :menu) if PokeAccess::Verbosity.descriptions?
    rescue StandardError
      nil
    end

    # The names of the placed decorations over a tile, from the base's [id, x, y] entries without calling the
    # plugin's finder (which empties a slot while it searches): the small ones set on top (:decor) first, as removing
    # takes them before what they stand on.
    def self.names_at(base, x, y)
      decos = (base.decorations rescue nil)
      return [] unless decos.is_a?(Array)
      found = []
      decos.each_with_index do |d, i|
        next unless d.is_a?(Array)
        data = (GameData::SecretBaseDecoration.get(d[0]) rescue nil)
        next unless data && covers?(data, d[1], d[2], x, y)
        found.push([(data.permission rescue nil) == :decor ? 0 : 1, i, data.name.to_s])
      end
      found.sort.map { |f| f[2] }
    end

    # One tile of the check, by the copy's own can_place_here? arity (only the fork takes pos); nil if absent.
    def self.tile_ok?(scene, data, x, y, pos)
      m = (scene.method(:can_place_here?) rescue nil)
      return nil if m.nil?
      ((m.arity == 4) ? m.call(data, x, y, pos) : m.call(data, x, y)) ? true : false
    rescue StandardError
      nil
    end

    # Whether the whole piece fits at (x, y), tiles walked in the plugin's order: true, false or nil if unknown.
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

    # The cursor tile and, carrying a decoration, its name from medium and whether it fits; removing (no @item),
    # what the tile holds. The info key keeps the whole.
    def self.focus(scene)
      x = PokeAccess.ivar(scene, :@cursor_x)
      y = PokeAccess.ivar(scene, :@cursor_y)
      return if x.nil? || y.nil?
      PokeAccess::Cursor.announce(scene, :sb_place, [x, y], true) do
        parts = [[PokeAccess::I18n.t(:mg_rowcol, :row => y.to_i, :col => x.to_i), :brief]]
        item = PokeAccess.ivar(scene, :@item)
        if item
          data = (GameData::SecretBaseDecoration.get(item[0]) rescue nil)
          nm = (data.name rescue nil)
          parts.push([nm.to_s, :medium]) if nm && !nm.to_s.empty?
          ok = fits?(scene, data, x, y)
          parts.push([PokeAccess::I18n.t(ok ? :sb_can_place : :sb_blocked), :brief]) unless ok.nil?
        else
          names = names_at(PokeAccess.ivar(scene, :@base), x.to_i, y.to_i)
          parts.push([names.empty? ? PokeAccess::I18n.t(:sb_nothing) : names.join(", "), :brief])
        end
        PokeAccess::Verbosity.info_line(:map_square, parts)
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

# Closing a decoration list takes its description off the info key.
["SecretBag_Scene", "SecretBagParedSuelo_Scene"].each do |cname|
  PokeAccess::Hooks.after_hook(cname, :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }
end

# The decoration shop (SecretBaseMart_Scene) writes its prompts and results in its own help window, outside
# pbMessageDisplay: each is said as it is shown, a yes/no's question before its choices. Its money window and the
# focused decoration's description are read on the frame update every one of its loops runs, after the list's own
# update has read the row.
[:pbDisplay, :pbDisplayPaused, :pbConfirm].each do |meth|
  PokeAccess::Hooks.before_hook("SecretBaseMart_Scene", meth, :optional => true) do |_s, args|
    PokeAccess.say_screen_message(args)
  end
end
PokeAccess::Hooks.after_hook("SecretBaseMart_Scene", :update, :optional => true) do |scene, _r, _a|
  PokeAccess::SecretBases.money(scene)
  PokeAccess::SecretBases.mart_description(scene)
end

PokeAccess::Verbosity.define_reading(:map_square, :vb_map_square, :vbh_map_square)
