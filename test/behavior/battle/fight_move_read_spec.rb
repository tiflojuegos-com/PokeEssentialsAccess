# read_fight_move, the move-list reader shared by both fight-menu shapes (stock setIndex, and the
# Infinite Fusion fork's index= / setIndexAndMode). It was inline in the setIndex hook until the fork
# needed the same body from two more places, so it is exercised directly here.

# The subset of a fight display the reader touches: @battler with its move list, and @index.
def fight_display(moves, index)
  d = Object.new
  battler = Object.new
  battler.instance_variable_set(:@m, moves)
  def battler.moves; @m; end
  d.instance_variable_set(:@battler, battler)
  d.instance_variable_set(:@index, index)
  d
end

def fake_move(name, id = 1, pp = 15, total = 15)
  m = Object.new
  m.instance_variable_set(:@d, [name, id, pp, total])
  def m.name; @d[0]; end
  def m.id; @d[1]; end
  def m.pp; @d[2]; end
  def m.totalpp; @d[3]; end
  m
end

Suite.define("battle: the focused move is read with its pp, once per change") do
  moves = [fake_move("Ember"), fake_move("Growl", 2, 30, 40)]
  d = fight_display(moves, 0)

  PokeAccess::Battle.read_fight_move(d)
  spoke_once "the move under the cursor is named", /Ember/

  SpeakCapture.clear
  PokeAccess::Battle.read_fight_move(d)
  silent "the same slot is not repeated every frame"

  SpeakCapture.clear
  d.instance_variable_set(:@index, 1)
  PokeAccess::Battle.read_fight_move(d)
  spoke "moving to the next move reads it", /Growl/
  spoke "with its remaining pp", /30/
end

Suite.define("battle: an empty move slot is neither spoken nor recorded") do
  moves = [fake_move("Ember"), fake_move("", 0, 0, 0), fake_move("Tackle", 3)]
  d = fight_display(moves, 0)
  PokeAccess::Battle.read_fight_move(d)
  SpeakCapture.clear

  d.instance_variable_set(:@index, 1)
  PokeAccess::Battle.read_fight_move(d)
  silent "an empty slot says nothing"
  eq "and does not overwrite the dedup key, so the last real move is still what is remembered",
     d.instance_variable_get(:@access_cur_fight_move), 0

  SpeakCapture.clear
  d.instance_variable_set(:@index, 2)
  PokeAccess::Battle.read_fight_move(d)
  spoke "so the next real move still reads", /Tackle/
end

# The fork opens the menu through setIndexAndMode, which has to queue behind the hp/turn lines instead of
# cutting them -- the same distinction v21 makes.
Suite.define("battle: the opening read queues, navigation interrupts") do
  d = fight_display([fake_move("Ember")], 0)
  PokeAccess::Battle.read_fight_move(d, false)
  falsy "the opening read did not interrupt", (SpeakCapture.log.last || [])[1]

  SpeakCapture.clear
  d2 = fight_display([fake_move("Ember")], 0)
  PokeAccess::Battle.read_fight_move(d2)
  truthy "a navigation read does", (SpeakCapture.log.last || [])[1]
end
