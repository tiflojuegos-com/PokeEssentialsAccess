module PokeAccess
  # Improved Mementos (Royal): the summary's ribbons page becomes the worn memento's (drawPageMementos), read as
  # painted, label by value; the rank, drawn as icons up to four, is the one label written with no value.
  module ImprovedMementos
    # Where the page's own block starts (the plugin's xpos and ypos): the header above and the picture to
    # the left are the summary's, read with its other pages.
    LEFT = 290
    TOP = 96

    # The page as spoken, or nil when nothing of it was captured; the key hint is left to the summary.
    def self.page_text(pk, pairs)
      lines = PokeAccess::PaintCapture.lines(pairs) do |r|
        r[2] >= LEFT && r[3] >= TOP && PokeAccess.clean(r[0]) !~ PokeAccess::Summary::HINT
      end
      return nil if lines.empty?
      lines = with_rank(lines, pk)
      PokeAccess.sentences(PokeAccess::PaintCapture.pair_labels(lines))
    rescue StandardError
      nil
    end

    # The grid's focused memento as drawSelectedRibbon draws it: the written lines, the rank (icons, or from five one
    # icon and a number) and whether it is worn; said at the ribbon reading's level, whole on the info key.
    def self.grid_text(pk, pairs, id)
      rank = (pk.getMementoRank(id) rescue 0).to_i
      whole = grid_parts(pk, pairs, id, rank, true)
      return nil if whole.empty?
      PokeAccess::Info.set_info(:text, PokeAccess.sentences(whole))
      PokeAccess.sentences(grid_parts(pk, pairs, id, rank, false))
    rescue StandardError
      nil
    end

    # The grid's parts as the screen writes them; unless whole, less what the verbosity leaves out: the
    # description (the one row the page writes with drawTextEx) and the "n/m" place in the list.
    def self.grid_parts(pk, pairs, id, rank, whole)
      desc = whole || PokeAccess::Verbosity.keep?(:ribbon, :full)
      pos = whole || PokeAccess::Verbosity.keep?(:positions, :medium)
      lines = PokeAccess::PaintCapture.lines(pairs) do |r|
        t = PokeAccess.clean(r[0])
        !(rank > 4 && t == rank.to_s) && (desc || r[1] != :dtex) && (pos || t !~ %r{\A\d+/\d+\z})
      end
      parts = PokeAccess::PaintCapture.pair_labels(lines)
      parts.push(PokeAccess::I18n.t(:mem_rank, :n => rank)) if rank > 0
      parts.push(PokeAccess::I18n.t(:mem_worn)) if id && id == (pk.memento rescue nil)
      parts
    end

    # The lines with the worn memento's rank after its bare label (the one followed straight by another label), or
    # that label dropped when none is worn.
    def self.with_rank(lines, pk)
      rank = worn_rank(pk)
      out = []
      lines.each_with_index do |l, i|
        nxt = lines[i + 1]
        bare = l =~ /:\z/ && (nxt.nil? || nxt =~ /:\z/)
        if !bare
          out.push(l)
        elsif rank > 0
          out.push("#{l} #{rank}")
        end
      end
      out
    end

    # The rank of the memento the Pokemon wears, 0 when it wears none.
    def self.worn_rank(pk)
      m = (pk.memento rescue nil)
      m ? (pk.getMementoRank(m) rescue 0).to_i : 0
    end
  end
end

PokeAccess::Hooks.override(PokeAccess::SummaryGameData, :page_text, :tag => "improved_mementos") do |_m, original, args|
  scene = args[0]
  pk = PokeAccess.ivar(scene, :@pokemon)
  if PokeAccess.ivar(scene, :@page_id) == :page_ribbons && scene.respond_to?(:drawPageMementos) && pk
    PokeAccess::ImprovedMementos.page_text(pk, args[4]) || original.call
  else
    original.call
  end
end

PokeAccess::Hooks.before_hook("PokemonSummary_Scene", :drawSelectedRibbon, :optional => true) do |_scene, args|
  PokeAccess::PaintCapture.arm(:mementos_sel) if args.length >= 4
end

PokeAccess::Hooks.override(PokeAccess::RibbonsV21, :focused_text, :tag => "improved_mementos") do |_m, original, args|
  scene = args[0]
  shape = args[1]
  pk = PokeAccess.ivar(scene, :@pokemon)
  if shape.length >= 4 && scene.respond_to?(:drawPageMementos) && pk
    pairs = PokeAccess::PaintCapture.take_pairs(:mementos_sel)
    PokeAccess::ImprovedMementos.grid_text(pk, pairs, PokeAccess::RibbonsV21.focused_id(shape)) || original.call
  else
    original.call
  end
end
