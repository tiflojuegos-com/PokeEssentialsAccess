# The Grandeur Club card (GCCard_Scene): each of its four pages as painted (labels, trainer id, credits), plus
# a tier line per challenge from the game variables its icon strips are indexed by.
module PokeAccess
  module FireAshGC
    # One challenge's tier line: with thresholds, how many the value passed; with a top, the value capped there;
    # with neither, the plain count. A slot the card leaves blank (zero, or under the first threshold) has no emblem.
    def self.tier_text(name, value, top)
      return PokeAccess::I18n.t(:gc_empty, :name => name) if value <= 0
      if top.is_a?(Array)
        n = 0
        top.each { |t| n += 1 if value >= t }
        return PokeAccess::I18n.t(:gc_empty, :name => name) if n <= 0
        return PokeAccess::I18n.t(:gc_tier, :name => name, :n => n, :max => top.length)
      end
      return PokeAccess::I18n.t(:gc_count, :name => name, :n => value) unless top
      PokeAccess::I18n.t(:gc_tier, :name => name, :n => (value > top ? top : value), :max => top)
    end
  end
end

PokeAccess::Game.define("fireash") do
  # page drawing method => [page, [[name as painted, game variable, top tier or tier thresholds]]]; the tops were
  # measured on the icon strips (the script does not clamp them).
  gc_pages = {
    :pbDrawGCCardOne   => [1, [["Practice", 91, 3], ["Club", 92, 4]]],
    :pbDrawGCCardTwo   => [2, [["Gauntlet", 93, [10, 25, 50]], ["Duet", 97, 4], ["Mayhem", 94, 3],
                               ["Sync", 95, 4], ["Titan", 96, 4]]],
    :pbDrawGCCardThree => [3, [["Kanto", 90, 2], ["Johto", 89, 2], ["Hoenn", 88, 2],
                               ["Sinnoh", 87, 2], ["Unova", 86, 2]]],
    :pbDrawGCCardFour  => [4, [["Kalos", 85, 2], ["Alola", 84, 2], ["Galar", 48, 2],
                               ["Frontier", 83, 2], ["Hisui", 47, 2]]]
  }

  gc_pages.each do |meth, spec|
    page, entries = spec
    around("GCCard_Scene", meth, :optional => true) do |_s, nxt, _a|
      PokeAccess::PaintCapture.arm(:gc_card)
      begin
        nxt.call
      ensure
        parts = []
        parts.push(PokeAccess::I18n.t(:gc_page, :n => page, :total => gc_pages.length)) if PokeAccess::Verbosity.keep?(:positions, :medium)
        names = entries.map { |name, _v, _t| name }
        rows = (PokeAccess::PaintCapture.take(:gc_card) || []).reject { |r| names.include?(r.to_s.strip) }
        painted = PokeAccess::PaintCapture.text(rows)
        parts.push(painted) unless painted.to_s.strip.empty?
        entries.each do |name, var, top|
          v = (pbGet(var) rescue ($game_variables ? $game_variables[var] : 0)).to_i
          parts.push(PokeAccess::FireAshGC.tier_text(name, v, top))
        end
        PokeAccess.speak_clean(parts.join(". "), true)
      end
    end
  end
end
