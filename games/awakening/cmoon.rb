# The CMoon hub (pbDMoon) and its submenus, whose cursor is a local variable: a per-frame poll mirrors it (no
# wrap) over the labels painted by pbDrawOutlineText, with a stack of frames as submenus open inside the hub.
module PokeAccess
  module AwakeningCMoon
    @entries = nil
    @labels = []
    @sel = 0
    @last = nil
    @stack = []

    # Opens a mirror frame for a screen of entries rows; nil for a screen read elsewhere, whose frame only keeps
    # the one underneath quiet.
    def self.open(entries)
      @stack.push([@entries, @labels, @sel, @last])
      @entries = entries
      @labels = []
      @sel = 0
      @last = nil
    end

    # Closes the current frame and restores the one underneath, its focus forgotten so it speaks again.
    def self.close
      @entries, @labels, @sel, @last = @stack.pop || [nil, [], 0, nil]
      @last = nil
    end

    # Collects a label drawn while the current screen is opening, in draw order.
    def self.label(text)
      return unless @entries
      t = PokeAccess.clean(text.to_s)
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
      PokeAccess.speak(PokeAccess::Verbosity.list_entry(name, @sel + 1, @entries), true)
    rescue StandardError
      nil
    end
  end
end

# Screen => row count, from each screen's bound in the dump (`select < N` gives N + 1 rows). A nil count marks a
# screen read elsewhere (or not yet) that opens inside a hub loop: its frame keeps the hub's mirror quiet.
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
  # The same quiet frame for the class screens, which run from their constructor.
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
  # FatesCartas.main is a singleton method, which around cannot bind (it checks instance methods); override can.
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
