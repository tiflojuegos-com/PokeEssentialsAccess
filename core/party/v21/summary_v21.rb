module PokeAccess
  # Triggers for the classic modern summary scene (PokemonSummary_Scene, used by v21.1 and the Sky fork).
  # All spoken content is the agnostic SummaryGameData; this file only wires this scene's hooks and dedups.
  module SummaryV21
    # The class name does NOT tell the eras apart: a gen-6 fork can declare PokemonSummary_Scene as well
    # (Awakening's BES-T compatibility layer) with gen-6 internals, and this reader then bound to it and read
    # a gen-6 Pokemon through the GameData API -- name and level came out, types, ability, item and nature
    # did not. Gate on the data API this file is written against; "" binds nothing.
    SCENE = PokeAccess::Engine.era_scene(:gamedata, "PokemonSummary_Scene", "PokemonSummaryScene")
    # Speaks a page on arrival, deduped per scene instance: drawPage is also called on every ribbon cursor
    # move, which would otherwise repeat "Cintas: N" continuously. A page change yields different text, so
    # navigating pages still reads each one; a fresh scene (reopen) reads even the same page.
    def self.speak_page(scene, page)
      t = PokeAccess::SummaryGameData.page_text(scene, page)
      return if t.nil? || t.to_s.empty?
      return if t == PokeAccess.ivar(scene, :@access_page_text)
      scene.instance_variable_set(:@access_page_text, t)
      PokeAccess.speak(t, false)
    rescue StandardError
      nil
    end
  end
end

# Each summary page read on arrival (drawPage dispatches all pages), deduped so the ribbon page (redrawn
# per cursor move) does not repeat.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryV21::SCENE, :drawPage) do |scene, _r, args|
  PokeAccess::SummaryV21.speak_page(scene, args[0])
end

# Focused move detail while navigating the moves page (and while choosing one to replace).
PokeAccess::Hooks.after_hook(PokeAccess::SummaryV21::SCENE, :drawSelectedMove) do |scene, _r, args|
  pk = PokeAccess.ivar(scene, :@pokemon)
  PokeAccess.speak(PokeAccess::SummaryGameData.move_detail(pk, args[1]), true)
end

# Choosing which move to forget when learning a new one: list the current four.
PokeAccess::Hooks.before_hook(PokeAccess::SummaryV21::SCENE, :pbChooseMoveToForget) do |scene, _args|
  pk = PokeAccess.ivar(scene, :@pokemon)
  PokeAccess.speak("#{PokeAccess::I18n.t(:sm_choose_forget)}. #{PokeAccess::SummaryGameData.moves_text(pk)}", false)
end
