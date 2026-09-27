module PokeAccess
  # The ZUD plugin's Max Raid database (RaidDataScene): search panel with filter values and match count, species
  # grid, species pages. Its values live in locals, so the text painted on its overlays is noted by position.
  module ZudRaidDatabase
    # The painted values of the filter rows, by the height each is drawn at, and the line under them.
    VALUE_ROWS = { 143 => 1, 175 => 2, 207 => 3, 239 => 4 }
    FOOT_Y = 340

    # The species page's move lists as [heading key, column x, in the lower row], the lower row from MOVES_BOTTOM.
    MOVE_LISTS = [[:zud_raid_primary, 92, false], [:zud_raid_secondary, 270, false],
                  [:zud_raid_spread, 92, true], [:zud_raid_support, 270, true]]
    MOVES_BOTTOM = 212

    def self.open(scene)
      @scene = scene
      @values = {}
      @count = nil
      @selecting = false
      @name = nil
      @page = nil
      @page_seen = nil
      PokeAccess.dedicate(PokeAccess.sprite(scene, "settings"))
      PokeAccess.speak(PokeAccess::I18n.t(:zud_raid_title), false)
    end

    def self.close; @scene = nil; end

    def self.open?; !@scene.nil?; end

    # Entering or leaving the grid; back on the search panel, its first row is read again.
    def self.selecting(on)
      @selecting = on
      @name = nil
      @page_seen = nil
      PokeAccess::Cursor.reset(@scene, :zud_raid_row) if @scene && !on
    end

    # Back on the grid from a species page, which repaints nothing: the species under the cursor again.
    def self.back_on_grid
      PokeAccess.speak(@name, true) if @scene && @selecting && @name
    end

    # A string the game painted on the database's overlays: a filter's value, the count of matches, a
    # species name or the page, told apart by where it went.
    def self.note(bitmap, text, y)
      return unless @scene
      t = PokeAccess.clean(text.to_s)
      return if t.empty?
      if bitmap.equal?(PokeAccess.ivar(@scene, :@pagetext))
        @page = t if t =~ /\d+\s*\/\s*\d+/
      elsif bitmap.equal?(PokeAccess.ivar(@scene, :@overlay))
        if y.to_i == FOOT_Y
          @selecting ? species(t) : count(t)
        elsif VALUE_ROWS[y.to_i]
          @values[VALUE_ROWS[y.to_i]] = t.sub(/\A\[/, "").sub(/\]\z/, "")
        end
      end
    rescue StandardError
      nil
    end

    # Says the count of matches when a filter changed it, resetting the row slot so the first row the game
    # returns to is queued behind it.
    def self.count(t)
      return if t == @count
      @count = t
      PokeAccess.speak(t, false)
      PokeAccess::Cursor.reset(@scene, :zud_raid_row)
    end

    # The focused species, with the page when it is a new one and positions are said.
    def self.species(t)
      return if t == @name
      @name = t
      parts = [t]
      parts.push(@page) if @page && @page != @page_seen && PokeAccess::Verbosity.keep?(:positions, :medium)
      @page_seen = @page
      PokeAccess.speak(parts.join(". "), true)
    end

    # The search panel's focused row, with the value painted beside a filter. The panel's command window
    # is the database's own, claimed from the generic reader, which would say the row without its value.
    def self.poll
      return unless @scene
      claim_filter
      return if @selecting
      win = PokeAccess.sprite(@scene, "settings")
      return unless win && (win.visible rescue false)
      idx = (win.index rescue nil)
      return unless idx
      cmds = (win.commands rescue nil) || []
      PokeAccess::Cursor.announce(@scene, :zud_raid_row, [idx, @values[idx]], true, false) do
        v = @values[idx]
        v ? "#{cmds[idx]}: #{v}" : cmds[idx].to_s
      end
    rescue StandardError
      nil
    end

    # Leaves the filter list (a second command window, hidden but while a filter is chosen) to the generic
    # reader only while it shows.
    def self.claim_filter
      f = PokeAccess.sprite(@scene, "filter")
      f.instance_variable_set(:@access_dedicated, !(f.visible rescue false)) if f
    end

    # A species page from its paint: the data column in reading order, labels joined to values and pictures in
    # their places, then each move list under its heading.
    # param sp the species' data, or nil
    def self.page_text(pairs, sp)
      rows = pairs.select { |p| p[2].is_a?(Numeric) && p[3].is_a?(Numeric) }
      column = rows.select { |p| p[2] >= 360 } + pictures(sp)
      info = PokeAccess::PaintCapture.pair_labels(PokeAccess::PaintCapture.lines(column))
      lists = MOVE_LISTS.map do |key, x, bottom|
        moves = rows.select { |p| p[2] == x && (p[3] >= MOVES_BOTTOM) == bottom }.sort_by { |p| p[3] }
        PokeAccess::I18n.t(key, :list => moves.map { |p| PokeAccess.clean(p[0].to_s) }.join(", "))
      end
      (info + lists).join(". ")
    end

    # The column's pictures as rows placed where it draws them: the arrows to the species' other forms, beside its
    # sprite, as the place of this one among them; the G-Max Factor mark above the form's name, for a species that
    # has one; and the types under it.
    def self.pictures(sp)
      return [] unless sp.respond_to?(:type1)
      out = []
      form = form_text(sp)
      out.push([form, :positions, 432, 92]) if form
      out.push([PokeAccess::I18n.t(:dmax_factor), :positions, 472, 124]) if (sp.hasGmax? rescue false)
      types = [sp.type1, sp.type2].uniq.map { |t| (::GameData::Type.get(t).name rescue t.to_s) }
      out.push([PokeAccess::I18n.t(:zud_raid_types, :list => types.join(", ")), :positions, 367, 194])
      out
    end

    # The page's form among the species' raid forms, which left and right step through, as a position; nil for a
    # species with one, or where positions go unsaid. From the plugin's own list: the arrows are set after the page.
    def self.form_text(sp)
      return nil unless PokeAccess::Verbosity.keep?(:positions, :medium)
      forms = (pbGetAvailableRaidForms(sp.species) rescue nil)
      return nil unless forms.is_a?(Array) && forms.length > 1
      i = forms.index((sp.id rescue nil))
      i ? PokeAccess::I18n.t(:zud_raid_form, :n => i + 1, :tot => forms.length) : nil
    end

    # Captures a species page's paint (pbSetSpeciesData, on opening and on each form) and says it, with the move
    # lists whole from the scene rather than the nine rows painted.
    def self.species_page(scene, species)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      say_page(scene, (::GameData::Species.get(species) rescue nil), pairs)
      ret
    end

    # Says a species page from its paint. It runs inside the database's own call, so it never raises.
    def self.say_page(scene, sp, pairs)
      full = full_moves(scene)
      pairs = pairs.reject { |p| MOVE_LISTS.any? { |_k, x, _b| p[2] == x } } + full if full
      t = page_text(pairs, sp)
      PokeAccess.speak(t, true) unless t.empty?
    rescue StandardError
      nil
    end

    # The four move lists whole, as rows placed where the page paints them.
    def self.full_moves(scene)
      lists = [:@datamoves1, :@datamoves2, :@datamoves3, :@datamoves4].map { |iv| PokeAccess.ivar(scene, iv) }
      return nil unless lists.all? { |l| l.is_a?(Array) }
      out = []
      lists.each_with_index do |moves, i|
        _key, x, bottom = MOVE_LISTS[i]
        y0 = bottom ? MOVES_BOTTOM : 24
        if moves.empty?
          out.push([(_INTL("None Found") rescue "None Found"), :positions, x, y0])
        else
          moves.each_with_index { |m, j| out.push([(::GameData::Move.get(m).name rescue m.to_s), :positions, x, y0 + j * 0.001]) }
        end
      end
      out
    end
  end
