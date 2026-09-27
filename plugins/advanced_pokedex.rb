# FL's Advanced Pokedex (Relict, Soulstones; Awakening behind switch 199): a fourth entry page whose sub-pages, the
# species' data and its moves by level, egg, machine and tutor, displaySubPage paints outside drawPage. Read from the
# paint, column by column, then "sub-page n/total"; on the way in the name and types lead. The v17 copies leave a label
# with no value empty ("HOLD ITEMS: " above "EVO: ..."); Relict's writes "None".
module PokeAccess
  module AdvancedPokedex
    # A painted row that opens with a label of its own ("EVO: Ivysaur at level 16", or a bare "HOLD ITEMS:").
    LABEL = /\A[^:]+:(\s|\z)/

    # The grid's rows, column by column, as lines: a label left without its value ("HOLD ITEMS:" with no item) takes
    # the row below it only when joins? says that row finishes it.
    # param rows take_pairs rows sorted by column, then line
    def self.grid_lines(rows)
      pitch = line_pitch(rows)
      out = []
      prev = nil
      rows.each do |r|
        t = PokeAccess.clean(r[0].to_s).strip
        next if t.empty?
        if prev && joins?(out.last, prev, r, t, pitch)
          out[-1] = "#{out.last} #{t}"
        else
          out.push(t)
        end
        prev = r
      end
      out
    end

    # Whether a row finishes the label painted above it: the label ends in a colon, the row sits on the next line of
    # the same column (within pitch, when known) and opens with no label of its own.
    def self.joins?(label, above, row, text, pitch)
      return false unless label =~ /:\z/ && above[2] == row[2] && text !~ LABEL
      pitch.nil? || row[3] - above[3] <= pitch
    end

    # The grid's line height: the smallest step between two rows of one column, or nil with no column of two.
    def self.line_pitch(rows)
      steps = []
      rows.each_with_index do |r, i|
        n = rows[i + 1]
        steps.push(n[3] - r[3]) if n && n[2] == r[2] && n[3] > r[3]
      end
      steps.min
    end

    # The page's text from its painted rows: the grid column by column, the name and the page count apart.
    # param entering true when the page was just opened (drawPage), which leads with the name and types
    def self.text(scene, pairs, entering)
      rows = (pairs || []).select { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) }
      return nil if rows.empty?
      bottom_y = rows.map { |r| r[3] }.max
      name_y = rows.map { |r| r[3] }.select { |y| y >= bottom_y - 40 }.min
      grid = rows.select { |r| r[3] < name_y }.sort_by { |r| [r[2], r[3]] }
      foot = rows.select { |r| r[3] >= name_y }.sort_by { |r| [r[3], r[2]] }.map { |r| PokeAccess.clean(r[0].to_s) }
      count = foot.find { |t| t =~ %r{\A\d+/\d+\z} }
      name = (foot - [count]).first
      parts = []
      if entering
        parts.push(name) if name
        ty = types(scene)
        parts.push(PokeAccess::I18n.t(:pdx_type, :t => ty.join(" "))) unless ty.empty?
      end
      parts.concat(grid_lines(grid))
      if count && PokeAccess::Verbosity.keep?(:positions, :medium) && count =~ %r{\A(\d+)/(\d+)\z}
        parts.push(PokeAccess::I18n.t(:adv_dex_page, :n => $1, :m => $2))
      end
      t = parts.reject { |p| p.to_s.strip.empty? }.join(", ")
      t.empty? ? nil : t
    end

    # The type names the page's icons show: the form's data where the copy keeps it (@data, Relict), the
    # two type ids it read from the dex data where it does not (@type1/@type2, Awakening).
    def self.types(scene)
      data = PokeAccess.ivar(scene, :@data)
      list = (data.types rescue nil)
      return list.map { |t| (GameData::Type.get(t).name rescue t.to_s) } if list.is_a?(Array) && !list.empty?
      ids = [PokeAccess.ivar(scene, :@type1), PokeAccess.ivar(scene, :@type2)].compact.uniq
      ids.map { |t| PokeAccess::Data.type_name(t) }.compact
    rescue StandardError
      []
    end

    # Speaks the sub-page as it is painted, when it says something new.
    def self.read(scene, pairs, entering)
      t = text(scene, pairs, entering)
      return if t.nil?
      return unless PokeAccess::Cursor.changed?(scene, :adv_dex, t)
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    # Brackets a paint of the page and reads it; this capture stands in for the core page reader's.
    def self.capture(scene, entering)
      PokeAccess::PaintCapture.arm(:adv_dex)
      begin
        yield
      ensure
        read(scene, PokeAccess::PaintCapture.take_pairs(:adv_dex), entering)
      end
    end
  end
end

# Page 4 as drawPage shows it (the core page reader runs drawPage guarded, which skips displaySubPage's hook); each
# of the two page readers forgets its last line when the other takes over.
PokeAccess::Hooks.around_hook("PokemonPokedexInfo_Scene", :drawPage, :optional => true) do |scene, nxt, args|
  unless args[0].to_i == 4
    PokeAccess::Cursor.reset(scene, :adv_dex)
    next nxt.call
  end
  PokeAccess::Cursor.reset(scene, :pdx_page)
  PokeAccess::AdvancedPokedex.capture(scene, true) { nxt.call }
end

# The sub-pages the action buttons flip, outside drawPage.
PokeAccess::Hooks.around_hook("PokemonPokedexInfo_Scene", :displaySubPage, :optional => true) do |scene, nxt, _a|
  PokeAccess::AdvancedPokedex.capture(scene, false) { nxt.call }
end
