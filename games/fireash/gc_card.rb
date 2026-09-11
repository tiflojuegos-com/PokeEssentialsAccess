# The Grandeur Club card (GCCard_Scene, the GCCARD key item): four pages of trainer card with no spoken word,
# rotated by tearing the scene down and building the next. The LABELS, trainer id and credit total go
# through pbDrawTextPositions and are captured as painted; the PROGRESS is one frame of an icon strip per
# challenge, so the tiers are read from the very variables the page indexes its icons with. Those variable
# numbers are this game's, read off 291_UI_GCCard.rb, and nothing else in the mod may assume them. The
# captured rows drop the challenge NAMES, because the tier line says each one again.
module PokeAccess
  module FireAshGC
    # One challenge as the page shows it. A threshold list means the page indexes the icon strip by how many
    # of them the streak has passed -- the streak itself is never painted, so saying "Gauntlet: 37" was a
    # number nobody could see. A plain top means the variable IS the tier, and the top comes from the strip.
    def self.tier_text(name, value, top)
      return PokeAccess::I18n.t(:gc_none, :name => name) if value <= 0
      if top.is_a?(Array)
        n = 0
        top.each { |t| n += 1 if value >= t }
        return PokeAccess::I18n.t(:gc_none, :name => name) if n <= 0
        return PokeAccess::I18n.t(:gc_tier, :name => name, :n => n, :max => top.length)
      end
      return PokeAccess::I18n.t(:gc_count, :name => name, :n => value) unless top
      PokeAccess::I18n.t(:gc_tier, :name => name, :n => (value > top ? top : value), :max => top)
    end
  end
end

PokeAccess::Game.define("fireash") do
  # page drawing method => [name as the page paints it, game variable, how the page turns that variable into
  # a tier]. A number is the highest tier and the variable IS the tier; an Array is the thresholds the page
  # indexes by, so the tier is how many of them the variable has passed.
  #
  # The tops are not in the script -- the page just does frame = value - 1 with no clamp -- so they were
  # measured on the icon strips themselves, which is the only place that number exists: Duet_rings 288/72 =
  # 4, Mayhem_plaques 252/84 = 3, Sygna_medallions 212/53 = 4, Titan_crowns 336/84 = 4. Practice 252/84 = 3
  # and Club_ribbons 144/36 = 4 agree with the clamps the code does have, which is what makes the method
  # trustworthy for the four it does not.
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
        parts = [PokeAccess::I18n.t(:gc_page, :n => page, :total => gc_pages.length)]
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
