# Pokemon Z's and Opalo's IV stars on the stats page, empty, low, high or perfect by the page's thresholds, said as
# words in the page's order, speed last. The gen-6 pass runs the Pokemon Z profile, which loads the reader.
Suite.define("pokemon z: the stats page says the star each stat's individual value earns") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Chispa", :iv => [31, 17, 16, 7, 6, 26])
  want = t.t(:iv_stars, :list => [[:st_hp, :iv_star_perfect], [:st_atk, :iv_star_high], [:st_def, :iv_star_low],
                                   [:st_spatk, :iv_star_empty], [:st_spdef, :iv_star_perfect],
                                   [:st_speed, :iv_star_low]].map { |s, k| "#{t.t(s)} #{t.t(k)}" }.join(", "))
  truthy "each stat with its star, after the stats and before the nature",
         PokeAccess::SummaryGen6.stats_text(pk).to_s.include?(want)
  eq "the thresholds are the page's: 6 is empty, 7 low, 16 low, 17 high, 25 high, 26 perfect",
     [6, 7, 16, 17, 25, 26].map { |v| PokeAccess::IVStars.star(v) },
     [:iv_star_empty, :iv_star_low, :iv_star_low, :iv_star_high, :iv_star_high, :iv_star_perfect]
end
