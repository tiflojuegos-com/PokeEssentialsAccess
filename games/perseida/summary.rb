# Perseida's summary (0146_PScreen_Summary, rewritten by 0260_Signos_Summary) orders its pages its own way: drawPageTwo is
# the stats, with a column of EVs and a letter for each IV, and drawPageThree the moves; drawPageFour only runs on leaving
# the move cursor, painted over at once by drawPageThree. Each page is said as what it shows, and the ribbon cursor, which
# paints the ribbon's name and description under the grid (pbdrawRibDesc), as it moves. The sign has its own page
# (drawInfoZodiac) and, with the powers on, the action key opens the star power's over it (drawInfoPageZodiac, a modal loop);
# the data sheet paints its name too.
module PokeAccess
  module PerseidaSummary
    # The letters of Graphics/Pictures/Summary/letters, in the order of its icons.
    LETTERS = %w[F D C B A S]

    # The letter pbDisplayIVRatings draws for an IV.
    def self.letter(iv)
      icon = case iv
             when 31 then 5
             when 30 then 4
             when 0 then 0
             else iv > 24 ? 3 : (iv > 16 ? 2 : 1)
             end
      LETTERS[icon]
    end

    # Each stat's IV letter. The page draws them in the order the game keeps the IVs, beside rows in another order; said
    # by the stat each one rates.
    def self.ivs(pk)
      list = PokeAccess::Summary::STAT_ROWS.map { |i, key| "#{PokeAccess::I18n.t(key)} #{letter(pk.iv[i].to_i)}" }
      PokeAccess::I18n.t(:perseida_ivs, :list => list.join(", "))
    end

    # The stats page: the page paints the ability's name, not its description, and the action key opens the description.
    def self.stats(pk)
      name = PokeAccess::Data.ability_name(pk.ability)
      hint = PokeAccess::I18n.t(:perseida_info_hint, :key => PokeAccess::KeyHints.key(:c, "C"))
      PokeAccess::Verbosity.with_hint(PokeAccess::SummaryGen6.stats_text(pk, [name]), hint, " ")
    end

    # The column the sign's page writes in; left of it, the item, the name and the level stay in sight on every page.
    SIGN_COLUMN = 238

    # The mark both pages draw over the sign's token on a Pokemon that can Mega Evolve; a Shadow Pokemon's has no token.
    def self.mega_mark(pk)
      pk.hasMegaForm? && !(pk.isShadow? rescue false) ? PokeAccess::I18n.t(:perseida_mega_able) : nil
    end

    # The sign's line on the data sheet, where a Shadow Pokemon's has its gauge; nil where the sheet paints none.
    def self.sheet_sign(pk)
      sign = (pk.pbGetBirthsignName rescue nil)
      return nil if sign.nil? || (pk.isShadow? rescue false) || PokeAccess::Summary.egg?(pk)
      [_INTL('Signo de {1}', pk.name) + ": " + sign, mega_mark(pk)].compact.join(", ")
    end

    # The sign's page as painted, top to bottom, with its mark and the key hint it writes, while key hints are said.
    # param pairs what the page painted, as PaintCapture.take_pairs gives it
    def self.sign_page(pk, pairs)
      rows = pairs.select { |r| r[2].to_i >= SIGN_COLUMN }
      texts = PokeAccess::PaintCapture.laid_out(rows).map { |t| PokeAccess.clean(t) }
      hint = texts.find { |t| t == _INTL("Pulsa C o Espacio para ver mas información.") }
      page = PokeAccess.sentences((texts - [hint]) + [mega_mark(pk)])
      hint ? PokeAccess::Verbosity.with_hint(page, PokeAccess::KeyHints.localize(hint, nil, true)) : page
    end

    # The star power's page as it opens, cutting in and kept for the info key; the sign's page it returns to is said again.
    def self.power_page(scene, pk)
      PokeAccess::Summary.forget_page(scene)
      mega = pk.hasMegaForm? ? _INTL("Este Pokémon puede cambiar de forma tras utilizar su Poder Estelar.") : nil
      text = PokeAccess.sentences([_INTL("Poder: {1}", pk.pbGetPowerName2), PokeAccess.clean(pk.pbGetPowerDesc2), mega])
      PokeAccess::Info.set_info(:text, text)
      PokeAccess.speak(text, true, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    @power_up = false

    # Runs the star power's modal page: its loop runs the scene's pbUpdate, which would point the info key back at the
    # Pokemon each frame.
    def self.on_power_page(scene, pk)
      power_page(scene, pk)
      @power_up = true
      yield
    ensure
      @power_up = false
    end

    # Whether the info key stays on a detail the screen has up: the star power's page or the ribbon under its cursor.
    def self.detail_up?(scene)
      @power_up || (PokeAccess.sprite(scene, "ribsel").visible rescue false) ? true : false
    end

    # The ribbon under the cursor, cutting in after the first, and kept for the info key; past the last ribbon the game
    # paints nothing.
    def self.ribbon(scene, pk)
      idx = PokeAccess.ivar(scene, :@ribindex)
      ribbons = (pk.ribbons rescue nil)
      return unless idx.is_a?(Integer) && ribbons.is_a?(Array) && ribbons[idx]
      name, desc = PokeAccess::Summary.ribbon_parts(ribbons[idx])
      return if name.nil?
      head = PokeAccess::Verbosity.list_entry(name, idx + 1, ribbons.length)
      whole = PokeAccess.sentences([head, desc])
      PokeAccess::Info.set_info(:text, whole)
      PokeAccess::Cursor.announce(scene, :perseida_ribbon, idx, true, false) do
        PokeAccess::Verbosity.keep?(:ribbon, :full) ? whole : head
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("perseida") do
  override("PokeAccess::Summary", :speak_page) do |_mod, original, args|
    scene, pk, page = args
    case page
    when 2 then PokeAccess::Summary.speak_page(scene, pk, :stats, PokeAccess::PerseidaSummary.stats(pk))
    when 3 then PokeAccess::Summary.speak_page(scene, pk, :moves, PokeAccess::Summary.moves_text(pk))
    when 4 then nil
    else original.call
    end
  end
  # The header draws a mark on a magnific Pokemon where it draws a shiny one's star.
  override("PokeAccess::Summary", :header_icons) do |_mod, original, args|
    magnific = (args[0].isMagnific? rescue false) ? PokeAccess::I18n.t(:perseida_magnific) : nil
    [original.call, magnific].reject { |part| part.to_s.empty? }.join(", ")
  end
  override("PokeAccess::SummaryGen6", :stats_extras) do |_mod, original, args|
    original.call + [PokeAccess::PerseidaSummary.ivs(args[0])]
  end
  override("PokeAccess::Info", :summary_text) do |_mod, original, args|
    text = original.call
    sign = text && PokeAccess::PerseidaSummary.sheet_sign(args[0])
    sign ? PokeAccess.sentences([text, sign]) : text
  end
  before("PokemonSummaryScene", :drawInfoZodiac, :optional => true) do |_scene, _a|
    PokeAccess::PaintCapture.arm(:perseida_sign)
  end
  after("PokemonSummaryScene", :drawInfoZodiac, :optional => true) do |scene, _r, args|
    pairs = PokeAccess::PaintCapture.take_pairs(:perseida_sign)
    PokeAccess::Summary.speak_page(scene, args[0], :sign, PokeAccess::PerseidaSummary.sign_page(args[0], pairs))
  end
  around("PokemonSummaryScene", :drawInfoPageZodiac, :optional => true) do |scene, nxt, args|
    PokeAccess::PerseidaSummary.on_power_page(scene, args[0]) { nxt.call }
  end
  override("PokeAccess::SummaryGen6", :detail_focused?) do |_mod, original, args|
    original.call || PokeAccess::PerseidaSummary.detail_up?(args[0])
  end
  before("PokemonSummaryScene", :pbRibbonSelection, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :perseida_ribbon)
  end
  after("PokemonSummaryScene", :pbdrawRibDesc, :optional => true) do |scene, _r, args|
    PokeAccess::PerseidaSummary.ribbon(scene, args[0])
  end
end
