# Royal's Currydex (Window_Currydex, [number, name] entries the generic reader skips): the recipe or "unknown", the
# medal painted beside its best score from medium and the score in full; the recipe count on opening. The info key
# adds the description.
module PokeAccess
  module RoyalCurrydex
    # The medal sprite (Curry/Currydex/puntuacion_N) for each rank rangoPuntuacionCurry gives, by its colour and the
    # stars on it: the ranks the result screen names Koffing, Wobbuffet, Milcery, Copperajah and Charizard.
    MEDALS = [:rcy_medal_1, :rcy_medal_2, :rcy_medal_3, :rcy_medal_4, :rcy_medal_5]

    # The medal a rank paints, or nil for a rank with no sprite.
    def self.medal(rank)
      key = (rank.to_i >= 1) ? MEDALS[rank.to_i - 1] : nil
      key ? PokeAccess::I18n.t(key) : nil
    end
  end
end

PokeAccess::Game.define("royal") do
  screen_reader("Window_Currydex") do |win, i|
    cmds = win.instance_variable_get(:@commands)
    next nil unless cmds.is_a?(Array) && cmds[i]
    id = cmds[i][0]
    num = id.to_i + 1
    unless (pbCurryRegistered?(id) rescue false)
      unknown = PokeAccess::I18n.t(:dexlist_unknown, :num => num)
      PokeAccess::Info.set_info(:text, unknown)
      next unknown
    end
    parts = [[PokeAccess::I18n.t(:dexlist_entry, :num => num, :name => cmds[i][1]), :brief]]
    best = ($PokemonGlobal.curry_mejor_puntuacion[id] rescue nil)
    if best.is_a?(Integer) && best > -1
      parts.push([PokeAccess::I18n.t(:rcy_best, :n => best), :full])
      medal = PokeAccess::RoyalCurrydex.medal((rangoPuntuacionCurry(best) rescue -1))
      parts.push([medal, :medium]) if medal
    end
    whole = PokeAccess::Verbosity.full_line(parts)
    desc = (ResultadosCurry::LISTADO_CURRYS[id][2] rescue nil)
    PokeAccess::Info.set_info(:text, PokeAccess.sentences([whole, PokeAccess.clean(desc.to_s)]), whole)
    PokeAccess::Verbosity.line(:dex_entry, parts)
  end

  after("PokemonCurrydex_Scene", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }

  after("PokemonCurrydex_Scene", :pbStartScene, :optional => true) do |_s, _r, _a|
    total = (ResultadosCurry::LISTADO_CURRYS.length rescue nil)
    found = (pbCurryDexCount rescue nil)
    PokeAccess.speak(PokeAccess::I18n.t(:rcy_recipes, :n => found, :tot => total), false) if found && total
  end
end
