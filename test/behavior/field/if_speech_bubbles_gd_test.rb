# Infinite Fusion's speech bubbles (games/infinitefusion_common/speech_bubbles.rb): after pbCallBub the next message
# window floats over (1) or points with an arrow at (2) an event; a line whose bubble marks an event other than the one
# running is led by where that event stands and the player's tag for it, never its editor's name. The game's window
# functions and map interpreter, reduced to what the reader asks of them, come before the profile file binds to them.

# The map interpreter as the reader asks it: which event it runs, and whether it is running.
class IFSpecInterpreter
  def initialize(event_id, running = true); @event_id = event_id; @running = running; end
  def running?; @running; end
end

def pbCreateMessageWindow(_viewport = nil, _skin = nil); Object.new; end
def pbDisposeMessageWindow(_msgwindow); nil; end
def pbMapInterpreter; $if_spec_interpreter; end

bubbles_path = File.join(Harness::ROOT, "games", "infinitefusion_common", "speech_bubbles.rb")
eval(Harness.source(bubbles_path), TOPLEVEL_BINDING, bubbles_path)

class IfSpeechBubblesGdTest < PokeAccessTest
  test "a line under an arrow bubble on another event is led by where it stands, its editor's name unsaid" do
    in_room { bubble(2, 14, "¡Uno!") }
    assert_equal [["2 #{t(:dir_left)}, 1 #{t(:dir_up)}: ¡Uno!", false]], SpeakCapture.log
  end

  test "a floating bubble on a tagged event is led by the player's tag and where it stands" do
    in_room { bubble(1, 15, "¡Dos!") }
    assert_equal [["hermana, 4 #{t(:dir_left)}: ¡Dos!", false]], SpeakCapture.log
  end

  test "a bubble on the event being talked to leads nothing" do
    in_room { bubble(2, 29, "¡Tres!") }
    assert_equal ["¡Tres!"], SpeakCapture.lines
  end

  test "a line with no floating or arrow bubble is not led" do
    in_room do
      bubble(0, 14, "¡Cuatro!")
      bubble(3, 14, "¡Cinco!")
    end
    assert_equal ["¡Cuatro!", "¡Cinco!"], SpeakCapture.lines
  end

  test "a bubble over the player, or on an event the map lacks, leads nothing" do
    in_room do
      bubble(2, 0, "¡Seis!")
      bubble(2, 99, "¡Siete!")
    end
    assert_equal ["¡Seis!", "¡Siete!"], SpeakCapture.lines
  end

  test "a bubble on the map's first event leads its line too" do
    in_room do
      World.event(:id => 1, :x => 20, :y => 18, :name => "EV001")
      bubble(2, 1, "¡Once!")
    end
    assert_equal ["2 #{t(:dir_right)}: ¡Once!"], SpeakCapture.lines
  end

  test "a window closed with no line drops the head it was to carry" do
    in_room do
      bubble(2, 14, nil)
      PokeAccess.say_dialogue("¿Ocho?")
    end
    assert_equal ["¿Ocho?"], SpeakCapture.lines
  end

  test "with no interpreter running, any event's bubble leads its line" do
    in_room do
      $if_spec_interpreter = nil
      bubble(2, 29, "¡Nueve!")
    end
    assert_equal ["1 #{t(:dir_down)}: ¡Nueve!"], SpeakCapture.lines
  end

  test "an interpreter that has stopped counts as none running" do
    in_room do
      $if_spec_interpreter = IFSpecInterpreter.new(29, false)
      bubble(2, 29, "¡Diez!")
    end
    assert_equal ["1 #{t(:dir_down)}: ¡Diez!"], SpeakCapture.lines
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Runs the block where the lines are said: the player at (18,18), a kid the editor names "fake kid" at (16,17), a girl
  # the player tagged "hermana" at (14,18), and event 29 at (18,19), whose interpreter runs; the bubble's state, the
  # tag, the interpreter and any head still promised are dropped after.
  def in_room
    temp = $PokemonTemp
    $PokemonTemp = Struct.new(:speechbubble_bubble, :speechbubble_talking).new(nil, nil)
    $if_spec_interpreter = IFSpecInterpreter.new(29)
    $game_player.x = 18
    $game_player.y = 18
    World.event(:id => 14, :x => 16, :y => 17, :name => "fake kid")
    World.event(:id => 15, :x => 14, :y => 18, :name => "Niña")
    World.touch(:id => 29, :x => 18, :y => 19, :trigger => 3)
    PokeAccess::Tags.set($game_map.map_id, 15, "hermana")
    yield
  ensure
    PokeAccess::Tags.delete($game_map.map_id, 15)
    PokeAccess.before_next_line(nil)
    $PokemonTemp = temp
    $if_spec_interpreter = nil
  end

  # A message window shown under a bubble of kind (1 floating, 2 an arrow, others none) on event id, as pbCallBub leaves
  # it for the next window, saying line in it (nothing for nil) before it closes.
  def bubble(kind, id, line)
    $PokemonTemp.speechbubble_bubble = kind
    $PokemonTemp.speechbubble_talking = id
    window = pbCreateMessageWindow
    PokeAccess.say_dialogue(line) if line
    pbDisposeMessageWindow(window)
    $PokemonTemp.speechbubble_bubble = nil
  end
end
