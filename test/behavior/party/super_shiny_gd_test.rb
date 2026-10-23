# Skyflyer's games (anil, royal) paint a super shiny with its own purple star: the lists say it (skyflyer_common), and
# so does Royal's copy of the DBK battler panel, its profile file loaded for each test and taken back after.
class SuperShinyGdTest < PokeAccessTest
  ROYAL = File.join(Harness::ROOT, "games", "royal", "super_shiny.rb")

  test "Royal's battler panel names a super shiny by its purple star" do
    with_royal_panel do
      assert_equal ["Pikachu", t(:pk_super_shiny)], PokeAccess::DBKBattlerInfo.identity_parts(battler(pikachu(true)))
    end
  end

  test "Royal's battler panel names any other shiny by the shiny word" do
    with_royal_panel do
      { "a plain shiny" => pikachu(false), "a shiny that knows no super tier" => pikachu(nil) }.each do |what, pk|
        assert_equal ["Pikachu", t(:pk_shiny)], PokeAccess::DBKBattlerInfo.identity_parts(battler(pk)), what
      end
    end
  end

  test "the lists say a super shiny's star in the shiny mark's place, ahead of pokerus" do
    assert_equal [t(:pk_super_shiny), t(:pk_pokerus)], PokeAccess::Party.icon_mark_list(pikachu(true, 1))
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # A shiny Pikachu, super shiny or not (nil: one that knows no such tier), carrying pokerus at that stage (0: it never
  # had it).
  def pikachu(super_shiny, pokerus = 0)
    pk = Object.new
    pk.define_singleton_method(:name) { "Pikachu" }
    pk.define_singleton_method(:shiny?) { true }
    pk.define_singleton_method(:super_shiny?) { super_shiny } unless super_shiny.nil?
    pk.define_singleton_method(:pokerusStage) { pokerus }
    pk
  end

  # A battler of the player's showing pk.
  def battler(pk)
    b = Object.new
    b.define_singleton_method(:pokemon) { pk }
    b
  end

  # Runs the block with Royal's super_shiny.rb loaded over the plugin's panel, then takes back all it installed: the
  # panel's shiny word and the alias that kept it, the override's entry in the listing and the profile's name.
  def with_royal_panel
    panel = PokeAccess::DBKBattlerInfo
    game = PokeAccess::Game
    word = panel.method(:shiny_word)
    methods = panel.singleton_methods(false)
    overrides = PokeAccess::Hooks.overrides.length
    profiles = game.profiles.dup
    name = game.instance_variable_get(:@profile_name)
    eval(Harness.source(ROYAL), TOPLEVEL_BINDING, ROYAL)
    yield
  ensure
    panel.define_singleton_method(:shiny_word, word)
    (panel.singleton_methods(false) - methods).each { |added| panel.singleton_class.send(:remove_method, added) }
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    game.profiles.replace(profiles)
    game.instance_variable_set(:@profile_name, name)
  end
end
