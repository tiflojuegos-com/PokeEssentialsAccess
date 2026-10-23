# The party's icon-only marks (Party.icon_mark_list): the shiny star, then pokerus while carried, none on an egg; how
# shiny? and pokerus? ask either era's engine; and the marks as a sentence of their own in the glance.
class IconMarksTest < PokeAccessTest
  T = PokeAccess::I18n
  Party = PokeAccess::Party

  # Raw pokerus counters by stage, strain in the high nibble and days left in the low: never infected, carrying it,
  # and cured with its strain kept.
  RAW_POKERUS = { 0 => 0x00, 1 => 0x21, 2 => 0x20 }.freeze

  test "says the shiny star, then pokerus while it is carried, and nothing for an ordinary member" do
    shiny = T.t(:pk_shiny)
    rus = T.t(:pk_pokerus)
    { [false, 0] => [], [true, 0] => [shiny], [false, 1] => [rus], [true, 1] => [shiny, rus],
      [false, 2] => [] }.each do |(is_shiny, stage), want|
      assert_equal want, Party.icon_mark_list(member(is_shiny, stage)), "shiny #{is_shiny}, pokerus stage #{stage}"
    end
  end

  test "says no marks for no Pokemon" do
    assert_equal [], Party.icon_mark_list(nil)
  end

  test "says no marks on an egg, shiny and infected as it is" do
    egg = member(true, 1)
    def egg.egg?; true; end
    assert_equal [], Party.icon_mark_list(egg)
  end

  test "asks a modern engine shiny? and a gen-6 one isShiny?" do
    [[{ :shiny? => true }, true], [{ :shiny? => false }, false], [{ :isShiny? => true }, true],
     [{ :isShiny? => false }, false], [{}, false]].each do |replies, want|
      assert_equal want, Party.shiny?(answering(replies)), "answering #{replies.inspect}"
    end
  end

  test "without a pokerus stage, counts a raw pokerus counter above zero" do
    [[{ :pokerus => 0 }, false], [{ :pokerus => 1 }, true], [{ :pokerus => RAW_POKERUS[1] }, true],
     [{}, false]].each do |replies, want|
      assert_equal want, Party.pokerus?(answering(replies)), "answering #{replies.inspect}"
    end
  end

  test "counts no pokerus where the stage is no number" do
    assert_equal false, Party.pokerus?(answering(:pokerusStage => Object.new))
  end

  test "falls back to isShiny? and the raw counter where shiny? and pokerusStage raise" do
    pk = answering(:isShiny? => true, :pokerus => RAW_POKERUS[1])
    def pk.shiny?; raise ArgumentError, "unreadable"; end
    def pk.pokerusStage; raise ArgumentError, "unreadable"; end
    assert_equal [T.t(:pk_shiny), T.t(:pk_pokerus)], Party.icon_mark_list(pk)
  end

  test "says no marks, rather than failing, when the game's shiny word raises" do
    original = Party.method(:shiny_word)
    Party.define_singleton_method(:shiny_word) { |_pk| raise ArgumentError, "broken word" }
    assert_equal [], Party.icon_mark_list(member(true, 1))
  ensure
    Party.define_singleton_method(:shiny_word, original)
  end

  test "the glance says the marks as a sentence of their own, before the panel's own icons" do
    pk = member(true, 1)
    pk.gender = nil
    pk.define_singleton_method(:expshare) { true }
    glance = T.t(:pk_glance, :name => pk.name, :level => pk.level, :hp => pk.hp, :tot => pk.totalhp)
    assert_equal "#{glance} #{T.t(:pk_shiny)}, #{T.t(:pk_pokerus)}, #{T.t(:pty_expshare)}.",
                 PokeAccess::Info.pokemon_info(pk)
  end

  private

  # A party member as the engine builds it: shiny or not, its pokerus answered both as a stage and as the raw counter.
  def member(shiny, stage)
    pk = Poke.build(:name => "Chispa", :shiny => shiny)
    pk.define_singleton_method(:pokerusStage) { stage }
    pk.define_singleton_method(:pokerus) { RAW_POKERUS[stage] }
    pk
  end

  # An object answering each method named in replies with its value, and nothing else.
  def answering(replies)
    o = Object.new
    replies.each { |name, value| o.define_singleton_method(name) { value } }
    o
  end
end
