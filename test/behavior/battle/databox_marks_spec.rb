# The marks a gen-6 databox draws beside a battler's name (battleBoxOwned, shiny...), read from the images its refresh
# paints (the gen-6 hook on the stub databox): with the HP key from the battle marks reading's medium level, always
# with the info key, and once, queued, as a foe comes in.
class MarksBattlerG6
  attr_accessor :name, :level, :hp, :totalhp, :gender, :displayGender, :status, :index, :pokemon
  def initialize(index, pokemon)
    @index = index; @pokemon = pokemon; @name = "Pidgey"; @level = 12; @hp = 30; @totalhp = 30
    @gender = 0; @displayGender = 0; @status = 0
  end
  def pbTypes(_withtype = false); []; end
end

Suite.define("battle boxes (gen 6): the marks a foe's box draws, with its lines and as it comes in") do
  t = PokeAccess::I18n
  bt = PokeAccess::Battle
  foe = MarksBattlerG6.new(1, Object.new)
  box = PokemonDataBox.new(foe)
  plain = bt.battler_state(foe, true)
  battle = Object.new
  battle.define_singleton_method(:battlers) { [nil, foe] }
  bt.set_battle(battle)
  level = PokeAccess::Config.verbosity
  begin
    plain_info = bt.foe_info
    SpeakCapture.clear
    eq "the box's refresh keeps its own result", box.refresh, :refreshed
    eq "no icon drawn, nothing added", bt.battler_state(foe, true), plain
    silent "and nothing said as it comes in"
    box.owned = true
    box.refresh
    eq "the HP key says a mark after the foe's state", bt.battler_state(foe, true), "#{plain}, #{t.t(:dex_caught)}"
    eq "the info key after its line", bt.foe_info, "#{plain_info}, #{t.t(:dex_caught)}"
    silent "and a mark drawn after it came in is left to the battle's own message"

    rare = MarksBattlerG6.new(3, Object.new)
    rare_box = PokemonDataBox.new(rare)
    rare_box.owned = true
    rare_box.shiny = true
    SpeakCapture.clear
    rare_box.refresh
    rare_box.refresh
    eq "a foe that comes in with marks says them once, queued", SpeakCapture.log,
       [[t.t(:bt_marks_entry, :name => "Pidgey", :marks => "#{t.t(:dex_caught)}, #{t.t(:pk_shiny)}"), false]]

    PokeAccess::Config.verbosity = :brief
    eq "at brief the HP key leaves the marks out", bt.battler_state(foe, true), plain
    eq "while the info key keeps them", bt.foe_info, "#{plain_info}, #{t.t(:dex_caught)}"
    other = MarksBattlerG6.new(5, Object.new)
    other_box = PokemonDataBox.new(other)
    other_box.shiny = true
    SpeakCapture.clear
    other_box.refresh
    silent "and nothing is said as a foe comes in"
    PokeAccess::Config.verbosity = level

    box.owned = false
    box.refresh
    eq "a box that stops drawing it stops saying it", bt.battler_state(foe, true), plain
  ensure
    PokeAccess::Config.verbosity = level
    bt.clear_battle
  end
end
