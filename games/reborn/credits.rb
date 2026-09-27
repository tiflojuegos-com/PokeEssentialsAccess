module PokeAccess
  # Reborn's credits (Scene_Credits) hold six rolls, CREDIT to CREDIT5, and its main paints the one variable 747 picks
  # (the ending sets it). Once Anna smiles, the lines tagged for Lin and Terra are dropped; unless she does, or switch
  # 1941 is on, so are those for Anna and Shade.
  module RebornCredits
    ROLLS = %w[CREDIT CREDIT1 CREDIT2 CREDIT3 CREDIT4 CREDIT5]

    # The raw lines of the roll that runs, filtered as main filters them; nil where the scene has no such rolls.
    def self.raw_lines(scene)
      return nil unless scene.class.const_defined?(:CREDIT5)
      name = ROLLS[($game_variables[747] rescue 0).to_i]
      text = name ? (scene.class.const_get(name) rescue nil) : nil
      return nil unless text.is_a?(String)
      lines = text.split(/\n/)
      anna = ($game_switches[:Anna_Smiles] rescue false) ? true : false
      lines = lines.reject { |l| l =~ /\A<[LT]>/ } if anna
      lines = lines.reject { |l| l =~ /\A<[AH]>/ } unless anna || ($game_switches[1941] rescue false)
      lines
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  override("PokeAccess::Credits", :raw_lines) do |_mod, original, args|
    PokeAccess::RebornCredits.raw_lines(args[0]) || original.call
  end
end
