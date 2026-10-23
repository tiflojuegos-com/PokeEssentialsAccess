# The trainer line of the gen-6 player ($Trainer), whose Pokedex counts are its own, and under Reminiscencia, whose
# profile says its coins and heart scales instead of money and badges; the shared cases are in trainer_line_cases.rb.
require File.expand_path("trainer_line_cases", File.dirname(__FILE__))

class TrainerLineTest < PokeAccessTest
  TrainerLineCases.define(self)

  test "a gen-6 trainer holding the Pokedex but missing either of its counts says no Pokedex" do
    { "seen" => [12, nil], "owned" => [nil, 30] }.each do |missing, dex|
      with_trainer(trainer(:dex => dex)) do
        assert_equal sentences("Rojo", money(1500), badges(4), playtime(2, 5)), PokeAccess::Info.trainer_info,
                     "no #{missing} count"
      end
    end
  end

  test "under Reminiscencia the line says its coins and heart scales in place of money and badges" do
    with_reminiscencia do
      with_bag(:COIN => 37, :HEARTSCALE => 4) do
        with_trainer(trainer) do
          assert_equal sentences("Rojo", t(:rem_coins, :n => 37), t(:rem_scales, :n => 4), playtime(2, 5)),
                       PokeAccess::Info.trainer_info
        end
      end
    end
  end

  test "under Reminiscencia money is spoken as coins" do
    with_reminiscencia do
      assert_equal t(:rem_coins, :n => 1500), PokeAccess::Info.trainer_part(:money, trainer)
    end
  end

  private

  # Runs the block with Reminiscencia's profile (games/reminiscencia/constants.rb) evaluated over this process; all it
  # writes (money label, trainer parts and order, key hints, transfer patterns, name filters, name tables, the
  # profile list) is put back after.
  def with_reminiscencia
    cfg = PokeAccess::Config
    saved = [cfg.money_label, cfg.trainer_parts.dup, PokeAccess::Info::TRAINER_PARTS.dup, cfg.key_hint_letters.dup,
             PokeAccess::Locator::TRANSFER_SCRIPTS.dup, PokeAccess.name_filters.dup, cfg.status_names.dup,
             cfg.field_weather_names.dup, PokeAccess::Game.profiles.dup]
    path = File.join(Harness::ROOT, "games", "reminiscencia", "constants.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    PokeAccess::Locator.clear_verdicts
    yield
  ensure
    cfg.money_label = saved[0]
    cfg.trainer_parts = saved[1]
    PokeAccess::Info::TRAINER_PARTS.replace(saved[2])
    cfg.key_hint_letters.replace(saved[3])
    PokeAccess::Locator::TRANSFER_SCRIPTS.replace(saved[4])
    PokeAccess.name_filters.replace(saved[5])
    cfg.status_names.replace(saved[6])
    cfg.field_weather_names.replace(saved[7])
    PokeAccess::Game.profiles.replace(saved[8])
    PokeAccess::Locator.clear_verdicts
  end

  # Runs the block with a bag holding the given quantities, the game's bag put back after.
  def with_bag(counts)
    was = $PokemonBag
    bag = Object.new
    bag.define_singleton_method(:pbQuantity) { |item| counts[item] || 0 }
    $PokemonBag = bag
    yield
  ensure
    $PokemonBag = was
  end
end
