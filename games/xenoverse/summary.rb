# The summary (0223_NewSummary) draws Stats, Moves and Memo on other pages than Essentials' and writes its paragraphs
# with drawTextExH: the shared summary reader speaks each page from what these pages paint, with its cursor, Pokemon and
# move details.
PokeAccess::Game.define("xenoverse") do
  before("PokemonSummaryScene", :drawPageTwo) do |_scene, _args|
    PokeAccess::PaintCapture.arm(:xenoverse_summary_stats)
  end
  before("PokemonSummaryScene", :drawPageFour) do |_scene, _args|
    PokeAccess::PaintCapture.arm(:xenoverse_summary_memo)
  end

  override("PokeAccess::Summary", :speak_page) do |_receiver, original, args|
    scene, pokemon, page = args
    if scene.is_a?(PokemonSummaryScene)
      case page
      when 2
        painted = PokeAccess::PaintCapture.take(:xenoverse_summary_stats)
        extras = PokeAccess::Summary.eviv_rows(pokemon) if pokemon
        text = PokeAccess::SummaryGen6.stats_text(pokemon, painted, extras)
        args[3] = PokeAccess::Summary.with_hints(text, painted)
      when 3
        args[3] = PokeAccess::Summary.moves_text(pokemon)
      when 4
        painted = PokeAccess::PaintCapture.laid_out(PokeAccess::PaintCapture.take_pairs(:xenoverse_summary_memo))
        args[3] = PokeAccess::Summary.painted_memo(painted) || PokeAccess::SummaryGen6.memo_text(pokemon)
      end
    end
    original.call
  end

  kernel("drawTextExH", :before) do |args, _result|
    if PokeAccess::PaintCapture.armed?(:xenoverse_summary_stats) || PokeAccess::PaintCapture.armed?(:xenoverse_summary_memo)
      PokeAccess::PaintCapture.note(args[5], :dtex, args[1], args[2])
    end
  end
end
