module PokeAccess
  # Hooks for the modern PokemonSummary_Scene (v21.1 and the Sky fork); the text comes from SummaryGameData.
  module SummaryV21
    # The scene to hook, gated on the GameData API since a gen-6 fork may declare PokemonSummary_Scene too; ""
    # binds nothing.
    SCENE = PokeAccess::Engine.era_scene(:gamedata, "PokemonSummary_Scene", "PokemonSummaryScene")
    # Speaks the page drawn, or the egg page for an egg, through Summary.speak_page.
    def self.speak_page(scene, page)
      pk = PokeAccess.ivar(scene, :@pokemon)
      pairs = PokeAccess::PaintCapture.take_pairs(:summary_egg)
      PokeAccess::Summary.say_egg_page(scene, pk, pairs)
      return if PokeAccess::Summary.egg?(pk)
      memo = pairs.select { |r| r[1] == :formatted }.map { |r| r[0] }
      t = PokeAccess::SummaryGameData.page_text(scene, page, memo, pairs.map { |r| r[0] }, pairs)
      t = PokeAccess::Summary.with_hints(t, PokeAccess::PaintCapture.lines(pairs))
      pid = PokeAccess.ivar(scene, :@page_id)
      named = pid.nil? ? page == 1 : pid == :page_info
      PokeAccess::Summary.speak_page(scene, pk, pid || page, t, named)
    rescue StandardError
      nil
    end

    # Speaks the focused move's detail and points the info key at it; a profile whose summary has another face for
    # the moves page (a contest page) overrides it.
    def self.speak_move(scene, move)
      pk = PokeAccess.ivar(scene, :@pokemon)
      PokeAccess::Info.set_info(:move, move) if move
      PokeAccess.speak(PokeAccess::SummaryGameData.move_detail(pk, move), true)
    end
  end
end

# Each page on arrival (drawPage dispatches them all). A container, since a page can run a whole screen inside
# its draw (Infinite Fusion's Pokedex entry), whose readers a guard would drop as nested.
PokeAccess::Hooks.after_hook(PokeAccess::SummaryV21::SCENE, :drawPage, :hook_container => true) do |scene, _r, args|
  PokeAccess::SummaryV21.speak_page(scene, args[0])
end

# The move reorder and the ribbon cursor, polled from pbUpdate as in gen-6; the tracking is reset on opening.
PokeAccess::Hooks.before_hook(PokeAccess::SummaryV21::SCENE, :pbStartScene) do |_s, _a|
  PokeAccess::Summary.reset_reorder
end
PokeAccess::Hooks.after_hook(PokeAccess::SummaryV21::SCENE, :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::Summary.reorder_poll(scene)
  PokeAccess::Summary.ribbon_poll(scene)
end

# Focused move detail while navigating the moves page (and while choosing one to replace).
PokeAccess::Hooks.after_hook(PokeAccess::SummaryV21::SCENE, :drawSelectedMove) do |scene, _r, args|
  PokeAccess::SummaryV21.speak_move(scene, args[1])
end

# Learning a move with a full moveset: the new move (drawn as a fifth row) and the current four, queued.
PokeAccess::Hooks.before_hook(PokeAccess::SummaryV21::SCENE, :pbChooseMoveToForget) do |scene, args|
  pk = PokeAccess.ivar(scene, :@pokemon)
  learn = args[0] ? PokeAccess::Data.move_name(args[0]) : nil
  lead = (learn && !learn.to_s.empty?) ? "#{PokeAccess::I18n.t(:sm_learn, :move => learn)}. " : ""
  PokeAccess.speak("#{lead}#{PokeAccess::I18n.t(:sm_choose_forget)}. #{PokeAccess::SummaryGameData.moves_text(pk)}", false)
end
