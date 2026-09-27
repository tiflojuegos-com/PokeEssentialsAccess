# The speech dispatcher hands each line to every observer as a message (text, category, interrupt, number); the
# category is the call's, else the innermost scope's, else the moment's; a raising observer cannot silence the mod.
Suite.define("speech: a line's category is the call's, else the innermost scope's, else the moment's") do
  seen = []
  PokeAccess::Speech.observe(:spec_speech) { |msg| seen.push(msg) }
  begin
    PokeAccess.speak("uno", true, :battle)
    PokeAccess::Speech.as(:menu) do
      PokeAccess.speak("dos")
      PokeAccess::Speech.as(:info) { PokeAccess.speak("tres") }
      PokeAccess.speak("cuatro", false, :system)
    end
    eq "the call names it first, then the innermost scope, then the outer one again",
       seen.map { |m| [m.text, m.category] }, [["uno", :battle], ["dos", :menu], ["tres", :info], ["cuatro", :system]]
    eq "each carries whether it cut in", seen.map { |m| m.interrupt }, [true, true, true, false]
    nums = seen.map { |m| m.seq }
    truthy "and a number that rises with every line", nums == nums.sort && nums.uniq.length == 4

    seen.clear
    begin
      PokeAccess::Speech.as(:info) { raise "boom" }
    rescue RuntimeError
      nil
    end
    PokeAccess.speak("cinco")
    falsy "a scope left by an exception does not outlive it", seen[0].category == :info
  ensure
    PokeAccess::Speech.unobserve(:spec_speech)
  end
end

Suite.define("speech: with nothing named, the moment decides") do
  had_scene = $scene
  had_temp = $game_temp
  begin
    PokeAccess.message_enter
    eq "a message on screen is dialogue", PokeAccess::Speech.deduce, :dialogue
    PokeAccess.message_leave

    PokeAccess::Battle.battle_started
    eq "a fight is battle", PokeAccess::Speech.deduce, :battle
    PokeAccess::Battle.battle_ended

    $scene = Object.new
    eq "a screen that is not the map is a menu", PokeAccess::Speech.deduce, :menu
    $scene = Scene_Map.new
    $game_temp = Struct.new(:in_menu).new(false)
    eq "the map under free control is navigation", PokeAccess::Speech.deduce, :nav
    $game_temp = Struct.new(:in_menu).new(true)
    eq "and the pause menu over it is a menu", PokeAccess::Speech.deduce, :menu
  ensure
    $scene = had_scene
    $game_temp = had_temp
    PokeAccess.message_leave while PokeAccess.message_depth > 0
    PokeAccess::Battle.battle_ended
  end
end

Suite.define("speech: observers are keyed, replaced by key, and never able to silence the reader") do
  a = []
  PokeAccess::Speech.observe(:spec_obs) { |msg| a.push(msg.text) }
  PokeAccess::Speech.observe(:spec_obs) { |msg| a.push("again #{msg.text}") }
  PokeAccess::Speech.observe(:spec_bad) { |_msg| raise "an instrument fails" }
  begin
    SpeakCapture.clear
    PokeAccess.speak("hola")
    eq "registering a key again replaces the observer instead of adding one", a, ["again hola"]
    eq "and a raising observer does not stop the line reaching the reader", SpeakCapture.lines, ["hola"]
    PokeAccess::Speech.unobserve(:spec_obs)
    PokeAccess.speak("adios")
    eq "an observer taken off hears nothing more", a, ["again hola"]
  ensure
    PokeAccess::Speech.unobserve(:spec_obs)
    PokeAccess::Speech.unobserve(:spec_bad)
  end
end

Suite.define("speech: the chokepoints file their lines under their category") do
  seen = []
  PokeAccess::Speech.observe(:spec_chokepoints) { |msg| seen.push([msg.text, msg.category]) }
  begin
    PokeAccess::Verbosity.rotate_scheme
    eq "the verbosity key speaks as the mod talking about itself", seen.last[1], :system
    PokeAccess::Config.verbosity = :full
    PokeAccess::PausePanel.instance_variable_set(:@last, [])
    PokeAccess::PausePanel.say(["Dinero: 500"])
    eq "a pause panel is a menu", seen.last, ["Dinero: 500", :menu]
  ensure
    PokeAccess::Speech.unobserve(:spec_chokepoints)
    PokeAccess::PausePanel.instance_variable_set(:@last, [])
  end
end
