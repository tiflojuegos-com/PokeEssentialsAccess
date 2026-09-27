# Desolation's quest log (Scripts/Pokemon Desolation/Quest_Log.rb): a list of main or side quests, swapped with left
# and right, and a quest's page of objectives, turned with left and right when they overflow. The list's rows are the
# generic reader's; this says which list is up, the row again back on the list, and each quest page, its title and
# state first.
module PokeAccess
  module DesolationQuests
    # The state word of a quest or objective: 2 done, 1 in progress, anything else none.
    def self.state(n)
      case n.to_i
      when 2 then PokeAccess::I18n.t(:qu_status_done)
      when 1 then PokeAccess::I18n.t(:qu_status_pending)
      end
    end

    # A line with its state, or the bare line when it has none.
    def self.line(text, n)
      st = state(n)
      st ? PokeAccess::I18n.t(:qu_line, :name => text, :status => st) : text
    end

    # The objectives the page paints, top to bottom, each with its state from the quest's own list.
    def self.objectives(scene, quest)
      sprites = PokeAccess.ivar(scene, :@sprites) || {}
      wins = sprites.keys.select { |k| k.to_s =~ /\Abody / }.map { |k| sprites[k] }
      wins = wins.reject { |w| w.nil? || (w.disposed? rescue false) }.sort_by { |w| w.y.to_i }
      goals = quest.is_a?(Array) ? Array(quest[2]) : []
      wins.map do |w|
        t = w.text.to_s
        goal = goals.find { |g| g.is_a?(Array) && (_INTL(g[1].to_s) rescue g[1].to_s) == t }
        line(PokeAccess.clean(t), goal ? goal[0] : nil)
      end
    end

    # The page under the arrows: the quest's title and state unless already said, which page when there are
    # several, and its objectives.
    def self.page_text(scene, titled)
      log = PokeAccess.ivar(scene, :@currentlog)
      quest = log.is_a?(Array) ? log[PokeAccess.ivar(scene, :@index).to_i] : nil
      out = []
      title = (PokeAccess.sprite(scene, "header").text rescue nil)
      out.push(line(PokeAccess.clean(title), quest ? quest[1] : nil)) if title && !titled
      pages = Array(PokeAccess.ivar(scene, :@screens)).length
      if pages > 1
        out.push(PokeAccess::I18n.t(:adv_dex_page, :n => PokeAccess.ivar(scene, :@screen_index).to_i + 1, :m => pages))
      end
      PokeAccess.sentences(out.concat(objectives(scene, quest)))
    end

    # Says which list is up, the first row of the list queued behind it.
    def self.say_list(scene)
      head = (PokeAccess.sprite(scene, "subheader").text rescue nil)
      return if head.nil?
      win = PokeAccess.sprite(scene, "commands")
      PokeAccess::Cursor.reset(win, :cmd_focus) if win
      PokeAccess.speak(PokeAccess.clean(head), true)
    end

    # The list's loop runs again after each confirm, on the same window and row (back from a quest's page, or a
    # quest not found yet): from the second run on, the row is said again.
    def self.back_to_list(scene)
      if scene.instance_variable_get(:@access_listed)
        win = PokeAccess.sprite(scene, "commands")
        PokeAccess::Cursor.reset(win, :cmd_focus) if win
      end
      scene.instance_variable_set(:@access_listed, true)
    end
  end
end

PokeAccess::Game.define("desolation") do
  after("QuestLog_Scene", :pbStartScene) { |scene, _r, _a| PokeAccess::DesolationQuests.say_list(scene) }
  after("QuestLog_Scene", :pbSetCommands) { |scene, _r, _a| PokeAccess::DesolationQuests.say_list(scene) }
  before("QuestLog_Scene", :pbScene) { |scene, _a| PokeAccess::DesolationQuests.back_to_list(scene) }

  after("QuestInfo_Scene", :pbUpdate) do |scene, _r, _a|
    titled = scene.instance_variable_get(:@access_titled)
    PokeAccess::Cursor.announce(scene, :deso_quest_page, PokeAccess.ivar(scene, :@screen_index)) do
      scene.instance_variable_set(:@access_titled, true)
      PokeAccess::DesolationQuests.page_text(scene, titled)
    end
  end
end
