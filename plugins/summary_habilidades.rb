# The EV/IV sub-screen ("Habilidades", C on the stats page), a blocking loop: its paint is captured on entry and
# spoken by the frame poll in paint order, bar the rows painted away from what they belong to (label, value pairs
# repeat, so no uniq). The stats page's picture draws the C key that opens it, said with the page.
module PokeAccess
  module SummaryHabilidades
    def self.poll
      return unless PokeAccess::PaintCapture.pending?(:sum_habilidades)
      rows = ordered(PokeAccess::PaintCapture.take_pairs(:sum_habilidades))
      return if rows.empty?
      PokeAccess.speak_clean(rows.join(", "), false)
    rescue StandardError
      nil
    end

    # The sheet's rows as take_pairs gives them, in paint order but for three: a label ending in a colon takes the
    # value painted right of it on its line (the ability, painted after the header below it), a lone sex sign joins
    # the row left of it on its line (the name), and a paragraph follows the row above it at its left edge (the
    # ability's description, painted last).
    def self.ordered(pairs)
      rest = Array(pairs).dup
      out = []
      until rest.empty?
        r = rest.shift
        t = PokeAccess.clean(r[0].to_s)
        next if t.empty?
        x = r[2]
        y = r[3]
        unless x.is_a?(Numeric) && y.is_a?(Numeric)
          out.push([t, nil, nil])
          next
        end
        if PokeAccess::Party::SIGNS.include?(t) && (host = row_left_of(out, x, y))
          host[0] = "#{host[0]} #{t}"
          next
        end
        if r[1] == :dtex && (above = row_above(out, x, y))
          out.insert(out.index { |e| e.equal?(above) } + 1, [t, x, y])
          next
        end
        if t =~ /:\z/ && (value = value_right_of(rest, x, y))
          rest.delete_at(rest.index { |e| e.equal?(value) })
          t = "#{t} #{PokeAccess.clean(value[0].to_s)}".strip
        end
        out.push([t, x, y])
      end
      out.map { |e| e[0] }
    end

    # The nearest row still to come on this line, right of x: a label's value.
    def self.value_right_of(rest, x, y)
      rest.select { |e| e[3] == y && e[2].is_a?(Numeric) && e[2] > x }.min_by { |e| e[2] }
    end

    # The nearest row already said on this line, left of x.
    def self.row_left_of(out, x, y)
      out.select { |e| e[2] == y && e[1].is_a?(Numeric) && e[1] < x }.max_by { |e| e[1] }
    end

    # The lowest row already said above y that starts at x: the heading a paragraph sits under.
    def self.row_above(out, x, y)
      out.select { |e| e[1] == x && e[2].is_a?(Numeric) && e[2] < y }.max_by { |e| e[2] }
    end

    # The stats page's text followed, once, by the key its picture draws for this sheet, while key hints are said,
    # on a summary that has the sheet.
    def self.with_key(scene, page, text)
      return text unless page == 3 && text && scene.respond_to?(:Habilidades) && PokeAccess::Verbosity.hints?
      key = PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:sumh_key))
      text.to_s.end_with?(key) ? text : PokeAccess.sentences([text, key])
    rescue StandardError
      text
    end
  end
end

# The sheet closes by redrawing the stats page it covered: the page is forgotten on the way in, so it is said again.
PokeAccess::Hooks.before_hook("PokemonSummaryScene", :Habilidades, :optional => true) do |s, _a|
  PokeAccess::Summary.forget_page(s)
  PokeAccess::PaintCapture.arm(:sum_habilidades)
end
PokeAccess::Keys.on_frame { PokeAccess::SummaryHabilidades.poll }

PokeAccess::Hooks.override(PokeAccess::Summary, :speak_page, :tag => "summary_habilidades") do |_mod, original, args|
  args[3] = PokeAccess::SummaryHabilidades.with_key(args[0], args[2], args[3])
  original.call
end
