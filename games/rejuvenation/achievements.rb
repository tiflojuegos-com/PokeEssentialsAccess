module PokeAccess
  # Rejuvenation's achievements (PokemonAchievementsScene, from the CyberNav): a hidden command window moves the
  # focus over painted buttons, each a name and its level, and a panel below with the description and the progress
  # to the next level. A level reached on the map pops up over it as a LocationWindow.
  module RejuvAchievements
    # How Achievements#progress's popup begins; the map-name signs, the other LocationWindows, do not.
    POPUP = /\AAchievement Reached!/

    # The achievement at i as painted: name, level of levels, description and progress.
    def self.text(scene, i)
      a = PokeAccess.ivar(scene, :@achievements)[i]
      k = PokeAccess.ivar(scene, :@achievementInternalNames)[i]
      levels = PokeAccess.ivar(scene, :@_buttons)[i][1]
      mine = $Trainer.achievements
      PokeAccess::I18n.t(:rj_achievement, :name => PokeAccess.clean(a[:name]), :lvl => mine.getLevel(k),
                         :max => levels.length, :desc => PokeAccess.clean(a[:description]),
                         :prog => mine.getProgress(k), :goal => mine.getMilestone(k))
    rescue StandardError
      nil
    end

    # Claims the hidden window, whose bare names the generic reader would say, and says the focused achievement
    # when the cursor lands on a new one: the first queued, later moves cutting in.
    def self.follow(scene)
      win = PokeAccess.dedicate(PokeAccess.sprite(scene, "command_window"))
      return if win.nil?
      i = win.index
      PokeAccess::Cursor.announce(win, :rj_achievement, i, true, false) { text(scene, i) }
    end

    # The achievement popup's lines as painted, one sentence each, or nil for any other popup.
    def self.popup_text(text)
      t = text.to_s
      t =~ POPUP ? PokeAccess.sentences(t.split(/\r?\n/)) : nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  before("PokemonAchievementsScene", :update, :optional => true) do |scene, _a|
    PokeAccess::RejuvAchievements.follow(scene)
  end

  after("LocationWindow", :initialize, :optional => true) do |_window, _r, args|
    t = PokeAccess::RejuvAchievements.popup_text(args[0])
    PokeAccess.speak_clean(t, false) if t
  end
end
