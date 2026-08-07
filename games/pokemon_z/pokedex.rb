# Pokedex entry (AdvancedPokedexScene, script 205, custom). Its own module (not core's PokeAccess::Pokedex)
# so this game-specific reader never collides with the shared dex helper.
module PokeAccess
  module ZPokedex
    # Builds the text of the current dex page (info / level moves / egg moves / machine and tutor moves).
    #
    # The last group only exists when the game's own SHOWMACHINETUTORMOVES is on -- it is off in the build
    # surveyed, so @machineMovesPages is never even assigned and @totalPages stops after the egg moves. The
    # branch is here anyway because "everything after the level moves is egg moves" is only true while that
    # switch stays off: flip it and every machine page would be announced as "egg moves" with an empty
    # list under it, which is a wrong answer rather than a missing one.
    def self.page_text(scene)
      page  = scene.instance_variable_get(:@page)
      total = scene.instance_variable_get(:@totalPages)
      return nil unless page && total && total > 0
      infoP = scene.instance_variable_get(:@infoPages) || 0
      lvlP  = scene.instance_variable_get(:@levelMovesPages) || 0
      eggP  = scene.instance_variable_get(:@eggMovesPages) || 0
      out = ["Pagina #{page} de #{total}."]
      if page <= infoP
        info = scene.instance_variable_get(:@infoArray) || []
        (12 * (page - 1)...12 * page).each do |i|
          col = i / 6
          v = (info[col] ? info[col][i % 6] : nil)
          out.push(v.to_s) if v && !v.to_s.strip.empty?
        end
      elsif page <= infoP + lvlP
        out.push("Movimientos por nivel:")
        move_page(out, scene, :@levelMovesArray, page - infoP)
      elsif page <= infoP + lvlP + eggP
        out.push("Movimientos huevo:")
        move_page(out, scene, :@eggMovesArray, page - infoP - lvlP)
      else
        out.push("Movimientos por MT y tutor:")
        move_page(out, scene, :@machineMovesArray, page - infoP - lvlP - eggP)
      end
      out.join(" ")
    rescue StandardError
      nil
    end

    # One page of ten moves out of the named array, exactly as the screen paginates it.
    def self.move_page(out, scene, sym, page)
      arr = scene.instance_variable_get(sym) || []
      (10 * (page - 1)...10 * page).each { |i| out.push(arr[i].to_s) if arr[i] }
      out
    end
  end
end

PokeAccess::Game.define("pokemon_z") do
  # Entry open: name + types + first page (or a not-owned notice).
  after("AdvancedPokedexScene", :pbStartScene) do |scene, _r, _a|
    sp = scene.instance_variable_get(:@species)
    name = (PBSpecies.getName(sp) rescue "Pokemon")
    t1 = scene.instance_variable_get(:@type1)
    t2 = scene.instance_variable_get(:@type2)
    ty = PokeAccess::Util.types_phrase((PBTypes.getName(t1) rescue nil), (PBTypes.getName(t2) rescue nil))
    head = "#{name}."
    head += " Tipo #{ty}." unless ty.empty?
    body = PokeAccess::ZPokedex.page_text(scene)
    PokeAccess.speak(body ? "#{head} #{body}" : "#{head} Sin datos, no capturado.", true)
    scene.instance_variable_set(:@access_started, true)
  end

  # Page change (C/A): read the new page; the flag avoids doubling the startScene read.
  after("AdvancedPokedexScene", :displayPage) do |scene, _r, _a|
    if scene.instance_variable_get(:@access_started)
      t = PokeAccess::ZPokedex.page_text(scene)
      PokeAccess.speak(t, true) if t
    end
  end
end
