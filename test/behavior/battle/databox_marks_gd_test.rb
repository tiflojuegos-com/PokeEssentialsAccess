# The marks a modern databox draws beside a battler's name (draw_owned_icon's icon_own, from the stock folder or a
# Deluxe Battle Kit style's own, and the icons plugins register), read from the images its refresh paints through
# the v21 hook on the stub databox.
class DataboxMarksGdTest < PokeAccessTest
  T = PokeAccess::I18n

  # A v21 battler as its box and the readers see it: a level-12 male Pidgey at full hp, with no status.
  class Battler
    attr_accessor :name, :level, :hp, :totalhp, :gender, :status, :index, :pokemon
    def initialize(index)
      @index = index; @pokemon = Object.new; @name = "Pidgey"; @level = 12; @hp = 30; @totalhp = 30
      @gender = 0; @status = :NONE
    end
    def types; []; end
    def pbTypes(_withtype = false); []; end
  end

  test "keeps what the box's refresh answers" do
    assert_equal :refreshed, ::Battle::Scene::PokemonDataBox.new(Battler.new(1)).refresh
  end

  test "adds nothing for a box that draws no caught icon" do
    foe = Battler.new(1)
    drawn(foe)
    assert_equal plain_state, PokeAccess::Battle.battler_state(foe, true)
  end

  test "says the caught icon from the stock folder or a battle style's own" do
    [nil, "Graphics/Plugins/Deluxe Battle Kit/Databoxes/Style"].each do |folder|
      foe = Battler.new(1)
      drawn(foe, :owned => true, :style_path => folder)
      assert_equal "#{plain_state}, #{T.t(:dex_caught)}", PokeAccess::Battle.battler_state(foe, true),
                   "from #{folder || 'the stock folder'}"
    end
  end

  test "puts the marks after a modern status" do
    foe = Battler.new(1)
    foe.status = :BURN
    drawn(foe, :owned => true)
    assert_equal "#{plain_state}, StatusBURN, #{T.t(:dex_caught)}", PokeAccess::Battle.battler_state(foe, true)
  end

  test "names a species' own Mega and Primal icons, ZUD's Dynamax and Ultra Burst and the kit's Hyper Mode, in order" do
    foe = Battler.new(3)
    drawn(foe, :extra => %w[icon_mega_Charizard icon_primal_Kyogre icon_dynamax icon_ultra icon_hyper_mode])
    assert_equal [T.t(:bt_mark_mega), T.t(:bt_mark_primal), T.t(:bt_m_dynamax), T.t(:bt_m_ultra), T.t(:dbk_mark_hyper)],
                 PokeAccess::Battle.shown_marks(foe)
  end

  test "ignores the icons that stand for no mark" do
    foe = Battler.new(1)
    drawn(foe, :extra => %w[icon_status icon_megaphone])
    assert_equal [], PokeAccess::Battle.shown_marks(foe)
  end

  private

  # The HP key's line for the battler with nothing added: name and sign, level and hp as a percentage.
  def plain_state
    T.t(:bt_state, :name => "Pidgey ♂", :level => 12, :hp => T.t(:bt_hp_pct, :n => 100))
  end

  # The battler's box with the given seams (:owned, :style_path, :extra), refreshed once.
  def drawn(battler, seams = {})
    box = ::Battle::Scene::PokemonDataBox.new(battler)
    seams.each { |seam, value| box.send("#{seam}=", value) }
    box.refresh
    box
  end
end
