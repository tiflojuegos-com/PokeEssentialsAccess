# Challenge / randomizer rule editors (the Challenge Modes and Randomizer EX plugins): a checkbox list of
# rule names, each with an ON/OFF toggle drawn beside it, plus a trailing "Confirm". The toggle lives in
# @text_key, so the generic command reader speaks the name and never the state -- which is the only thing
# the player is there to change.
#
# Three copies compared line by line: Challenge Modes in two games and Randomizer EX in one. The window
# class is IDENTICAL in all three (same initialize, same @text_key[i] = command[1], same drawItem, same
# commands= setter). They differ only in the label the game PAINTS -- "ACTIVADO"/"DESACTIVADO" in the
# translated copy, "ON"/"OFF" in the other -- which this reader never uses: the state is read from the
# number and spoken through the mod's own i18n, so it comes out in the player's language either way.
module PokeAccess
  module ChallengeRules
    # The focused rule with its on/off state, or a plain trailing option (Confirm).
    #
    # @commands holds [name, toggle] pairs until the window's own setter splits them, so both shapes are
    # accepted: whichever one is in place when the cursor lands, the state is the same value.
    def self.text(win, i)
      cmds = win.instance_variable_get(:@commands)
      keys = win.instance_variable_get(:@text_key)
      c = (cmds[i] rescue nil)
      name = c.is_a?(Array) ? c[0] : c
      tog  = c.is_a?(Array) ? c[1] : (keys[i] rescue nil)
      return (name.is_a?(String) ? name : nil) if tog.nil?
      state = (tog == 1) ? PokeAccess::I18n.t(:val_on) : PokeAccess::I18n.t(:val_off)
      name.is_a?(String) ? "#{name}, #{state}" : nil
    rescue StandardError
      nil
    end

    @win = nil

    def self.arm(win); @win = win; end

    # True while a rule list is on screen. The description strip is an ordinary Window_AdvancedTextPokemon,
    # the same class plain dialogue uses, so this is what keeps the listener below from reading dialogue
    # everywhere else. It clears itself: the screen disposes its windows on the way out.
    def self.open?
      w = @win
      !w.nil? && !(w.disposed? rescue true)
    rescue StandardError
      false
    end

    # The description of the focused rule, queued so it follows the name and state.
    def self.describe(win, raw)
      return unless open? && (PokeAccess::Config.read_help rescue true)
      txt = PokeAccess.clean(raw.to_s)
      return if txt.empty? || txt == PokeAccess.ivar(win, :@access_rule_desc)
      win.instance_variable_set(:@access_rule_desc, txt)
      PokeAccess::Info.set_info(:text, txt)
      PokeAccess.speak(txt, false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_CommandPokemon_Challenge") do |win, i|
  PokeAccess::ChallengeRules.text(win, i)
end

# Toggling rebuilds the option list through commands= without moving the cursor, so the generic reader's
# [index, pocket] key is unchanged and the new state would never be spoken. Clearing the slot makes the next
# update read the row again.
PokeAccess::Hooks.after_hook("Window_CommandPokemon_Challenge", :commands=, :optional => true) do |win, _r, _a|
  PokeAccess::Cursor.reset(win, :cmd_focus)
end

PokeAccess::Hooks.after_hook("Window_CommandPokemon_Challenge", :initialize, :optional => true) do |win, _r, _a|
  PokeAccess::ChallengeRules.arm(win)
end

PokeAccess::Hooks.after_hook("Window_AdvancedTextPokemon", :text=, :optional => true) do |win, _r, args|
  PokeAccess::ChallengeRules.describe(win, args[0])
end
