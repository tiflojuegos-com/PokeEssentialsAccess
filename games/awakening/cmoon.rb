# The CMoon hub (pbDMoon, script 0221) and the screens it opens. This is the front door of the whole Fates
# system -- diary, legendaries, compendium, miscellaneous and the summon creator -- and it was silent, which
# made everything behind it unreachable even though those screens are now covered.
#
# Its cursor is a LOCAL variable (`select`), so no hook can read it. Same situation as the Triple Triad
# pickers in the core, and the same answer: an around-hook holds the screen while its loop runs, and a
# per-frame poll mirrors the very same navigation the loop does (DOWN while below the last row, UP while
# above the first, no wrap) to know where the focus is. The labels are not hardcoded here either -- each
# screen paints them once at setup with pbDrawOutlineText, so those calls are captured while it is opening
# and the captured strings are what gets spoken. That keeps the conditional first entry ("Diario de D`" vs
# "Diario de Personajes") correct without this file having to know why it varies.
#
# Why a STACK of frames rather than one flag: the hub opens its submenus from INSIDE its own loop (the
# `break` only runs once the submenu returns), so the hub's ensure has not fired yet. With a single flag the
# hub's mirror stayed armed underneath, the submenu navigated with the very same UP/DOWN keys, and every
# press moved the hub cursor too and announced an entry from the screen behind -- while pbDrawOutlineText
# kept appending the submenu's labels to the hub's list, shifting those wrong entries further with each one.
# Every one of these screens has the same shape and differs only in how many rows it holds, so a frame per
# open screen reads the one that actually has focus and restores the one underneath on the way out.
module PokeAccess
  module AwakeningCMoon
    @entries = nil
    @labels = []
    @sel = 0
    @last = nil
    @stack = []

    # Opens a mirror frame. entries is how many rows the screen holds; nil means a screen this file does not
    # read -- the summon crafter, announced by its own plugin reader -- whose frame exists only so the screen
    # underneath stays quiet and stops collecting its labels while it is up.
    def self.open(entries)
      @stack.push([@entries, @labels, @sel, @last])
      @entries = entries
      @labels = []
      @sel = 0
      @last = nil
    end

    # Closes the current frame and restores the one underneath, with its focus forgotten so coming back to it
    # says where you are instead of leaving a screen that never speaks again.
    def self.close
      @entries, @labels, @sel, @last = @stack.pop || [nil, [], 0, nil]
      @last = nil
    end

    # Collects a label drawn while the current screen is opening, in draw order.
    def self.label(text)
      return unless @entries
      t = PokeAccess.clean(text.to_s).to_s.strip
      @labels.push(t) unless t.empty?
    rescue StandardError
      nil
    end

    # Mirrors the focused screen's own navigation and speaks the focused entry when it changes.
    def self.poll
      return unless @entries
      @sel += 1 if Input.trigger?(Input::DOWN) && @sel < @entries - 1
      @sel -= 1 if Input.trigger?(Input::UP) && @sel > 0
      return if @sel == @last
      @last = @sel
      name = @labels[@sel]
      return if name.nil? || name.empty?
      PokeAccess.speak(PokeAccess::I18n.t(:list_entry, :name => name,
                                          :n => @sel + 1, :tot => @entries), true)
    rescue StandardError
      nil
    end
  end
end

# Row counts come from each screen's own bound in the dump (`select < N` gives N + 1 rows): pbDMoon 0221,
# pbDMoonb 0224 and pbDMoonc 0225 hold five, pbCompendium 0222 two, pbCallMisc 0223 four.
#
# The rest are listed with NO count on purpose. They are screens this file does not read -- each has its own
# reader, or none yet -- and they are opened from inside a hub loop that has not ended, so without a frame of
# their own the hub's mirror stays armed underneath: their UP/DOWN moves the hub cursor too and the player
# hears an entry from the screen behind, while pbDrawOutlineText keeps appending their labels to the hub's
# list and shifting those wrong entries further with every one. A countless frame is the "somebody else owns
# this screen, keep quiet" marker.
module PokeAccess
  module AwakeningCMoon
    SCREENS = {
      "pbDMoon" => 5, "pbDMoonb" => 5, "pbDMoonc" => 5, "pbCompendium" => 2, "pbCallMisc" => 4,
      "pbItemCrafter" => nil, "pbQuestlog" => nil, "openGacha" => nil, "pbCallAchievements" => nil,
      "pbCallAngel" => nil, "pbCallDemon" => nil, "pbCallTitle" => nil, "pbCallTrainer" => nil,
      "pbCallLegen" => nil
    }
    1.upto(9) { |n| SCREENS["pbCallLegen#{n}"] = nil }
  end
end

PokeAccess::Game.define("awakening") do
  PokeAccess::AwakeningCMoon::SCREENS.each do |fname, entries|
    kernel(fname, :around) do |_args, nxt|
      PokeAccess::AwakeningCMoon.open(entries)
      begin
        nxt.call
      ensure
        PokeAccess::AwakeningCMoon.close
      end
    end
  end
  # The same, for the children that are classes rather than top-level functions. Both are opened with .new
  # and run their whole screen from the constructor, so that is where the frame has to go.
  [["Fates_Menu_Personajes", :initialize], ["Logros_Scene", :initialize]].each do |cname, meth|
    around(cname, meth) do |_s, nxt, _a|
      PokeAccess::AwakeningCMoon.open(nil)
      begin
        nxt.call
      ensure
        PokeAccess::AwakeningCMoon.close
      end
    end
  end
  # FatesCartas.main is a SINGLETON method, and around cannot see one: wrap tests method_defined?, which asks
  # about instance methods only, so this hook silently bound nothing and logged a phantom typo on every boot.
  # The frame it was meant to open never opened either, leaving the hub's own row poller armed while the card
  # screen was up -- and the cards move with UP and DOWN, so every keypress also announced a hub row on top
  # of them. override resolves the singleton (fates_extra.rb wraps the same method that way).
  override("FatesCartas", :main) do |_mod, original, _args|
    PokeAccess::AwakeningCMoon.open(nil)
    begin
      original.call
    ensure
      PokeAccess::AwakeningCMoon.close
    end
  end
  kernel("pbDrawOutlineText", :before) { |args, _r| PokeAccess::AwakeningCMoon.label(args[5]) }
  poll_each_frame { PokeAccess::AwakeningCMoon.poll }
end
