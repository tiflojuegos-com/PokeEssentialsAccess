# Realidea's party panel (games/realidea/party.rb) over the gen-6 readers: the HP bar said as a share, since the panel
# writes its figures off its bitmap, while the info key keeps the figures the summary paints.
class RealideaPartyTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "realidea", "party.rb")
  T = PokeAccess::I18n
  Party = PokeAccess::Party
  MALE = " \xE2\x99\x82"

  class << self
    # The profile's panel_hp_figures?: its file is evaluated once per process, and core's method and the registries it
    # adds to are put back at once.
    def realidea_figures
      @realidea_figures ||= begin
        core = Party.method(:panel_hp_figures?)
        saved = [PokeAccess::Game.profiles.dup, PokeAccess::Hooks.overrides.dup,
                 PokeAccess::Hooks.instance_variable_get(:@bound).dup]
        eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
        mine = Party.method(:panel_hp_figures?)
        Party.define_singleton_method(:panel_hp_figures?, core)
        PokeAccess::Game.instance_variable_set(:@profiles, saved[0])
        PokeAccess::Game.instance_variable_set(:@profile_name, nil)
        PokeAccess::Hooks.overrides.replace(saved[1])
        PokeAccess::Hooks.instance_variable_set(:@bound, saved[2])
        mine
      end
    end
  end

  test "a party member says its HP bar as a share of the total, as the panel writes no figures" do
    with_realidea do
      assert_equal head + ", " + T.t(:bt_hp_pct, :n => 85), Party.party_line([member(30, 35)], 0)
    end
  end

  test "a sliver of HP left is at least 1 percent, and with none left only the fainted slot is said" do
    with_realidea do
      assert_equal [head + ", " + T.t(:bt_hp_pct, :n => 1), head + ", " + T.t(:pk_fainted)],
                   [Party.party_line([member(1, 300)], 0), Party.party_line([member(0, 35)], 0)]
    end
  end

  test "the info key keeps the HP figures the summary paints" do
    with_realidea do
      pk = member(30, 35)
      Party.party_line([pk], 0)
      assert_equal PokeAccess::Info.pokemon_info(pk), PokeAccess::Info.info_text
    end
  end

  test "an annotated panel says its annotation in place of the bar" do
    with_realidea do
      assert_equal head + ", APTO", Party.party_line([member(30, 35)], 0, "APTO")
    end
  end

  private

  # Runs the block with Realidea's override in force, core's put back after.
  def with_realidea
    core = Party.method(:panel_hp_figures?)
    Party.define_singleton_method(:panel_hp_figures?, self.class.realidea_figures)
    yield
  ensure
    Party.define_singleton_method(:panel_hp_figures?, core) if core
  end

  # A male level-12 Bulba with hp of total HP left.
  def member(hp, total)
    Poke.build(:name => "Bulba", :level => 12, :hp => hp, :totalhp => total, :gender => 0)
  end

  # The member's name, sex sign and level, as the panel writes them, the species its icon shows after the nickname.
  def head
    T.t(:pty_head, :name => "Bulba, Especie1", :sex => MALE, :level => 12)
  end
end
