# Perseida's raids, the veins of mana (0274_NewBattle_Raid_Screen, 0275_NewBattle_Raid_Rewards): each screen paints all its
# text once, in initialize, and runs its own loop in show. The entry shows the title, three options, the stars and the
# sign's token beside the Pokemon's black shape, so its species goes unsaid; the rewards show the title, a lone Exit, the
# prizes and the Pokemon itself.
module PokeAccess
  module PerseidaRaid
    TAG = :perseida_raid

    # Runs a screen's initialize (the block), keeping on it the strings it paints, in the order it paints them.
    def self.painted(scene)
      PokeAccess::PaintCapture.arm(TAG)
      yield
    ensure
      rows = PokeAccess::PaintCapture.take(TAG, :positions) || []
      scene.instance_variable_set(:@access_rows, rows.map { |row| PokeAccess.clean(row.to_s) })
    end

    # What both screens draw of the raid: its stars and the name of the sign whose token they show.
    def self.details(scene)
      rank = PokeAccess.ivar(scene, :@rank)
      sign = (PokeAccess.ivar(scene, :@pokemon).pbGetBirthsignName rescue nil)
      [rank ? PokeAccess::I18n.t(:perseida_raid_rank, :n => rank) : nil,
       sign.to_s.empty? ? nil : PokeAccess::I18n.t(:perseida_sign, :name => sign)]
    end

    # The entry's [key, line] for its focused option: rows are the title and then the options.
    def self.entry(scene)
      selected = PokeAccess.ivar(scene, :@selected)
      [selected, lambda { entry_line(scene, PokeAccess.ivar(scene, :@access_rows), selected) }]
    end

    # The focused option with its place, led the first time by what the screen shows.
    def self.entry_line(scene, rows, selected)
      option = PokeAccess::Verbosity.list_entry(rows[selected + 1], selected + 1, rows.length - 1)
      return option if PokeAccess.ivar(scene, :@access_heard)
      scene.instance_variable_set(:@access_heard, true)
      PokeAccess.sentences([rows[0]] + details(scene) + [option])
    end

    # The rewards as they open: rows are the title, the exit and then the prizes, up to the six it paints.
    def self.rewards(scene)
      rows = PokeAccess.ivar(scene, :@access_rows)
      name = PokeAccess.clean((PokeAccess.ivar(scene, :@pokemon).name rescue "").to_s)
      prizes = (rows[2, rows.length] || []).join(", ")
      line = PokeAccess.sentences([rows[0], name] + details(scene) + [prizes, rows[1]])
      PokeAccess::Info.set_info(:text, line)
      PokeAccess.speak(line, false)
    end

    WATCH = PokeAccess::SceneWatcher.reader("RaidBattles", :show, TAG) { |scene| PokeAccess::PerseidaRaid.entry(scene) }
  end
end

["RaidBattles", "RaidRewards"].each do |cname|
  PokeAccess::Hooks.around_hook(cname, :initialize) do |scene, call_next, _args|
    PokeAccess::PerseidaRaid.painted(scene) { call_next.call }
  end
end

PokeAccess::Hooks.before_hook("RaidRewards", :show) { |scene, _a| PokeAccess::PerseidaRaid.rewards(scene) }

# The entry's second option opens the PC over it; back from there, its cursor is said again.
PokeAccess::Hooks.wrap_kernel("pbPokeCenterPC", "perseida_raid_pc", :after) do |_args, _r|
  PokeAccess::Cursor.reset(PokeAccess::PerseidaRaid::WATCH, PokeAccess::PerseidaRaid::TAG)
end
