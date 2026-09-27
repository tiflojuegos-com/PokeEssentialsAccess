module PokeAccess
  # Uranium's Black/White options: its own SliderOption can paint a word instead of its floor (lowtext: the
  # autosave slider's "Off"), and the scene writes each row's help from its @HELPTEXT list, not into a textbox.
  module UraniumOptions
    # The word a slider paints at its floor, or nil where it paints the number.
    def self.floor_word(o, v)
      low = (o.lowtext rescue nil)
      (low && v == o.optstart) ? low.to_s : nil
    end

    # The focused row's help from the scene's @HELPTEXT, taken when the row changes: kept for the info key and, while
    # descriptions are said, spoken after the row. nil where the scene keeps no such list.
    def self.help(scene)
      list = PokeAccess.ivar(scene, :@HELPTEXT)
      return nil unless list.is_a?(Array)
      opt = PokeAccess.sprite(scene, "option")
      idx = (opt.index rescue nil)
      text = idx ? PokeAccess.clean(list[idx].to_s) : ""
      return true if text.empty? || !PokeAccess::Cursor.changed?(scene, :ura_opt_help, idx)
      PokeAccess::Info.set_info(:text, text)
      PokeAccess.speak(text, false) if PokeAccess::Verbosity.descriptions?
      true
    end
  end
end

PokeAccess::Game.define("uranium") do
  override("PokeAccess::Options", :value_of) do |_mod, original, args|
    PokeAccess::UraniumOptions.floor_word(args[0], args[1]) || original.call
  end
  override("PokeAccess::OptionHelp", :read) do |_mod, original, args|
    PokeAccess::UraniumOptions.help(args[0]) || original.call
  end
end
