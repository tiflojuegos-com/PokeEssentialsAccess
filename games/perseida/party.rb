# Perseida's party screen (0145_PScreen_Party) always paints the mana bar with its figures, whatever the switch the pause
# menu asks: said from the party reading's medium as it opens and when it changes; and a Pokemon with its star power on is
# tinted, a mark among the row's full details. Its menu paints a star power (0257_Signos_Commandos, with its mana cost in
# brackets) in the blue of a field move, which core's reader takes it for.
module PokeAccess
  module PerseidaParty
    # A command of the party's menu that is a star power.
    POWER_ROW = /\(\d+\)\z/

    # A focused command's line, a star power's by what it is.
    def self.command(win, line)
      return line unless defined?(Window_CommandPokemonColor) && win.is_a?(Window_CommandPokemonColor)
      name = (PokeAccess.ivar(win, :@commands)[win.index] rescue nil).to_s
      name =~ POWER_ROW ? "#{name}, #{PokeAccess::I18n.t(:perseida_star_power)}" : line
    end

    # Says the mana when it differs from what this screen said last, queued.
    def self.mana(scene)
      PokeAccess::Cursor.announce(scene, :perseida_mana, [$game_variables[VARMANA], pbMaxMana], false) do
        line = PokeAccess::I18n.t(:perseida_mana, :n => $game_variables[VARMANA], :max => pbMaxMana)
        PokeAccess::Verbosity.line(:party, [[line, :medium]])
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("perseida") do
  override("PokeAccess::Menus", :focused_text) do |_mod, original, args|
    PokeAccess::PerseidaParty.command(args[0], original.call)
  end
  [:pbStartScene, :pbRefresh].each do |meth|
    after("PokemonScreen_Scene", meth, :optional => true, :hook_container => true) do |scene, _r, _a|
      PokeAccess::PerseidaParty.mana(scene)
    end
  end
  override("PokeAccess::Party", :panel_marks) do |_mod, original, args|
    (args[0].isBlessed? rescue false) ? original.call + [PokeAccess::I18n.t(:perseida_blessed)] : original.call
  end
end
