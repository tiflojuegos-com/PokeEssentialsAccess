# Event Indicators floats a marker over an event while its page carries an "Event Indicator" comment (a quest to
# take, in emerald); the locator says it after the event's name while it shows.

# One marker as the plugin keeps it in the map spriteset, indexed by event id.
EvIndSpecSprite = Struct.new(:type, :visible, :disposed) do
  def disposed?; disposed; end
end

# The scene the markers live under: spriteset(map_id) answers the map's spriteset, which holds them.
class EvIndSpecScene
  def initialize(sprites); @set = Struct.new(:event_indicator_sprites).new(sprites); end
  def spriteset(_map_id = -1); @set; end
end

def ev_ind_spec_with_scene(sprites)
  had = $scene
  $scene = EvIndSpecScene.new(sprites)
  yield
ensure
  $scene = had
end

Suite.define("event indicators: a quest marker over an event is said after its name") do
  ei = PokeAccess::EventIndicators
  quest = PokeAccess::I18n.t(:evind_quest)
  npc = World.event(:id => 3, :name => "Grunt", :sprite => "npc")
  plain = World.event(:id => 4, :name => "Nurse", :sprite => "nurse")
  sprites = []
  sprites[3] = EvIndSpecSprite.new("quest", true, false)
  ev_ind_spec_with_scene(sprites) do
    eq "a showing quest marker names itself", ei.mark(npc), quest
    eq "an event with none has no mark", ei.mark(plain), nil
    eq "the locator's marks for the event", PokeAccess::Locator.name_marks(npc), [quest]
    sprites[3] = EvIndSpecSprite.new("quest", false, false)
    eq "a hidden marker (its event is talking) is not said", ei.mark(npc), nil
    sprites[3] = EvIndSpecSprite.new("quest", true, true)
    eq "nor a disposed one (the page changed)", ei.mark(npc), nil
    sprites[3] = EvIndSpecSprite.new("question", true, false)
    eq "and a marker that is no quest one is left to its picture", ei.mark(npc), nil
  end
  eq "types drawn with the quest graphics are quests", [ei.type_key("questsimple"), ei.type_key("questshortnpc")],
     [:evind_quest, :evind_quest]
  eq "outside the map scene there is nothing to say", ei.mark(npc), nil
end

Suite.define("event indicators: the locator announces the mark with the event it focuses") do
  loc = PokeAccess::Locator
  npc = World.event(:id => 3, :name => "Grunt", :sprite => "npc", :x => 7, :y => 5)
  sprites = []
  sprites[3] = EvIndSpecSprite.new("quest", true, false)
  saved = [loc.instance_variable_get(:@target), loc.instance_variable_get(:@targets)]
  ev_ind_spec_with_scene(sprites) do
    begin
      loc.instance_variable_set(:@targets, [npc])
      loc.instance_variable_set(:@target, npc)
      SpeakCapture.clear
      loc.announce_selected(true)
      spoke "the name, then the mark, then the rest", /\A#{Regexp.escape(loc.target_name(npc))}, #{Regexp.escape(PokeAccess::I18n.t(:evind_quest))}, /
      off_map = Struct.new(:x, :y, :id).new(7, 5, 3)
      eq "a target that is not the map's own event carries no mark", loc.name_marks(off_map), []
    ensure
      loc.instance_variable_set(:@target, saved[0])
      loc.instance_variable_set(:@targets, saved[1])
    end
  end
end
