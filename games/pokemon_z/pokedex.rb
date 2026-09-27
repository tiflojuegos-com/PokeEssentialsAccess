# Pokemon Z's Pokedex entry (AdvancedPokedexScene, the game's own screen).
module PokeAccess
  module ZPokedex
    # The text of the current dex page: info, level moves, egg moves, or machine and tutor moves (pages past the
    # egg moves, which exist only with the game's SHOWMACHINETUTORMOVES on).
    def self.page_text(scene)
      page  = scene.instance_variable_get(:@page)
      total = scene.instance_variable_get(:@totalPages)
      return nil unless page && total && total > 0
      infoP = scene.instance_variable_get(:@infoPages) || 0
      lvlP  = scene.instance_variable_get(:@levelMovesPages) || 0
      eggP  = scene.instance_variable_get(:@eggMovesPages) || 0
      out = []
      out.push("#{PokeAccess::I18n.t(:adv_dex_page, :n => page, :m => total)}.") if PokeAccess::Verbosity.keep?(:positions, :medium)
      if page <= infoP
        info = scene.instance_variable_get(:@infoArray) || []
        (12 * (page - 1)...12 * page).each do |i|
          col = i / 6
          v = (info[col] ? info[col][i % 6] : nil)
          out.push(v.to_s) if v && !v.to_s.strip.empty?
        end
      elsif page <= infoP + lvlP
        out.push(painted("MOVIMIENTOS POR NIVEL:"))
        move_page(out, scene, :@levelMovesArray, page - infoP)
      elsif page <= infoP + lvlP + eggP
        out.push(painted("MOVIMIENTOS HUEVO:"))
        move_page(out, scene, :@eggMovesArray, page - infoP - lvlP)
      else
        out.push(painted("MOVIMIENTOS POR MT Y MO:"))
        move_page(out, scene, :@machineMovesArray, page - infoP - lvlP - eggP)
      end
      out.join(" ")
    rescue StandardError
      nil
    end

    # A page title as the game paints it (displayPage's own _INTL strings), in the running build's language.
    def self.painted(title)
      PokeAccess.clean((_INTL(title) rescue title).to_s)
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
    name = (PBSpecies.getName(sp) rescue nil)
    t1 = scene.instance_variable_get(:@type1)
    t2 = scene.instance_variable_get(:@type2)
    ty = PokeAccess::Util.types_phrase((PBTypes.getName(t1) rescue nil), (PBTypes.getName(t2) rescue nil))
    head = name ? "#{name}." : ""
    head += " #{PokeAccess::I18n.t(:pdx_type, :t => ty)}." unless ty.empty?
    body = PokeAccess::ZPokedex.page_text(scene) || "#{PokeAccess::I18n.t(:pdx_not_caught)}."
    PokeAccess.speak("#{head} #{body}", true)
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
