module PokeAccess
  # Insurgence's challenge-run menu (Kernel.pbNuzlockeMenu): ten mouse-only checkboxes in a ControlWindow. While it
  # runs, up and down move a focus over them and left or right flip the focused one; confirm accepts what is ticked.
  module InsurgenceChallenges
    # Runs the menu with its keyboard route on.
    def self.run
      @window = nil
      @focus = 0
      @open = true
      yield
    ensure
      @open = false
      @window = nil
    end

    # The window's checkboxes, in order.
    def self.boxes(win)
      (win.controls rescue []).select { |c| c.respond_to?(:checked=) }
    end

    # The prompt above them: the first control that is no button.
    def self.prompt(win)
      c = (win.controls rescue []).find { |x| !x.respond_to?(:checked) && !(defined?(::Button) && x.is_a?(::Button)) }
      c ? PokeAccess.clean((c.label rescue "").to_s) : ""
    end

    # A checkbox as its label and its mark.
    def self.describe(c)
      "#{PokeAccess.clean(c.label.to_s)}, #{PokeAccess::I18n.t(c.checked ? :val_on : :val_off)}"
    end

    # How the menu is worked, with the game's accept and cancel keys as bound now.
    def self.keys_text
      PokeAccess::I18n.t(:ins_challenge_keys,
                         :accept => game_keys("Action") || PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter)),
                         :cancel => game_keys("Cancel/Menu") ||
                                    PokeAccess::KeyHints.key(:b, PokeAccess::I18n.t(:key_escape)))
    end

    # The keys the game's own Controls screen binds to one of its actions ($PokemonSystem.gameControls, read through
    # Keys2), joined; nil where they cannot be read.
    def self.game_keys(action)
      label = (_INTL(action) rescue action)
      rows = ($PokemonSystem.gameControls rescue nil) || []
      names = rows.select { |c| (c.controlAction rescue nil) == label }.map { |c| (c.keyName rescue nil).to_s }
      names = names.reject { |n| n.empty? }.uniq
      names.empty? ? nil : names.join(", ")
    rescue StandardError
      nil
    end

    # One frame, before the window's update: the opening read the first time, then the focus moves and flips.
    def self.frame(win)
      return unless @open
      list = boxes(win)
      return if list.empty?
      unless @window.equal?(win)
        @window = win
        @focus = 0
        return PokeAccess.speak(PokeAccess.sentences([prompt(win), keys_text, describe(list[0])]), false)
      end
      step = Input.trigger?(Input::DOWN) ? 1 : (Input.trigger?(Input::UP) ? -1 : 0)
      if step != 0
        @focus = [[@focus + step, 0].max, list.length - 1].min
        PokeAccess.speak(describe(list[@focus]), true)
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        c = list[@focus]
        c.checked = !c.checked
        PokeAccess.speak(PokeAccess::I18n.t(c.checked ? :val_on : :val_off), true)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("insurgence") do
  kernel("pbNuzlockeMenu", :around) { |_args, nxt| PokeAccess::InsurgenceChallenges.run { nxt.call } }
  before("ControlWindow", :update, :optional => true) { |w, _a| PokeAccess::InsurgenceChallenges.frame(w) }
end
