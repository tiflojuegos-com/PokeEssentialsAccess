# bo4p5687's Racecourse (RaceGame, pbRaceGame; Ashen Frost): every menu is a picture with a cursor, a step of @process: play or
# quit, the Pokemon that runs, the wager, the lane to bet on, the race and whether to go again. The verdict is a message.
module PokeAccess
  module Racecourse
    STEPS = { 0 => :rc_menu, 1 => :rc_pick_runner, 2 => :rc_pick_wager, 3 => :rc_pick_lane, 7 => :rc_continue }

    # What the cursor is on at a step, as a key that changes when it moves and the row's words; nil on the first step until
    # its picture is up, as a game with no Coin Case only says so.
    def self.row(scene, step)
      case step
      when 0
        return nil unless PokeAccess.sprite(scene, "Play")
        play = PokeAccess.ivar(scene, :@select)
        [play, PokeAccess::I18n.t(play ? :rc_play : :rc_quit)]
      when 1
        i = PokeAccess.ivar_i(scene, :@selecttwo)
        [i, PokeAccess::Data.species_name(::CANDIDAT[i].to_sym).to_s]
      when 2
        i = PokeAccess.ivar_i(scene, :@selectcoin)
        open = PokeAccess.ivar(scene, :@check) == false
        wager = PokeAccess::I18n.t(:vp_wager, :n => ::COIN_RACEGAME.values[i])
        [[i, open], open ? PokeAccess.sentences([coins, wager].compact) : wager]
      when 3
        i = PokeAccess.ivar_i(scene, :@choose)
        [i, PokeAccess::I18n.t(:rc_lane, :n => i + 1)]
      when 7
        again = PokeAccess.ivar(scene, :@continue)
        [again, PokeAccess::I18n.t(again ? :rc_yes : :rc_no)]
      end
    end

    # The coins the player holds, in words; nil where the game keeps none.
    def self.coins
      held = PokeAccess::Minigames.held_coins
      held ? PokeAccess::I18n.t(:mg_coins, :n => held) : nil
    end

    # The wager step's two other keys: the action button opens and closes the box of coins, and back leaves only with it open.
    def self.wager_keys
      PokeAccess::I18n.t(:rc_wager_keys, :a => PokeAccess::KeyHints.key(:a, "Z"), :b => PokeAccess::KeyHints.key(:b, "X"))
    end

    # The step's words: its row, led by the step's title when the cursor has just arrived there, and its keys at the wager.
    def self.line(scene, step, text)
      return text unless PokeAccess::Cursor.changed?(scene, :rc_step, step)
      parts = [PokeAccess::I18n.t(STEPS[step])]
      parts.push(coins) if step == 2
      parts.push(text)
      parts.push(wager_keys) if step == 2 && PokeAccess::Verbosity.hints?
      PokeAccess.sentences(parts.compact)
    end

    # The info key's line at a step: its title and row, with the coins where wagers are made; the race's own words otherwise.
    # Parked (Minigames.publish), as the game's waits and messages run over the map, whose frames take the key back.
    def self.publish(scene, step, text)
      parts = STEPS[step] ? [PokeAccess::I18n.t(STEPS[step]), step == 2 ? coins : nil, text] : [text]
      PokeAccess::Minigames.publish(scene, PokeAccess.sentences(parts.compact))
    end

    # What the race itself lets be said: that it is on, and the lane that won, which only its number shows.
    def self.outcome(scene, step)
      return [:racing, PokeAccess::I18n.t(:rc_running)] if step == 4
      return nil unless step == 6
      win = PokeAccess.ivar(scene, :@win)
      [:won, win ? PokeAccess::I18n.t(:rc_winner, :n => win + 1) : PokeAccess::I18n.t(:rc_tie)]
    end
  end
end

PokeAccess::Racecourse::READER = PokeAccess::SceneWatcher.reader("RaceGame", :pbStart, :racecourse, :optional => true) do |scene|
  step = PokeAccess.ivar_i(scene, :@process)
  found = PokeAccess::Racecourse::STEPS[step] ? PokeAccess::Racecourse.row(scene, step) : PokeAccess::Racecourse.outcome(scene, step)
  next nil unless found
  text = found[1]
  said = lambda do
    PokeAccess::Racecourse.publish(scene, step, text)
    PokeAccess::Racecourse::STEPS[step] ? PokeAccess::Racecourse.line(scene, step, text) : text
  end
  [[step, found[0]], said]
end
PokeAccess::Hooks.before_hook("RaceGame", :pbEndScene, :optional => true) { |_scene, _args| PokeAccess::Minigames.unpublish }
