require "open3"
require "rbconfig"

# Xenoverse uses gen6. Its isolated fixtures need that engine's actual classes;
# complete-profile loading is checked independently under both engine models.
class XenoverseProfileCasesTest < PokeAccessTest
  CASES = %w[xenoverse_badges_test.rb xenoverse_bag_test.rb xenoverse_battle_bag_test.rb xenoverse_battle_menus_test.rb xenoverse_caught_pokemon_test.rb xenoverse_centers_test.rb xenoverse_controls_test.rb xenoverse_fullbox_choice_test.rb xenoverse_fullbox_test.rb xenoverse_game_modes_test.rb xenoverse_gender_test.rb xenoverse_mart_test.rb xenoverse_menu_test.rb xenoverse_naming_test.rb xenoverse_party_test.rb xenoverse_starter_test.rb xenoverse_summary_test.rb xenoverse_title_test.rb].freeze
  if ENGINE == :gen6
    CASES.each do |case_name|
      test "Xenoverse isolated case #{case_name}" do
        env = {"ESSENTIAL_PEA_SOURCE" => Harness::ROOT, "PA_ENGINE" => ENGINE.to_s,
               "RUBYOPT" => nil, "RUBYLIB" => nil}
        runner = File.join(Harness::ROOT, "test/support/xenoverse_case_runner.rb")
        output, errors, status = Open3.capture3(env, RbConfig.ruby, runner, case_name, "--seed", "4242")
        assert status.success?, "#{case_name}: #{errors}#{output}"
        summary = output.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips/)
        assert summary, output
        assert_operator summary[1].to_i, :>, 0
        assert_operator summary[2].to_i, :>, 0
        assert_equal ["0", "0", "0"], summary.captures[2, 3], output
        puts "XENO_CASE|#{ENGINE}|#{case_name}|#{summary[1]}|#{summary[2]}"
      end
    end
  end

  test "Xenoverse complete profile loads with actual key hints and unnamed field rules" do
    env = {"ESSENTIAL_PEA_SOURCE" => Harness::ROOT, "PA_ENGINE" => ENGINE.to_s,
           "RUBYOPT" => nil, "RUBYLIB" => nil}
    driver = File.join(Harness::ROOT, "test/support/xenoverse_profile_load_driver.rb")
    output, errors, status = Open3.capture3(env, RbConfig.ruby, driver)
    assert status.success?, errors + output
    assert_includes output, "PASS|xenoverse|#{ENGINE}|0 load errors|4 actual key hints|English cache|field rules unnamed"
  end
end
