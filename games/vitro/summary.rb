# Vitro's summary (0161_PScreen_Summary, 0234_Contest_Summary) is BES's with its pages rearranged: the data sheet paints the
# friendship bar and joins the Pokedex number to the species, the memo page keeps only how it was met and paints the field
# moves the Pokemon can use as icons, the moves page paints the Dynamax meter, and a fifth page, before the ribbons, paints
# the contest stats over the moves with their contest type, its cursor opening each move's appeal and jam as hearts.
module PokeAccess
  module VitroSummary
    # The icons the memo page paints, in its order: the move an icon stands for, by the game's name for it, and the moves
    # that light it; with no name of its own, said by the moves themselves.
    FIELD_ICONS = [[:SURF, [:WATERFALL]], [:EMBER, [:EMBER]], [:CUT, [:SLASH]], [:ROCKSMASH, [:ROCKSMASH]],
                   [:STRENGTH, [:STRENGTH, :SUPERPOWER]], [:HEADBUTT, [:SKULLBASH, :IRONHEAD, :ZENHEADBUTT]],
                   [:FLASH, [:FLASH]], [nil, [:SWEETSCENT, :DEFOG]],
                   [nil, [:SOFTBOILED, :MILKDRINK, :HEALPULSE, :LIFEDEW]]]
    # The weather moves that light the last icon, each only on a Pokemon of these types.
    WEATHER = [[:SUNNYDAY, [:FIRE, :GRASS]], [:RAINDANCE, [:WATER]], [:SANDSTORM, [:GROUND, :ROCK, :STEEL]],
               [:SNOWSCAPE, [:ICE]]]
    # The place of each contest type among the five names the radar paints.
    CONTEST_ROW = { "Cute" => 0, "Tough" => 1, "Beauty" => 2, "Cool" => 3, "Smart" => 4 }

    # A move's name as the game spells it.
    def self.move_name(move)
      PBMoves.getName(getConst(PBMoves, move))
    end

    # Whether a Pokemon can learn a move, as the page asks it.
    def self.able?(pk, move)
      pk.isCompatibleWithMove?(getConst(PBMoves, move)) ? true : false
    end

    # The field moves the memo page's icons show for a Pokemon, in their order.
    def self.field_moves(pk)
      names = []
      FIELD_ICONS.each do |word, moves|
        able = moves.select { |m| able?(pk, m) }
        next if able.empty?
        names.concat(word ? [move_name(word)] : able.map { |m| move_name(m) })
      end
      WEATHER.each do |move, types|
        names.push(move_name(move)) if able?(pk, move) && types.any? { |t| pk.hasType?(t) }
      end
      names
    end

    # The memo page: the memo as painted, a line each, then the field moves under the label the page paints.
    # param painted the paragraphs the page painted, each with its lines broken by <br>
    def self.memo_page(pk, painted)
      memo = PokeAccess::Summary.painted_memo(Array(painted).map { |t| t.to_s.gsub(/<br>/i, "\n") })
      names = field_moves(pk)
      PokeAccess.sentences([memo, names.empty? ? nil : "#{_INTL('Movimientos de Campo:')} #{names.join(', ')}"])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The Pokedex number page one paints joined to the species ("025 Pikachu"), or nil where it paints the species alone.
    def self.dex_number(pairs)
      row = (pairs || []).map { |r| PokeAccess.clean(r[0]) }.find { |t| t =~ /\A\d{3,4} \S/ }
      row ? row[/\A\d+/] : nil
    end

    # The Dynamax level the moves page's meter shows, which it draws only for a Pokemon that can Dynamax and a player who
    # holds the Dynamax Band.
    def self.dynamax(pk)
      return nil unless pk.respond_to?(:dynamax) && (pbHasDBand rescue false)
      PokeAccess::I18n.t(:dmax_level, :n => (pk.dynamax_lvl rescue 0).to_i)
    end

    # The contest type the game keeps for a move, by the name the radar paints for it.
    def self.contest_type(scene, data)
      names = PokeAccess.ivar(scene, :@access_contest_names)
      names.is_a?(Array) ? names[CONTEST_ROW[data.contestType] || 3] : nil
    end

    # One row of the contest page: the move, its contest type and its PP.
    def self.contest_row(scene, move)
      parts = [[PBMoves.getName(move.id), :brief]]
      type = contest_type(scene, PBContestMoveData.new(move.id))
      parts.push([type, :medium]) if type
      parts.push([PokeAccess::I18n.t(:mv_pp, :pp => move.pp, :tot => move.totalpp), :brief]) if move.totalpp > 0
      PokeAccess::Verbosity.line(:summary_move, parts, ". ")
    end

    # The contest page as painted: the radar's five names, their five values and the sheen, then the moves. The radar paints
    # its names and values apart, in that order, and keeps the names for the types the rows draw as pictures.
    # param pairs what the page painted, as PaintCapture.take_pairs gives it
    def self.contest_page(scene, pk, pairs)
      rows = pairs.map { |r| PokeAccess.clean(r[0]) }
      return nil if rows.length < 11
      scene.instance_variable_set(:@access_contest_names, rows[0, 5])
      stats = (0...5).map { |i| "#{rows[i]} #{rows[i + 5]}" }.join(", ")
      moves = pk.moves.select { |m| m.id > 0 }.map { |m| contest_row(scene, m) }
      PokeAccess.sentences([_INTL("Concursos"), stats, rows[10],
                            moves.empty? ? nil : PokeAccess::I18n.t(:sm_moves, :list => moves.join(", "))])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A move under the contest cursor as painted: its name, contest type, the hearts of its appeal and jam, and its effect;
    # kept for the info key, the cursor being a detail of the page.
    def self.contest_move(scene, moveid)
      data = PBContestMoveData.new(moveid)
      text = PokeAccess.sentences([PBMoves.getName(moveid), "#{_INTL('TIPO')} #{contest_type(scene, data)}",
                                   "#{_INTL('EXHIBICIÓN')} #{(data.hearts || 0).to_i}",
                                   "#{_INTL('INHIBICIÓN')} #{(data.jam || 0).to_i}",
                                   PokeAccess.clean(_INTL(pbGetContestMoveDescription(moveid)))])
      PokeAccess::Info.set_info(:text, text)
      PokeAccess.speak(text, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  override("PokeAccess::BesSummary", :info_extras) do |mod, original, args|
    original.call + [mod.friendship(args[0])].compact
  end
  override("PokeAccess::BesSummary", :memo_page) do |_mod, _original, args|
    PokeAccess::VitroSummary.memo_page(args[0], args[1])
  end
  override("PokeAccess::Summary", :painted_dex_number) do |_mod, original, args|
    original.call || PokeAccess::VitroSummary.dex_number(args[0])
  end
  override("PokeAccess::Summary", :moves_text) do |_mod, original, args|
    PokeAccess.sentences([original.call, PokeAccess::VitroSummary.dynamax(args[0])])
  end
  # The stats page's "Presiona C" goes through this game's own text call, out of any capture.
  kernel("drawFormattedTextEx2", :before) do |args, _r|
    PokeAccess::PaintCapture.note(args[5], :dtex, args[1], args[2])
  end
  before("PokemonSummaryScene", :drawPageContestMoves, :optional => true) do |_scene, _a|
    PokeAccess::PaintCapture.arm(:vitro_contest)
  end
  after("PokemonSummaryScene", :drawPageContestMoves, :optional => true) do |scene, _r, _a|
    pk = PokeAccess.ivar(scene, :@pokemon)
    pairs = PokeAccess::PaintCapture.take_pairs(:vitro_contest)
    PokeAccess::Summary.speak_page(scene, pk, :contest, PokeAccess::VitroSummary.contest_page(scene, pk, pairs))
  end
  before("PokemonSummaryScene", :pbContestMoveSelection, :optional => true) do |scene, _a|
    PokeAccess::Summary.forget_page(scene)
  end
  after("PokemonSummaryScene", :drawSelectedContestMove, :optional => true) do |scene, _r, args|
    PokeAccess::VitroSummary.contest_move(scene, args[0])
  end
end
