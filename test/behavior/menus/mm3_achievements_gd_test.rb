# Mega MewThree's achievements (plugins/mm3_achievements.rb): the highlight's achievement said with its place, its level
# and what the box says of it, read after the screen's update has changed the box.

# As the plugin's: update moves the box to the hidden window's row.
class PokemonAchievements_Scene
  class CommandWindow; attr_accessor :index; def initialize; @index = 0; end; end
  class Button; def initialize(level); @level = level; end; end
  class Box
    def initialize(row); change(row); end
    def change(row); @description = row[2]; @progress = row[3]; end
  end
  ROWS = [["First win", "1/3", "Win a battle.", "4/10"], ["All done", "3/3", "Finish the game.", "12"]].freeze

  def initialize
    @buttons = ROWS.map { |r| r[0] }
    @sprites = { "command_window" => CommandWindow.new, "achievementText" => Box.new(ROWS[0]) }
    ROWS.each_with_index { |r, i| @sprites["button#{i}"] = Button.new(r[1]) }
    @shown = 0
  end

  def highlight(i); @sprites["command_window"].index = i; end

  attr_reader :claimed_on_update

  def update
    @claimed_on_update = PokeAccess.dedicated?(@sprites["command_window"]) if @claimed_on_update.nil?
    i = @sprites["command_window"].index
    @sprites["achievementText"].change(ROWS[i]) if i != @shown
    @shown = i
  end

  def pbEndScene; end
end

begin
  path = File.join(Harness::ROOT, "plugins", "mm3_achievements.rb")
  src = Harness.source(path)
  hooks = src.index('PokeAccess::FocusReader.define("PokemonAchievements_Scene"')
  eval(src[hooks..-1], TOPLEVEL_BINDING, path, src[0, hooks].count("\n") + 1)
end

class Mm3AchievementsGdTest < PokeAccessTest
  test "the screen opens on its first achievement, queued, with its level, description and progress" do
    PokemonAchievements_Scene.new.update
    assert_equal [[first_line, false]], SpeakCapture.log
  end

  test "a move cuts in with the box already changed, and a frame with no move says nothing" do
    scene = PokemonAchievements_Scene.new
    scene.update
    SpeakCapture.clear
    scene.highlight(1)
    2.times { scene.update }
    assert_equal [[last_line, true]], SpeakCapture.log
  end

  test "the hidden window is claimed before it first updates, so nothing else reads its row" do
    scene = PokemonAchievements_Scene.new
    scene.update
    assert_equal true, scene.claimed_on_update
  end

  test "the info key keeps the line until the screen closes" do
    scene = PokemonAchievements_Scene.new
    scene.update
    assert_equal first_line, PokeAccess::Info.info_text
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "a count without a slash is said as painted, and an empty one as nothing" do
    assert_equal ["12", ""], ["12", nil].map { |c| PokeAccess::MM3Achievements.count_words(c) }
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def first_line
    "First win, #{list_place(1, 2)}. #{t(:mm3_level, :n => t(:mm3_of, :n => "1", :tot => "3"))}. Win a battle. " \
      "#{t(:mm3_progress, :n => t(:mm3_of, :n => "4", :tot => "10"))}"
  end

  def last_line
    "All done, #{list_place(2, 2)}. #{t(:mm3_level, :n => t(:mm3_of, :n => "3", :tot => "3"))}. Finish the game. " \
      "#{t(:mm3_progress, :n => "12")}"
  end
end
