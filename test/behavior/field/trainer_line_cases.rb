# Shared body of trainer_line_spec (gen-6 pass) and trainer_line_gd_spec (gamedata pass): the trainer line
# is core and both eras build it from the same named parts. What is pinned: the default line is the five
# parts in their order, a profile can replace a part in place (ribbons where badges were), add one (it
# joins the end), reorder and drop through the order alone, a part that raises costs only its fragment, and
# an unknown name in the order is ignored.
module TrainerLineCases
  # Snapshot of the order and the readers the cases touch, restored afterwards: Reset does not reach the
  # structural config, and a leaked part would rewrite the trainer line for every suite after.
  def self.snapshot
    [PokeAccess::Config.trainer_parts.dup, PokeAccess::Info::TRAINER_PARTS.dup]
  end

  def self.restore(saved)
    PokeAccess::Config.trainer_parts = saved[0]
    PokeAccess::Info::TRAINER_PARTS.clear
    PokeAccess::Info::TRAINER_PARTS.merge!(saved[1])
  end

  # The fragments of the current line, split the way trainer_info joins them.
  def self.fragments
    PokeAccess::Info.trainer_info.to_s.split(". ")
  end
end

def define_trainer_line_suites
  Suite.define("trainer line: the default is the five named parts, in order") do
    info = PokeAccess::Info
    tr = info.player_object
    truthy "the harness exposes a player object", tr
    saved = TrainerLineCases.snapshot
    begin
      eq "the default order is name, money, badges, pokedex, playtime", PokeAccess::Config.trainer_parts,
         [:name, :money, :badges, :pokedex, :playtime]
      frags = TrainerLineCases.fragments
      eq "the line opens with the name", frags[0], tr.name.to_s
      money = PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => tr.money)
      eq "the money comes second, through the configured label", frags[1], money
      expected = PokeAccess::Config.trainer_parts.map { |k| info.trainer_part(k, tr) }.compact
      eq "and the whole line is exactly those parts that answered, joined", frags, expected
      truthy "name and money answer on every fixture, the rest depends on what the stub trainer carries", expected.length >= 2
    ensure
      TrainerLineCases.restore(saved)
    end
  end

  Suite.define("trainer line: a profile replaces, adds, reorders and drops parts without rewriting the line") do
    info = PokeAccess::Info
    tr = info.player_object
    saved = TrainerLineCases.snapshot
    begin
      badges = info.trainer_part(:badges, tr)
      info.set_trainer_part(:badges) { |_t| "Cintas: 4" }
      frags = TrainerLineCases.fragments
      eq "a replaced part keeps its place", frags[2], "Cintas: 4"
      falsy "and the old fragment is gone", frags.include?(badges)
      eq "the order itself did not change", PokeAccess::Config.trainer_parts, [:name, :money, :badges, :pokedex, :playtime]

      info.set_trainer_part(:coins) { |_t| "Monedas: 37" }
      eq "a new part joins the end of the order", PokeAccess::Config.trainer_parts.last, :coins
      eq "and of the line", TrainerLineCases.fragments.last, "Monedas: 37"

      PokeAccess::Config.trainer_parts = [:name, :coins, :playtime]
      frags = TrainerLineCases.fragments
      eq "the order alone reorders and drops: money and badges are not spoken", frags[0, 2], [tr.name.to_s, "Monedas: 37"]
      falsy "no money fragment remains", frags.any? { |f| f == PokeAccess::I18n.t(PokeAccess::Config.money_label, :n => tr.money) }

      info.set_trainer_part(:boom) { |_t| raise "reader down" }
      PokeAccess::Config.trainer_parts = [:name, :boom, :coins, :ghost]
      eq "a part that raises costs only its fragment, and an unknown name is ignored",
         TrainerLineCases.fragments, [tr.name.to_s, "Monedas: 37"]

      info.set_trainer_part(:mute) { |_t| "" }
      PokeAccess::Config.trainer_parts = [:mute]
      eq "a line with nothing to say is nil, not an empty string", info.trainer_info, nil
    ensure
      TrainerLineCases.restore(saved)
    end
  end
end
