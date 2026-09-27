module PokeAccess
  # Uranium's marks on its party and Black/White summary: DEAD for a fainted Pokemon under the Nuzlocke rule, RAD
  # for a corrupted Nuclear one, the memo page's date and place and each stat's IVs and EVs.
  module UraniumSummary
    # True for a fainted Pokemon while the Nuzlocke rule is on, which the party and summary mark DEAD.
    def self.dead?(pk)
      (($PokemonGlobal.nuzlocke rescue false) && (pk.hp rescue 1).to_i <= 0) ? true : false
    end

    # True for a Nuclear Pokemon the summary marks RAD: corrupted and not yet cured.
    def self.corrupted?(pk)
      (pk.isNuclear? && !pk.nuclearFree) ? true : false
    rescue StandardError
      false
    end

    # The summary header's icons as this game draws them: DEAD in place of fainted under the Nuzlocke rule, and the
    # RAD mark last.
    # param icons the header's icons as the core words them, joined with ", "
    def self.icons(pk, icons)
      parts = icons.to_s.empty? ? [] : icons.to_s.split(", ")
      if dead?(pk)
        fainted = PokeAccess::I18n.t(:pk_fainted)
        parts = parts.map { |p| p == fainted ? PokeAccess::I18n.t(:ura_dead) : p }
      end
      parts.push(PokeAccess::I18n.t(:ura_rad)) if corrupted?(pk)
      parts.join(", ")
    end

    # Notes the memo page's date and place for the Pokemon it is about to draw.
    def self.memo_of(pk)
      @memo = memo_lines(pk)
    end

    # The notes memo_of kept, handed over once.
    def self.take_memo
      m = @memo
      @memo = nil
      m
    end

    # The date the page draws (day/month/year) and the place, marked as a dream where the map is one of the game's
    # dream maps (DREAMMAPS, drawn purple).
    def self.memo_lines(pk)
      return nil unless pk
      out = []
      t = (pk.timeReceived rescue nil)
      out.push(PokeAccess::I18n.t(:ura_memo_date, :date => _INTL("{1}/{2}/{3}", t.day, t.mon, t.year))) if t
      text = (pk.obtainText rescue nil)
      place = (text && text != "") ? text : (pbGetMapNameFromId(pk.obtainMap) rescue nil)
      unless place.to_s.strip.empty?
        dream = ((PokeAccess.const_at("DREAMMAPS") || []).include?(pk.obtainMap) rescue false)
        place = "#{place}, #{PokeAccess::I18n.t(:ura_memo_dream)}" if dream
        out.push(PokeAccess::I18n.t(:ura_memo_place, :place => place))
      end
      out.empty? ? nil : out
    end

    # Each stat's IV and EV as the stats page writes them beside it, in the page's order (speed last).
    def self.iv_ev(pk)
      iv = pk.iv
      ev = pk.ev
      PokeAccess::I18n.t(:sm_ivev, :hpi => iv[0], :hpe => ev[0], :ai => iv[1], :ae => ev[1], :di => iv[2], :de => ev[2],
                         :sai => iv[4], :sae => ev[4], :sdi => iv[5], :sde => ev[5], :si => iv[3], :se => ev[3])
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("uranium") do
  override("PokeAccess::Summary", :header_icons) do |_mod, original, args|
    PokeAccess::UraniumSummary.icons(args[0], original.call)
  end
  override("PokeAccess::Party", :status_slot) do |_mod, original, args|
    PokeAccess::UraniumSummary.dead?(args[0]) ? PokeAccess::I18n.t(:ura_dead) : original.call
  end
  before("PokemonSummaryScene", :drawPageTwo) do |scene, args|
    PokeAccess::UraniumSummary.memo_of(PokeAccess::SummaryGen6.subject(scene, args))
  end
  override("PokeAccess::Summary", :painted_memo) do |_mod, original, _args|
    memo = original.call
    extra = PokeAccess::UraniumSummary.take_memo
    (memo && extra) ? PokeAccess.sentences([memo].concat(extra)) : memo
  end
  override("PokeAccess::SummaryGen6", :stats_extras) do |_mod, original, args|
    original.call + [PokeAccess::UraniumSummary.iv_ev(args[0])].compact
  end
end
