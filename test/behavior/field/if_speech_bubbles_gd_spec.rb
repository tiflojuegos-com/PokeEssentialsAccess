# Infinite Fusion's speech bubbles: after pbCallBub the next message window floats over (1) or points with an arrow at
# (2) an event; a line whose bubble marks an event other than the one running is led by where it stands and the
# player's tag for it. The game's window functions and map interpreter, reduced to what the reader asks of them, are
# defined before the profile file binds to them.
class IFSpecInterpreter
  def initialize(event_id); @event_id = event_id; end
  def running?; true; end
end

def pbCreateMessageWindow(_viewport = nil, _skin = nil); Object.new; end
def pbDisposeMessageWindow(_msgwindow); nil; end
def pbMapInterpreter; $if_spec_interpreter; end

Suite.define("infinite fusion: a line in a bubble on another event is led by who that is and where it stands") do
  unless $if_speech_bubbles_loaded
    load File.expand_path("../../../games/infinitefusion_common/speech_bubbles.rb", File.dirname(__FILE__))
    $if_speech_bubbles_loaded = true
  end
  loc = PokeAccess::Locator
  old_temp = $PokemonTemp
  px = $game_player.x
  py = $game_player.y
  begin
    $PokemonTemp = Struct.new(:speechbubble_bubble, :speechbubble_talking).new(nil, nil)
    $if_spec_interpreter = IFSpecInterpreter.new(29)
    $game_player.x = 18
    $game_player.y = 18
    World.event(:id => 14, :x => 16, :y => 17, :name => "fake kid")
    World.event(:id => 15, :x => 14, :y => 18, :name => "Niña")
    PokeAccess::Tags.set($game_map.map_id, 15, "hermana")
    World.touch(:id => 29, :x => 18, :y => 19, :trigger => 3)
    PokeAccess.before_next_line(nil)
    shown = lambda do |kind, id, line|
      $PokemonTemp.speechbubble_bubble = kind
      $PokemonTemp.speechbubble_talking = id
      w = pbCreateMessageWindow
      PokeAccess.say_dialogue(line)
      pbDisposeMessageWindow(w)
      $PokemonTemp.speechbubble_bubble = nil
    end

    SpeakCapture.clear
    shown.call(2, 14, "One!")
    shown.call(1, 15, "Two!")
    eq "the arrow's event by its place alone, its editor's name unsaid; the floating bubble's by the player's tag too",
       SpeakCapture.lines, ["#{loc.dir_phrase(-2, -1)}: One!", "hermana, #{loc.dir_phrase(-4, 0)}: Two!"]

    SpeakCapture.clear
    shown.call(2, 29, "Three!")
    shown.call(3, 14, "Four!")
    shown.call(0, 14, "Five!")
    shown.call(2, 0, "Six!")
    eq "not the running event itself, nor a bubble by the player, none, or on no event", SpeakCapture.lines,
       ["Three!", "Four!", "Five!", "Six!"]

    $PokemonTemp.speechbubble_bubble = 2
    $PokemonTemp.speechbubble_talking = 14
    pbDisposeMessageWindow(pbCreateMessageWindow)
    $PokemonTemp.speechbubble_bubble = nil
    SpeakCapture.clear
    PokeAccess.say_dialogue("Seven?")
    eq "a window closed with no line drops the head it was to carry", SpeakCapture.lines, ["Seven?"]

    $if_spec_interpreter = nil
    SpeakCapture.clear
    shown.call(2, 29, "Eight!")
    eq "with no interpreter running, any event's bubble leads its line", SpeakCapture.lines,
       ["#{loc.dir_phrase(0, 1)}: Eight!"]
  ensure
    PokeAccess::Tags.delete($game_map.map_id, 15)
    PokeAccess.before_next_line(nil)
    $PokemonTemp = old_temp
    $if_spec_interpreter = nil
    $game_player.x = px
    $game_player.y = py
    World.clear_events
  end
end
