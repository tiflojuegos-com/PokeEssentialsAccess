# Game.define registers a profile's name once and runs its block on a Definition, whose every verb hands its
# arguments and block to the toolkit call that registers it, or merges into the table it names.
class GameApiTest < PokeAccessTest
  Game = PokeAccess::Game
  PROFILE = "api_probe"

  # Each verb that only forwards: [verb, its arguments, the module and method it reaches, the calls that method gets
  # as [arguments, whether the verb's block came along]].
  FORWARDS = [
    [:screen_reader, ["ApiWindow"], PokeAccess::Menus, :def_extractor, [[["ApiWindow"], true]]],
    [:info_window, ["ApiScene", :api_key, 2], PokeAccess::InfoWindow, :watch, [[["ApiScene", :api_key, 2, {}], false]]],
    [:info_window, ["ApiScene", :api_key, 2, { :every_frame => true }], PokeAccess::InfoWindow, :watch,
     [[["ApiScene", :api_key, 2, { :every_frame => true }], false]]],
    [:hall_of_fame, ["ApiHallA", ["ApiHallB"]], PokeAccess::HallOfFame, :bind,
     [[["ApiHallA"], false], [["ApiHallB"], false]]],
    [:after, ["ApiScene", :update], PokeAccess::Hooks, :after_hook, [[["ApiScene", :update, {}], true]]],
    [:after, ["ApiScene", :update, { :hook_container => true }], PokeAccess::Hooks, :after_hook,
     [[["ApiScene", :update, { :hook_container => true }], true]]],
    [:before, ["ApiScene", :update, { :optional => true }], PokeAccess::Hooks, :before_hook,
     [[["ApiScene", :update, { :optional => true }], true]]],
    [:around, ["ApiScene", :update, { :optional => true }], PokeAccess::Hooks, :around_hook,
     [[["ApiScene", :update, { :optional => true }], true]]],
    [:read_on_open, ["ApiScene"], PokeAccess::Hooks, :read_on_open, [[["ApiScene", :pbStartScene, {}], true]]],
    [:read_on_open, ["ApiScene", :pbOpen, { :timing => :before }], PokeAccess::Hooks, :read_on_open,
     [[["ApiScene", :pbOpen, { :timing => :before }], true]]],
    [:override, ["ApiScene", :update], PokeAccess::Hooks, :override,
     [[["ApiScene", :update, { :tag => "game_#{PROFILE}" }], true]]],
    [:kernel, ["pbApiCall"], PokeAccess::Hooks, :wrap_kernel,
     [[["pbApiCall", "game_#{PROFILE}_pbApiCall", :before], true]]],
    [:kernel, ["pbApiCall", :after], PokeAccess::Hooks, :wrap_kernel,
     [[["pbApiCall", "game_#{PROFILE}_pbApiCall", :after], true]]],
    [:diag_section, [:api_section], PokeAccess::Keys, :register_diag_section, [[[:api_section, :scene], true]]],
    [:diag_section, [:api_section, :perf], PokeAccess::Keys, :register_diag_section, [[[:api_section, :perf], true]]],
    [:remap_extra, [:api_action, 0x51, :lbl_api], PokeAccess::Remap, :register_extra,
     [[[:api_action, 0x51, :lbl_api], false]]],
    [:poll_each_frame, [], PokeAccess::Frame, :each_pulse, [[[], true]]],
    [:trainer_part, [:api_part], PokeAccess::Info, :set_trainer_part, [[[:api_part], true]]],
    [:mechanic, [:grid, [3, 4]], PokeAccess::World::Mechanics, :define, [[[:grid, [3, 4]], true]]],
    [:event_name, [], PokeAccess::Locator, :register_rule, [[[:name], true]]],
    [:event_category, [:api_cat], PokeAccess::Locator, :register_rule, [[[:category, :api_cat], true]]],
    [:event_hidden, [], PokeAccess::Locator, :register_rule, [[[:hidden], true]]],
    [:name_mark, [], PokeAccess::Locator, :register_rule, [[[:mark], true]]],
    [:hazard, [/api_lava/, :api_lava], PokeAccess::Locator, :register_hazard, [[[/api_lava/, :api_lava], false]]],
    [:teleporter, [/api_pad/], PokeAccess::Locator, :register_teleporter, [[[/api_pad/], false]]],
    [:transfer_script, [/api_warp\((\d+)\)/], PokeAccess::Locator, :register_transfer_script,
     [[[/api_warp\((\d+)\)/], false]]],
    [:field_move_item, [:SURF, :APIBOARD], PokeAccess::FieldMoves, :register_item, [[[:SURF, :APIBOARD], false]]],
    [:script_condition, [/api_cond/], PokeAccess::EventPages::ScriptCondition, :register_atom, [[[/api_cond/], true]]],
    [:terrain_rule, [], PokeAccess::Routes::Moves, :arrival_rule, [[[nil], true]]],
    [:terrain_rule, [:api_owner], PokeAccess::Routes::Moves, :arrival_rule, [[[:api_owner], true]]],
    [:held_key_ground, [:api_owner], PokeAccess::Routes::Moves, :held_key_rule, [[[:api_owner], true]]],
    [:terrain_exit, [:api_owner], PokeAccess::Routes::Moves, :leave_rule, [[[:api_owner], true]]],
    [:assisted_step, [:api_owner], PokeAccess::Routes::Moves, :assist_source, [[[:api_owner], true]]],
    [:plain_passability, [], PokeAccess::World::Probe, :plain!, [[[], false]]],
    [:pull_script, [/api_pull/], PokeAccess::Routes::Effects, :pull_script, [[[/api_pull/], false]]],
    [:on_picture, [], PokeAccess::PictureCues, :register, [[[], true]]]
  ].freeze

  # A game method a profile's hook binds to.
  class HookTarget
    def ping; :orig; end
  end

  # A command window a profile's reader answers for.
  class Window
    def index; 2; end
  end

  test "hands each verb's arguments and block to the call that registers it" do
    kept_profiles do
      FORWARDS.each do |verb, args, target, meth, want|
        marker = proc { :marker }
        calls = recording(target, meth) { Game.define(PROFILE) { send(verb, *args, &marker) } }
        assert_equal want, calls.map { |got, blk| [got, blk.equal?(marker)] }, "#{verb} #{args.inspect}"
      end
    end
  end

  test "sets the setting config names" do
    kept_profiles { Game.define(PROFILE) { config(:history_size, 50) } }
    assert_equal 50, PokeAccess::Config.history_size
  end

  test "adds button labels to the ones the remap menu has" do
    PokeAccess::Config.rebind_labels = { :a => "Alfa" }
    kept_profiles { Game.define(PROFILE) { button_labels(:q => "Quaff") } }
    assert_equal({ :a => "Alfa", :q => "Quaff" }, PokeAccess::Config.rebind_labels)
  end

  test "adds key-hint letters to the ones declared before" do
    kept_tables do
      PokeAccess::Config.key_hint_letters.replace("A" => :use)
      kept_profiles { Game.define(PROFILE) { key_hints("Z" => :api_button) } }
      assert_equal({ "A" => :use, "Z" => :api_button }, PokeAccess::Config.key_hint_letters)
    end
  end

  test "merges a game's own ids into the core name table it names" do
    kept_tables do
      core = PokeAccess::Config.status_names.dup
      kept_profiles { Game.define(PROFILE) { names(:status_names, 99 => :api_status) } }
      assert_equal core.merge(99 => :api_status), PokeAccess::Config.status_names
    end
  end

  test "sets the trainer line's parts, in their order, as symbols" do
    kept_tables do
      kept_profiles { Game.define(PROFILE) { trainer_order(["badges", :name]) } }
      assert_equal [:badges, :name], PokeAccess::Config.trainer_parts
    end
  end

  test "adds picture texts to the ones the picture cues speak" do
    kept_tables do
      kept_profiles { Game.define(PROFILE) { picture_texts("api_pic" => "Pulsa A") } }
      assert_equal "Pulsa A", PokeAccess::PictureCues::TEXTS["api_pic"]
    end
  end

  test "adds a per-language build's picture texts with their pictures' own language" do
    kept_tables do
      texts = { :api_pic_es => { :es => "Pulsa A", :en => "Press A" } }
      kept_profiles { Game.define(PROFILE) { picture_texts_multibuild(:es, texts) } }
      assert_equal [:es, texts[:api_pic_es]],
                   [PokeAccess::PictureCues::BASE_LANG["api_pic_es"], PokeAccess::PictureCues::TEXTS[:api_pic_es]]
    end
  end

  test "binds a profile's hook, which runs after the method it names" do
    ran = []
    kept_profiles { Game.define(PROFILE) { after("GameApiTest::HookTarget", :ping) { |_i, r, _a| ran << r } } }
    assert_equal :orig, HookTarget.new.ping
    assert_equal [:orig], ran
  end

  test "registers a profile's screen reader, which reads its window's focused option" do
    kept_extractors do
      kept_profiles { Game.define(PROFILE) { screen_reader("GameApiTest::Window") { |_w, i| "fila #{i}" } } }
      assert_equal "fila 2", PokeAccess::Menus.focused_text(Window.new)
    end
  end

  test "registers a profile's per-frame block, which every pulse runs" do
    ticks = []
    kept_pollers do
      kept_profiles { Game.define(PROFILE) { poll_each_frame { ticks << :tick } } }
      PokeAccess::Frame.run_pollers
    end
    assert_equal [:tick], ticks
  end

  test "registers a profile's name once, however many blocks define it" do
    kept_profiles do
      before = Game.profiles.dup
      2.times { Game.define(PROFILE) {} }
      assert_equal before + [PROFILE], Game.profiles
    end
  end

  test "registers no name for a define without one" do
    kept_profiles do
      before = Game.profiles.dup
      Game.define {}
      assert_equal before, Game.profiles
    end
  end

  test "registers the name of a define with no block" do
    kept_profiles do
      Game.define("api_bare")
      assert_equal "api_bare", Game.profiles.last
    end
  end

  test "drops the profile name it memoised once a new profile is defined" do
    kept_profiles do
      Game.profiles.clear
      Game.instance_variable_set(:@profile_name, "stale")
      Game.define(PROFILE) {}
      assert_equal PROFILE, Game.profile_name
    end
  end

  private

  # The calls made to mod.meth while the block runs, as [arguments, block], the method itself put back after.
  def recording(mod, meth)
    calls = []
    meta = mod.singleton_class
    kept = :"api_kept_#{meth.to_s.delete('!?=')}"
    meta.send(:alias_method, kept, meth)
    meta.send(:define_method, meth) { |*args, &blk| calls.push([args, blk]); nil }
    yield
    calls
  ensure
    meta.send(:alias_method, meth, kept)
    meta.send(:remove_method, kept)
  end

  # Runs the block and puts the defined profiles and the memoised profile name back as they were.
  def kept_profiles
    profiles = Game.profiles.dup
    name = Game.instance_variable_get(:@profile_name)
    yield
  ensure
    Game.profiles.replace(profiles)
    Game.instance_variable_set(:@profile_name, name)
  end

  # Runs the block and puts back Config's key-hint letters, status names and trainer parts, and the picture cues'
  # texts and base languages.
  def kept_tables
    tables = [PokeAccess::Config.key_hint_letters, PokeAccess::Config.status_names, PokeAccess::PictureCues::TEXTS,
              PokeAccess::PictureCues::BASE_LANG]
    saved = tables.map { |t| t.dup }
    parts = PokeAccess::Config.trainer_parts
    yield
  ensure
    tables.each_with_index { |t, i| t.replace(saved[i]) }
    PokeAccess::Config.trainer_parts = parts
  end

  # Runs the block and puts the command-window readers back as they were.
  def kept_extractors
    saved = PokeAccess::Menus::EXTRACTORS.dup
    yield
  ensure
    PokeAccess::Menus::EXTRACTORS.replace(saved)
  end

  # Runs the block with no per-frame pollers but those it registers, the real ones put back after.
  def kept_pollers
    frame = PokeAccess::Frame
    saved = frame.instance_variable_get(:@pollers)
    frame.instance_variable_set(:@pollers, [])
    yield
  ensure
    frame.instance_variable_set(:@pollers, saved)
  end
end
