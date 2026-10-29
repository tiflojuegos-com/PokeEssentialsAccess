module PokeAccess
  # Rejuvenation's quick summary (PokemonScreen_Scene#showQuickSummary, Z on a party member): a panel beside the party,
  # one drawFormattedTextEx row each (types, item, ability, the four moves after their mini type icons with their PP,
  # nature, EVs) and the EXP, or a shadow Pokemon's heart gauge, as a bar under the last label. Redrawn for each member
  # the cursor moves to while it is open, and kept on the info key until disposeQuickSummary closes it; the game's own
  # reader of it is muted.
  module RejuvQuickSummary
    # A move row's mini type icon (<icon=minitypeFIRE>), and the PP painted after the move ("15/15").
    MOVE_ICON = /<icon=minitype(\w+)>/
    PP = /(\d+)\/(\d+)\s*\z/

    # A move row as the summary's moves are said: its name, the type its icon shows (question marks as unknown) and
    # the PP painted.
    def self.move_row(text)
      type = PokeAccess::DexEntry.unknown_marks(PokeAccess::RejuvInspect.type_word(text[MOVE_ICON, 1]))
      rest = PokeAccess.clean(text.sub(MOVE_ICON, ""))
      pp = rest =~ PP ? [$1.to_i, $2.to_i] : [nil, nil]
      PokeAccess::SummaryRV.slot_line([rest.sub(PP, "").strip, type, pp[0], pp[1]])
    end

    # One painted row as said, its type icons worded and question marks as unknown; nil for an empty move slot.
    def self.row(text)
      t = text.to_s
      return move_row(t) if t =~ MOVE_ICON
      said = PokeAccess::DexEntry.unknown_marks(PokeAccess::RejuvInspect.worded(t))
      (said.empty? || PokeAccess::Menus.placeholder?(said)) ? nil : said
    end

    # The gauge drawn under the last label, in the words the game's own reader gives it; nil when it cannot tell.
    def self.gauge(pk)
      (pk.isShadow? rescue false) ? pk.getHeartGaugeBarTextTTS : pk.getEXPBarText(:tts => true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The panel as said: its rows in the order painted, the gauge's words after the last label.
    # param pairs the rows the panel painted, as PaintCapture.sample gives them
    def self.text(pairs, pk)
      rows = pairs.map { |r| row(r[0]) }.compact
      g = gauge(pk)
      rows[-1] = "#{rows[-1]} #{g}" if g && !rows.empty?
      PokeAccess.sentences(rows)
    end

    # The member under the cursor, whose panel is open.
    def self.member(scene)
      (PokeAccess.sprite(scene, "pokemon#{PokeAccess.ivar(scene, :@activecmd)}").pokemon rescue nil)
    end

    # Says the panel just painted, cutting in as Z opens it and queued behind the member's line when a cursor move
    # redraws it; the info key keeps it whole, Ctrl+T the member's row.
    def self.say(scene, pairs, opening)
      pk = member(scene)
      return if pk.nil? || pairs.empty?
      PokeAccess::Info.set_info(:text, PokeAccess::Verbosity.whole { text(pairs, pk) }, PokeAccess::Info.row_text)
      PokeAccess.speak(text(pairs, pk), opening, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # As the open panel is disposed (B, C or Z closing it, a key leaving the party, a redraw), the info key goes back
    # to the member under the cursor as the party published it, its row kept for Ctrl+T.
    def self.close(scene)
      return unless (scene.showingQuickSummary? rescue false)
      pk = member(scene)
      pk ? PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Info.row_text) : PokeAccess::Info.clear_text
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  around("PokemonScreen_Scene", :showQuickSummary, :optional => true) do |scene, nxt, _a|
    opening = !(scene.showingQuickSummary? rescue false)
    r = nil
    pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::RejuvQuickSummary.say(scene, pairs, opening)
    r
  end

  before("PokemonScreen_Scene", :disposeQuickSummary, :optional => true) do |scene, _a|
    PokeAccess::RejuvQuickSummary.close(scene)
  end
end
