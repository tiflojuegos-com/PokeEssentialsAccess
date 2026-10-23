# Reminiscencia's profile registers each key the game reads raw (T, S, F, A, V, 1 to 4) as a remap extra named by its
# uses, so the remap menu refuses those keys to other actions. Only the profile's extras block is evaluated.
class ReminRawKeysTest < PokeAccessTest
  Remap = PokeAccess::Remap
  PATH = File.join(Harness::ROOT, "games", "reminiscencia", "menus.rb")
  # The rows the profile registers, [action a saved binding names, virtual-key, label key]: T and S (pause menu, several
  # screens), F (text log), A (blessing odds, dating-sim tabs), V (message skip), 1 to 4 (summary moves, party lead).
  EXTRAS = [[:fast_travel, 0x54, :rem_ext_key_t], [:help, 0x53, :rem_ext_key_s], [:text_log, 0x46, :rem_ext_key_f],
            [:game_a, 0x41, :rem_ext_key_a], [:skip_text, 0x56, :rem_ext_key_v], [:key_1, 0x31, :rem_ext_key_1],
            [:key_2, 0x32, :rem_ext_key_2], [:key_3, 0x33, :rem_ext_key_3], [:key_4, 0x34, :rem_ext_key_4]]

  test "registers every raw key the game reads, under the action names saved bindings use" do
    with_profile_extras { assert_equal EXTRAS, Remap.extras }
  end

  test "registers each raw key once, though the profile's block runs again" do
    with_profile_extras do
      run_profile_extras
      assert_equal EXTRAS, Remap.extras
    end
  end

  test "refuses each of those keys to another action, naming the game's use of it" do
    asked = { [0x53, :x] => :help, [0x46, :a] => :text_log, [0x41, :left] => :game_a, [0x56, :c] => :skip_text,
              [0x31, :fast_travel] => :key_1, [0x32, :help] => :key_2, [0x33, :hp] => :key_3, [0x34, :b] => :key_4 }
    with_profile_extras do
      asked.each { |(vk, action), use| assert_equal use, Remap.conflict(vk, action), "#{action} on 0x#{vk.to_s(16)}" }
    end
  end

  test "T is refused as the mod's info key while that sits on T, and as the game's fast travel once it moves" do
    with_profile_extras do
      assert_equal :info, Remap.conflict(0x54, :c), "the mod's own key comes first"
      PokeAccess::Config.keys = PokeAccess::Config.keys.merge(:info => 0x55)
      assert_equal :fast_travel, Remap.conflict(0x54, :c), "then the game's T"
    end
  end

  test "names each raw key in the remap menu by the game's uses of it" do
    spanish = PokeAccess::I18n.table("es")
    with_profile_extras do
      EXTRAS.each do |sym, _vk, key|
        assert spanish.key?(key.to_s), "#{key} is written"
        assert_equal PokeAccess::I18n.t(key), Remap.label(sym), "the label of #{sym}"
      end
      ["Caja", "habilidad", "Bolsa"].each { |use| assert_includes Remap.label(:fast_travel), use, "T names #{use}" }
      assert_includes Remap.label(:help), "pestañas", "S names the dating sim's tabs"
    end
  end

  private

  # Runs the block with the extras the profile's extras block registers and nothing else; the registry and the list of
  # profiles put back after.
  def with_profile_extras
    extras = Remap.extras.dup
    profiles = PokeAccess::Game.profiles.dup
    Remap.extras.clear
    run_profile_extras
    yield
  ensure
    Remap.extras.replace(extras)
    PokeAccess::Game.profiles.replace(profiles)
  end

  # Evaluates the profile's extras block (its first Game.define) at its own lines of the file.
  def run_profile_extras
    found = Harness.source(PATH).match(/^PokeAccess::Game\.define\("reminiscencia"\) do\r?\n  remap_extra.*?^end\r?\n/m)
    eval(found[0], TOPLEVEL_BINDING, PATH, found.pre_match.count("\n") + 1)
  end
end
