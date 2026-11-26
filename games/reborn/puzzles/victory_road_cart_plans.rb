# Victory Road's second mine plan with the puzzle assist (map 790, up to the cart that blows the wall, switch 1166): the
# step whose starting state stands now, or off the plan the lever whose flip brings the state back onto a step.
module PokeAccess
  module RebornVrCartPlans
    PLANS = {
      790 => {
        :done => 1166,
        :switches => [1157, 1159, 1160, 1161, 1162, 1163, 1164, 1165, 1166, 1167],
        :vars => [501, 502, 503, 504],
        :levers => { 1160 => 33, 1161 => 35, 1162 => 34, 1163 => 39 },
        :labels => { 44 => :rbg_plan_rocks },
        :steps => [
          [28, :cart, "S1157"],
          [31, :boulder, "S1157,V501=1", [28, 55]],
          [35, :use, "S1157,S1159,V501=1"],
          [39, :use, "S1157,S1159,S1161,V501=1"],
          [28, :cart, "S1157,S1159,S1161,S1163,V501=1"],
          [41, :cart, "S1157,S1159,S1161,S1163"],
          [42, :cart, "S1157,S1159,S1161,S1163,V503=1"],
          [44, :use, "S1157,S1159,S1161,S1163,V503=1,V504=1"],
          [42, :cart, "S1157,S1159,S1161,S1163,S1164,V503=1,V504=1"],
          [29, :cart, "S1157,S1159,S1161,S1163,S1164,V503=1"],
          [39, :use, "S1157,S1159,S1161,S1163,S1164,V502=1,V503=1"],
          [29, :cart, "S1157,S1159,S1161,S1164,V502=1,V503=1"],
          [42, :cart, "S1157,S1159,S1161,S1164,V503=1"],
          [29, :cart, "S1157,S1159,S1161,S1167,V503=1,V504=2"],
          [46, :use, "S1157,S1159,S1161,S1167,V502=1,V503=1,V504=2"],
          [42, :cart, "S1157,S1159,S1161,S1165,S1167,V502=1,V503=1,V504=2"],
          [35, :use, "S1157,S1159,S1161,S1165,S1167,V502=1,V503=1"],
          [29, :cart, "S1157,S1159,S1165,S1167,V502=1,V503=1"],
          [41, :cart, "S1157,S1159,S1165,S1167,V503=1"],
          [33, :use, "S1157,S1159,S1165,S1167"],
          [41, :cart, "S1157,S1159,S1160,S1165,S1167"],
          [34, :use, "S1157,S1159,S1160,S1165,S1167,V503=2"],
          [41, :cart, "S1157,S1159,S1160,S1162,S1165,S1167,V503=2"],
          [33, :use, "S1157,S1159,S1160,S1162,S1165,S1167"],
          [41, :cart, "S1157,S1159,S1162,S1165,S1167"],
          [42, :cart, "S1157,S1159,S1162,S1165,S1167,V503=1"]
        ]
      }
    }

    # The plan of the map the player is on, or nil.
    def self.plan
      $game_map && PLANS[$game_map.map_id]
    end

    # The state as the plan writes it: the switches on and the variables not at 0, in the plan's order.
    def self.signature(pl)
      on = pl[:switches].select { |s| $game_switches[s] }.map { |s| "S#{s}" }
      vals = pl[:vars].map { |v| n = $game_variables[v].to_i; n == 0 ? nil : "V#{v}=#{n}" }.compact
      on + vals
    end

    # The step to take now as [index, step], or nil off the plan or once the mine is done.
    def self.step
      pl = plan
      return nil unless pl && !$game_switches[pl[:done]]
      sig = signature(pl).join(",")
      i = pl[:steps].index { |s| s[2] == sig }
      i && [i, pl[:steps][i]]
    end

    # Off the plan: the lever whose flip brings the state back onto a step, or nil.
    def self.lever_back
      pl = plan
      return nil unless pl && !$game_switches[pl[:done]]
      cur = signature(pl)
      steps = pl[:steps].map { |s| s[2].split(",").sort }
      pl[:levers].each do |sw, id|
        flag = "S#{sw}"
        flipped = (cur.include?(flag) ? cur - [flag] : cur + [flag]).sort
        return id if steps.include?(flipped)
      end
      nil
    end

    # What to do next, as [kind, event, plate tile, index]: a step of the plan, or the lever that brings it back (:back).
    def self.target
      s = step
      return [s[1][1], s[1][0], s[1][3], s[0]] if s
      id = lever_back
      id && [:back, id, nil, nil]
    end

    # Where the next thing to do stands, as the event stands now.
    def self.next_at
      t = target
      return nil unless t
      ev = $game_map.events[t[1]]
      ev && [ev.x, ev.y]
    end

    # The next thing to do, in words.
    def self.next_label
      t = target
      return nil unless t
      i18n = PokeAccess::I18n
      pl = plan
      case t[0]
      when :cart
        ev = $game_map.events[t[1]]
        name = ev && PokeAccess::RebornVrMines.cart_label(ev)
        i18n.t(:rbg_plan_cart, :name => name || i18n.t(:rbc2_cart))
      when :boulder then boulder_label(t)
      when :back then i18n.t(:rbg_plan_back)
      else
        key = (pl[:labels] || {})[t[1]] || (pl[:levers].values.include?(t[1]) ? :rbg_plan_lever : :rbg_plan_use)
        i18n.t(key)
      end
    end

    # The boulder's step: how far it still goes to its plate, from where it stands.
    def self.boulder_label(t)
      ev = $game_map.events[t[1]]
      return nil unless ev
      i18n = PokeAccess::I18n
      where = PokeAccess::Locator.dir_phrase(t[2][0] - ev.x, t[2][1] - ev.y)
      i18n.t(:rbg_plan_boulder, :where => where)
    end

    # The info key's line with the assist: the step's number and what it is, and where from the player.
    def self.info_line
      return nil unless PokeAccess::Puzzles.assist?
      t = target
      at = next_at
      return nil unless t && at
      where = PokeAccess::Locator.dir_phrase(at[0] - $game_player.x, at[1] - $game_player.y)
      what = next_label
      return PokeAccess::I18n.t(:rbg_plan_off, :what => what, :where => where) unless t[3]
      PokeAccess::I18n.t(:rbg_plan_step, :n => t[3] + 1, :total => plan[:steps].length, :what => what, :where => where)
    end
  end
end

PokeAccess::Game.define("reborn") do
  plans = PokeAccess::RebornVrCartPlans
  plans::PLANS.each do |map, pl|
    mechanic(:state, map, :part => :cart_plan) do
      auto
      spot :at => lambda { plans.next_at }, :label => lambda { plans.next_label }, :assist => true
      info { plans.info_line }
      active { PokeAccess::Puzzles.assist? && !plans.target.nil? }
      hint :rbg_plan_hint
      solved(nil, :quiet => true) { $game_switches[pl[:done]] }
    end
  end
end
