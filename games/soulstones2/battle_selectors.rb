# The two battle carousels of Soulstones 2's edited Pokeball UI, an older release than the one
# plugins/dbk_enhanced_ui.rb reads: the ball picker and the "Quick" party switch, sprite rows with no window,
# plus the question their confirmations write (pbShowCommandsUpper).
module PokeAccess
  module SS2Selectors
    # The focused ball, "name, count", with the description when the details toggle shows it; the empty
    # entries at both ends of the row are the way back.
    def self.ball_text(items, index, show_desc)
      e = (items[index] rescue nil)
      item = e ? (GameData::Item.try_get(e[0]) rescue nil) : nil
      return PokeAccess::I18n.t(:dbk_back) unless item
      line = PokeAccess::I18n.t(:dbk_ball, :name => item.name, :n => e[1])
      return line unless show_desc
      d = PokeAccess.clean((item.description rescue "").to_s)
      d.empty? ? line : "#{line}. #{d}"
    rescue StandardError
      nil
    end

    # The marks the extra panel draws around a move, one per foe, and what each says.
    MATCHUP_MARKS = { "[x]" => :mv_eff_none, "[--]" => :mv_eff_barely, "[-]" => :mv_eff_weak,
                      "[o]" => :mv_eff_neutral, "[+]" => :mv_eff_super, "[++]" => :mv_eff_hyper }
    MATCHUP_ROW = /\A\s*(\[[^\]]*\])\s+(.*?)(?:\s+(\[[^\]]*\]))?\s*\z/

    # The focused member as the row paints it: its "name [level]" caption (the name alone below medium), its bars,
    # the moves' matchups with the extra panel open, and the key hints on opening and on each toggle.
    # param rows the paint of this redraw, by source
    def self.member_text(scene, party, index, show, rows)
      pos = rows[:positions] || []
      return nil if pos.empty?
      pk = (party[index] rescue nil)
      brief = pk && !PokeAccess::Verbosity.keep?(:party, :medium)
      parts = [brief ? PokeAccess.clean(pk.name.to_s) : PokeAccess.clean(pos[2].to_s)]
      if pk
        PokeAccess::Info.set_info(:pokemon, pk)
        parts.concat(bar_parts(pk))
        parts.concat(matchups(scene, rows[:dtex] || [])) if show
      end
      parts.concat(pos[0, 2].map { |h| PokeAccess.clean(h.to_s) }) if PokeAccess::Verbosity.hints? && PokeAccess::Cursor.changed?(scene, :ss2_switch_hint, show)
      parts.reject { |p| p.to_s.empty? }.join(", ")
    rescue StandardError
      nil
    end

    # What the icon's bars show: the hit points or fainted, and the status, or else Pokerus in the party reading's
    # full level.
    def self.bar_parts(pk)
      return [PokeAccess::I18n.t(:pk_fainted)] if (pk.hp rescue 1).to_i <= 0
      parts = [PokeAccess::Battle.hp_phrase(pk.hp, pk.totalhp, true)]
      st = (pk.status rescue nil)
      if !(st.nil? || st == 0 || st == :NONE)
        parts.push(PokeAccess::Data.status_name(st))
      elsif PokeAccess::Party.pokerus?(pk) && PokeAccess::Verbosity.keep?(:party, :full)
        parts.push(PokeAccess::I18n.t(:pk_pokerus))
      end
      parts.compact
    end

    # The extra panel's rows, "[+] Move [o]": the move with the verdict for each foe, left mark first, the
    # foes in the order the panel takes them. With a single foe the verdict stands alone.
    def self.matchups(scene, rows)
      foes = ((PokeAccess.ivar(scene, :@battle).allBattlers rescue []) || []).select { |b| b && (b.index rescue 0).odd? }
      rows.map do |r|
        md = MATCHUP_ROW.match(r.to_s)
        next nil unless md
        move = md[2]
        words = [md[1], md[3]].compact.map { |m| PokeAccess::I18n.t(MATCHUP_MARKS[m] || :mv_eff_unknown) }
        verdict = if words.length > 1
                    words.each_with_index.map do |w, i|
                      nm = PokeAccess.clean((foes[i].name rescue "").to_s)
                      nm.empty? ? w : PokeAccess::I18n.t(:mv_eff_vs, :name => nm, :eff => w)
                    end.join(", ")
                  else
                    words.first
                  end
        "#{move}: #{verdict}"
      end.compact
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  # Each opening of the ball picker forgets its dedup, so the first entry is read again, queued.
  before("Battle::Scene", :pbSelectBallInfo, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :ss2_ball)
  end

  # The details toggle repaints without moving the cursor, so the key carries it.
  after("Battle::Scene", :pbUpdateBallSelection, :optional => true) do |scene, _r, args|
    PokeAccess::Cursor.announce(scene, :ss2_ball, [args[1], args[2]], true, false) do
      PokeAccess::SS2Selectors.ball_text(args[0], args[1], args[2])
    end
  end

  before("Battle::Scene", :pbSelectPartyInfo, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :ss2_switch)
    PokeAccess::Cursor.reset(scene, :ss2_switch_hint)
  end

  # Forgets the member as its summary opens, so it is said again on return; before, since pbPartySummary runs the
  # whole summary, whose readers an after hook would mute.
  before("Battle::Scene", :pbPartySummary, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :ss2_switch)
  end

  # Around, with the capture armed: the caption, the key hints and the extra panel are only in the paint.
  # The panel toggle repaints without moving the cursor, so the key carries it.
  around("Battle::Scene", :pbUpdatePartySelection, :optional => true) do |scene, nxt, args|
    PokeAccess::PaintCapture.arm(:ss2_switch)
    begin
      nxt.call
    ensure
      rows = PokeAccess::PaintCapture.take_by_source(:ss2_switch) || {}
      PokeAccess::Cursor.announce(scene, :ss2_switch, [args[1], args[2] ? true : false], true, false) do
        PokeAccess::SS2Selectors.member_text(scene, args[0], args[1], args[2] ? true : false, rows)
      end
    end
  end

  # Before, because the original is the modal Yes/No loop.
  before("Battle::Scene", :pbShowCommandsUpper, :optional => true) do |_s, args|
    PokeAccess.say_dialogue(args[0])
  end
end
