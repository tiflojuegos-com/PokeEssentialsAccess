# Perseida's copy of the gachapon (0202_Gacha_Scene, read by magic_gachapon) spends the Gatibox tokens of the bag, not the
# coins of the script's base; its banners show battlers and item icons by number, and their descriptions write a prize's
# tier as a row of asterisks around it.
module PokeAccess
  module PerseidaGacha
    # The token the scene counts and spends.
    TOKEN = :FICHAGATIBOX

    # The count painted beside the banner, by the token's name.
    def self.tokens
      name = (PokeAccess::Data.item_id(TOKEN) || [])[1]
      PokeAccess::I18n.t(:perseida_gacha_tokens, :name => name, :n => $PokemonBag.pbQuantity(TOKEN).to_i)
    end

    # What a reward picture shows: Graphics/Icons/itemNNN an item, Graphics/Battlers/Front/NNN a species and FrontShiny
    # its shiny, the _N of a form left out as it has no name of its own; nil for any other picture.
    def self.reward_name(path)
      file = path.to_s.split("/").last.to_s
      return PokeAccess::Data.item_name($1.to_i) if file =~ /\Aitem(\d+)\z/
      return nil unless file =~ /\A(\d+)/
      name = PokeAccess::Data.species_name($1.to_i)
      path.to_s.include?("FrontShiny") ? "#{name}, #{PokeAccess::I18n.t(:pk_shiny)}" : name
    end

    # A banner's description with each "***** prize *****" said as the prize and its stars.
    def self.description(text)
      text.to_s.gsub(/(\*+)\s*([^*\n]+?)\s*\*+/) { "#{PokeAccess::I18n.t(:gacha_prize, :name => $2, :n => $1.length)}." }
    end
  end
end

PokeAccess::Game.define("perseida") do
  override("PokeAccess::MagicGachapon", :counters) { |_mod, _original, _args| [PokeAccess::PerseidaGacha.tokens] }
  override("PokeAccess::MagicGachapon", :reward_name) do |_mod, _original, args|
    PokeAccess::PerseidaGacha.reward_name(args[0])
  end
  override("PokeAccess::MagicGachapon", :description) do |_mod, _original, args|
    PokeAccess::PerseidaGacha.description(args[0])
  end
end
