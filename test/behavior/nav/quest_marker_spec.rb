# Drago2308's Quest Marker (plugins/quest_marker.rb): an event whose live page opens with a quest_marker comment is
# said by the locator with what its picture shows, as each profile's quest_markers.rb describes its pictures.
def qm_event(id, comment)
  list = comment ? [TestCmd.new(108, [comment]), TestCmd.new(108, ["255"])] : [TestCmd.new(101, ["Hola"])]
  TestGameEvent.new(:id => id, :name => "Senyorita", :pages => [TestPage.new(:trigger => 0, :sprite => "BW040", :list => list)])
end

Suite.define("quest markers: the marker picture comes from the page's first comment, and marks the event") do
  qm = PokeAccess::QuestMarker
  root = File.expand_path("../../..", File.dirname(__FILE__))
  word = qm.method(:word)
  overrides = PokeAccess::Hooks.overrides.length
  restore = lambda do
    qm.define_singleton_method(:word, word)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
  end
  begin
    marked = qm_event(1, "quest_marker red")
    eq "the picture the comment asks for", qm.picture(marked), "red"
    eq "a page without the comment has none", qm.picture(qm_event(2, nil)), nil
    eq "nor one whose first comment is another", qm.picture(qm_event(3, "otra cosa")), nil
    eq "an undescribed picture adds no mark", PokeAccess::Locator.name_marks(marked), []

    load File.join(root, "games", "realidea", "quest_markers.rb")
    eq "Realidea's red is its yellow exclamation mark", PokeAccess::Locator.name_marks(marked),
       [PokeAccess::I18n.t(:qm_excl_yellow)]
    eq "and its third skull the red one", qm.mark(qm_event(4, "quest_marker calavera3")),
       PokeAccess::I18n.t(:qm_skull_red)
    World.clear_events
    $game_map.events[1] = marked
    PokeAccess::Locator.instance_variable_set(:@target, marked)
    SpeakCapture.clear
    PokeAccess::Locator.announce_selected(true)
    match "the locator says the mark after the event's name", SpeakCapture.last.to_s,
          /\A#{Regexp.escape(PokeAccess::Locator.target_name(marked))}, #{Regexp.escape(PokeAccess::I18n.t(:qm_excl_yellow))}/

    restore.call
    load File.join(root, "games", "awakening", "quest_markers.rb")
    eq "Awakening's red is a blue speech bubble", qm.mark(marked), PokeAccess::I18n.t(:qm_bubble_blue)
    eq "and its tripletriad the VS badge", qm.mark(qm_event(5, "quest_marker tripletriad")), PokeAccess::I18n.t(:qm_vs)
    unresolved = [:qm_excl_yellow, :qm_excl_blue, :qm_skull_white, :qm_skull_yellow, :qm_skull_red, :qm_bubble_blue,
                  :qm_vs].select { |k| PokeAccess::I18n.t(k) == k.to_s }
    eq "every label of both games resolves", unresolved, []
  ensure
    restore.call
    PokeAccess::Locator.instance_variable_set(:@target, nil)
    World.clear_events
  end
end