end

PokeAccess::Hooks.around_hook("RaidDataScene", :pbRaidData, :optional => true) do |scene, nxt, _a|
  PokeAccess::ZudRaidDatabase.open(scene)
  begin; nxt.call; ensure; PokeAccess::ZudRaidDatabase.close; end
end
PokeAccess::Hooks.around_hook("RaidDataScene", :pbSpeciesSelect, :optional => true) do |_scene, nxt, _a|
  PokeAccess::ZudRaidDatabase.selecting(true)
  begin; nxt.call; ensure; PokeAccess::ZudRaidDatabase.selecting(false); end
end
PokeAccess::Hooks.around_hook("RaidDataScene", :pbSetSpeciesData, :optional => true) do |scene, nxt, args|
  PokeAccess::ZudRaidDatabase.species_page(scene, args[0]) { nxt.call }
end
PokeAccess::Hooks.around_hook("RaidDataScene", :pbRaidDataBase, :optional => true) do |_scene, nxt, _a|
  begin; nxt.call; ensure; PokeAccess::ZudRaidDatabase.back_on_grid; end
end
# Every text the game paints goes through these two; they look at it only while the database is open.
PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "plugin_zud_raid_pbDrawTextPositions", :before) do |args, _r|
  next unless PokeAccess::ZudRaidDatabase.open?
  (args[1] || []).each { |r| PokeAccess::ZudRaidDatabase.note(args[0], r[0], r[2]) if r.is_a?(Array) }
end
PokeAccess::Hooks.wrap_kernel("drawTextEx", "plugin_zud_raid_drawTextEx", :before) do |args, _r|
  PokeAccess::ZudRaidDatabase.note(args[0], args[5], args[2]) if PokeAccess::ZudRaidDatabase.open?
end
PokeAccess::Keys.on_frame { PokeAccess::ZudRaidDatabase.poll }
