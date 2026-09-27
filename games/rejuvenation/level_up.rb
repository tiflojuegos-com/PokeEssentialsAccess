module PokeAccess
  # Rejuvenation's stat window (pbStatChangeDisplayWindow): each stat's change and new value, painted beside the
  # message of a level up or down, a Rare Candy, a vitamin or an EV reset, in battle and out. The engine has no
  # pbLevelUp; the changes are said right after that message.
  module RejuvStats
    # i18n keys of the stats in getStats order: HP, Attack, Defense, Sp. Atk, Sp. Def, Speed.
    STATS = [:st_hp, :st_atk, :st_def, :st_spatk, :st_spdef, :st_speed]

    # The changes from the old stats to the Pokemon's now, each rise or fall with the new value the window paints
    # after it; nil when none changed.
    def self.changes(pkmn, old)
      now = pkmn.getStats
      parts = []
      STATS.each_with_index do |key, i|
        d = now[i].to_i - old[i].to_i
        next if d == 0
        parts.push(PokeAccess::I18n.t(d > 0 ? :rj_stat_up : :rj_stat_down, :stat => PokeAccess::I18n.t(key), :n => d.abs,
                                      :v => now[i].to_i))
      end
      parts.empty? ? nil : parts.join(", ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  kernel("pbStatChangeDisplayWindow", :before) do |args, _r|
    t = PokeAccess::RejuvStats.changes(args[0], args[1])
    PokeAccess.after_next_line(t) if t
  end
end
