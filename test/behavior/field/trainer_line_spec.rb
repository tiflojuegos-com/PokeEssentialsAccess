# Gen-6 trainer line (cases in trainer_line_cases.rb), plus Reminiscencia's coins and heart scales instead of money:
# its constants.rb, this repo's own, is evaluated over a fake bag and everything it touches restored.
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
    eval(File.read(path), TOPLEVEL_BINDING, path)
    tr = info.player_object
    frags = TrainerLineCases.fragments
    eq "name, then coins, then heart scales", frags[0, 3], [tr.name.to_s, PokeAccess::I18n.t(:rem_coins, :n => 37), PokeAccess::I18n.t(:rem_scales, :n => 4)]
    falsy "and no money fragment at all", frags.any? { |f| f =~ /#{Regexp.escape(tr.money.to_s)}/ && f != PokeAccess::I18n.t(:rem_coins, :n => 37) }
    eq "the order the profile set, with no badges or Pokedex the game never shows",
       PokeAccess::Config.trainer_parts, [:name, :coins, :scales, :playtime]
    badge = PokeAccess::Info.trainer_part(:badges, tr)
    falsy "so no badge count is said", !badge.nil? && frags.include?(badge)
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
