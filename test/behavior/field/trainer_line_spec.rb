# The trainer line under the gen-6 stubs; the shared cases live in trainer_line_cases.rb. The Reminiscencia
# suite below is gen-6 only, like the game: its profile swaps the dead money for the coins and heart scales
# the run actually spends, so the whole constants file is evaluated over a fake bag and everything it
# touches (order, readers, name tables) is restored afterwards.
require File.expand_path("trainer_line_cases", File.dirname(__FILE__))
define_trainer_line_suites

Suite.define("trainer line (reminiscencia): coins and heart scales instead of the money the run never spends") do
  info = PokeAccess::Info
  saved = TrainerLineCases.snapshot
  tables = [PokeAccess::Config.status_names.dup, PokeAccess::Config.field_weather_names.dup, PokeAccess::Config.money_label]
  patterns = PokeAccess::Locator::TRANSFER_SCRIPTS.dup
  old_bag = $PokemonBag
  begin
    bag = Object.new
    bag.define_singleton_method(:pbQuantity) { |item| { :COIN => 37, :HEARTSCALE => 4 }[item] || 0 }
    $PokemonBag = bag
    path = File.join(Harness::ROOT, "games", "reminiscencia", "constants.rb")
    # eval is the harness's own loading mechanism (test/support/harness.rb): this repo's file, by absolute path.
    eval(File.read(path), TOPLEVEL_BINDING, path)
    tr = info.player_object
    frags = TrainerLineCases.fragments
    eq "name, then coins, then heart scales", frags[0, 3], [tr.name.to_s, PokeAccess::I18n.t(:rem_coins, :n => 37), PokeAccess::I18n.t(:rem_scales, :n => 4)]
    falsy "and no money fragment at all", frags.any? { |f| f =~ /#{Regexp.escape(tr.money.to_s)}/ && f != PokeAccess::I18n.t(:rem_coins, :n => 37) }
    eq "the order the profile set", PokeAccess::Config.trainer_parts, [:name, :coins, :scales, :badges, :pokedex, :playtime]
    eq "and a price spoken through the money label counts coins too", PokeAccess::Config.money_label, :rem_coins
  ensure
    $PokemonBag = old_bag
    PokeAccess::Locator::TRANSFER_SCRIPTS.clear
    patterns.each { |re| PokeAccess::Locator::TRANSFER_SCRIPTS.push(re) }
    (PokeAccess::Locator.clear_verdicts rescue nil)
    TrainerLineCases.restore(saved)
    PokeAccess::Config.status_names.clear; PokeAccess::Config.status_names.merge!(tables[0])
    PokeAccess::Config.field_weather_names.clear; PokeAccess::Config.field_weather_names.merge!(tables[1])
    PokeAccess::Config.money_label = tables[2]
  end
end
