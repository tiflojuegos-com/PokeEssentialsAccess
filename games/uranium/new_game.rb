module PokeAccess
  # Uranium's new-game screens: the custom-rules checklist (Window_PokemonNuzOption over CheckboxOptions, the focused
  # rule's help painted below it), the picture-only boy, neutral and girl selector and the naming screen's Delete key.
  module UraniumNewGame
    # A checklist row: the rule's name, the state its box shows and its help line; the last row is the exit command
    # with the help the scene writes under it.
    def self.row(win, i)
      opts = PokeAccess.ivar(win, :@options) || []
      return exit_row(win) if i >= opts.length
      o = opts[i]
      help = (o.helptext rescue nil).to_s
      parts = ["#{o.name.to_s.strip}, #{state(win, i)}"]
      parts.push(help) unless help.empty?
      parts.join(". ")
    end

    # The exit command and its help line, which exit_help left on the window.
    def self.exit_row(win)
      parts = [PokeAccess.ivar(win, :@exitmessage).to_s, PokeAccess.ivar(win, :@access_ura_exit_help).to_s]
      parts.reject { |t| t.empty? }.join(". ")
    end

    # Leaves on the checklist the help its scene writes under the exit command, by the scene's mode: the warning that
    # unchecked rules go for good when they are changed mid-game, else the start of the game.
    def self.exit_help(scene)
      win = PokeAccess.sprite(scene, "option")
      return unless win
      text = if PokeAccess.ivar(scene, :@mode) == 1
               _INTL("Permanently disable the options you unchecked.")
             else
               _INTL("Begin your game.")
             end
      win.instance_variable_set(:@access_ura_exit_help, text)
    end

    # The state a rule's box shows: unavailable (its prerequisite is off), locked, on or off.
    def self.state(win, i)
      o = PokeAccess.ivar(win, :@options)[i]
      key = if !(o.enabled? rescue true) then :ura_opt_unavailable
            elsif !(o.unlocked? rescue true) then :ura_opt_locked
            elsif (PokeAccess.ivar(win, :@optvalues) || [])[i] then :val_on
            else :val_off
            end
      PokeAccess::I18n.t(key)
    end

    # After a checklist update that flipped the focused box: its new state, interrupting.
    def self.toggled(win)
      return unless (win.mustUpdateOptions rescue false)
      i = win.index
      return if i.nil? || i >= (PokeAccess.ivar(win, :@options) || []).length
      PokeAccess.speak(state(win, i), true)
    end

    # Says the boy picture: queued the first time, as the selector opens on it, interrupting on later moves.
    def self.boy(scene)
      shown = PokeAccess.ivar(scene, :@access_ura_gsel)
      scene.instance_variable_set(:@access_ura_gsel, true)
      PokeAccess.speak(PokeAccess::I18n.t(:gsel_boy), shown ? true : false)
    end

    # The checklist's title, as its window paints it.
    def self.title(scene)
      box = PokeAccess.sprite(scene, "title")
      box ? (box.text rescue nil) : nil
    end
  end
end

PokeAccess::Game.define("uranium") do
  screen_reader("Window_PokemonNuzOption") { |win, i| PokeAccess::UraniumNewGame.row(win, i) }
  after("Window_PokemonNuzOption", :update, :hook_container => true) { |win, _r, _a| PokeAccess::UraniumNewGame.toggled(win) }
  read_on_open("PokemonRulesetScene", :pbStartScene) { |scene| PokeAccess::UraniumNewGame.title(scene) }
  after("PokemonRulesetScene", :pbStartScene) { |scene, _r, _a| PokeAccess::UraniumNewGame.exit_help(scene) }
  before("GenderSelectorScene", :selectBoy) { |s, _a| PokeAccess::UraniumNewGame.boy(s) }
  before("GenderSelectorScene", :selectNeutral) { |_s, _a| PokeAccess.speak(PokeAccess::I18n.t(:ura_gsel_neutral), true) }
  before("GenderSelectorScene", :selectGirl) { |_s, _a| PokeAccess.speak(PokeAccess::I18n.t(:gsel_girl), true) }
  after("Window_TextEntry", :deleteAtCursor) do |_w, r, _a|
    if r
      PokeAccess::Keys.typing!
      PokeAccess.speak(PokeAccess::I18n.t(:te_deleted), true)
    end
  end
end
