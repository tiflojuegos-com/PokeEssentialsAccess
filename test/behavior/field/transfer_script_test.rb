# The script-transfer registry under the gen-6 stubs (the shared cases live in transfer_script_cases.rb), with
# Reminiscencia's profile declaring its dungeon-entrance call; and, kept here, the gen-6 summary read page by page,
# its stats page with the IV stars of Pokemon Z, the profile this pass loads.
require File.expand_path("transfer_script_cases", File.dirname(__FILE__))

class TransferScriptTest < PokeAccessTest
  TransferScriptCases.define(self)

  test "under Reminiscencia a dungeon entrance, Kanto's or Hoenn's, is a door to its map, named as an exit" do
    with_reminiscencia do
      named = t(:loc_exit)
      doors = { "getToDungeon(319)" => [319, true, true, true, :door, named],
                "getToHoennDungeon(208)" => [208, true, true, true, :door, named] }
      got = doors.map do |call, _|
        ev = entrance(call)
        [call, door_state(ev) + [loc.target_name(ev)]]
      end
      assert_equal doors, got.to_h
    end
  end

  test "the summary reads pages two to five as the player turns to each, and a page turned back to again" do
    scene = PokemonSummaryScene.new
    scene.pbStartScene([chispa], 0)
    SpeakCapture.clear
    [2, 3, 4, 5, 3].each { |page| scene.drawPage(page) }
    memo = "#{t(:sm_memo)}. #{t(:sm_nature, :n => 'Naturaleza0')}. #{t(:sm_char_1)}."
    stats = t(:sum_stats, :hp => 40, :tot => 40, :atk => 30, :def => 28, :spa => 32, :spd => 26, :spe => 35)
    stars = [:st_hp, :st_atk, :st_def, :st_spatk, :st_spdef, :st_speed].map { |k| "#{t(k)} #{t(:iv_star_perfect)}" }
    ability = t(:sum_ability, :a => "Habilidad1")
    sheet = "#{t(:sm_stats)}. #{stats} #{t(:iv_stars, :list => stars.join(', '))} #{ability}"
    assert_equal [[memo, true], [sheet, true], [t(:sm_no_moves), true], [t(:sm_ribbons_none), true], [sheet, true]],
                 SpeakCapture.log
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # A Reminiscencia dungeon entrance running call: a sprite-less touch tile, three wide by its editor note size(3,1).
  def entrance(call)
    tile([TestCmd.new(355, [call])], 1, "size(3,1)")
  end

  # Chispa as the stand-in builds her: the engine's nature 0 (no stat raised), every IV 31 with HP first (the
  # characteristic sm_char_1), ability 1, her four move slots empty (0, gen 6's number for no move) and no ribbons.
  def chispa
    Poke.build(:name => "Chispa", :moves => [0, 0, 0, 0])
  end

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
end
