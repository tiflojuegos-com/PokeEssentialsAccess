module PokeAccess
  # Mega MewThree's Achievement System (PokemonAchievements_Scene): a hidden command window moves the highlight over a
  # list of buttons, each painting its level, and a box shows the focused achievement's description and progress.
  module MM3Achievements
    # The focused achievement: its name and place, its level, then what the box says about it.
    def self.line(name, i, scene)
      box = PokeAccess.sprite(scene, "achievementText")
      level = PokeAccess.ivar(PokeAccess.sprite(scene, "button#{i}"), :@level)
      total = PokeAccess.ivar(scene, :@buttons).length
      PokeAccess.sentences([PokeAccess::Verbosity.list_entry(name, i + 1, total),
                            PokeAccess::I18n.t(:mm3_level, :n => count_words(level)),
                            PokeAccess.ivar(box, :@description),
                            PokeAccess::I18n.t(:mm3_progress, :n => count_words(PokeAccess.ivar(box, :@progress)))])
    end

    # A count the screen paints "5/10" in words, a lone one (a goal already finished) as it is.
    def self.count_words(painted)
      n, tot = painted.to_s.split("/")
      tot ? PokeAccess::I18n.t(:mm3_of, :n => n, :tot => tot) : n.to_s
    end
  end
end

PokeAccess::FocusReader.define("PokemonAchievements_Scene", :index => "command_window", :items => :@buttons,
                               :slot => :mm3_achievement, :close => :pbEndScene, :optional => true,
                               :hook_container => true) do |name, i, scene|
  PokeAccess::MM3Achievements.line(name, i, scene)
end
