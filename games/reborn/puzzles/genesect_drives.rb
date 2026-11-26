# Neo Blacksteam Fabrication (map 877), Genesect quest (variable 637, 10 to 28): each drive in its receptor (switches
# 1738 to 1741) opens some doors and shuts others, the console at (31, 72) turns the shutters between modes A and B
# (1729), and the iso-shutter locks open doors for good (1730 to 1737). The assist follows a plan kept as data.
module PokeAccess
  module RebornGenesect
    MAP = 877
    QUEST = 637
    DONE = 28
    SWITCHES = (1729..1742).to_a
    CONSOLE = 82
    SHUTTERS = 1729
    RECEPTORS = { 135 => [1738, :rbrd_gen_shock], 152 => [1739, :rbrd_gen_chill], 160 => [1740, :rbrd_gen_burn],
                  161 => [1741, :rbrd_gen_douse] }
    LOCKS = { 88 => 1730, 93 => 1731, 98 => 1732, 103 => 1733, 108 => 1734, 113 => 1736, 118 => 1735, 123 => 1737 }
    GENERATORS = { 164 => [1742, :rbrd_gen_combustion], 204 => [1743, :rbrd_gen_hydro], 208 => [1745, :rbrd_gen_cooling],
                   212 => [1747, :rbrd_gen_steam] }
    FLOORS = [4, 5, 129, 130, 153, 154, 170, 171, 175, 176, 196, 197]
    TALKS = { 10 => :rbrd_gen_aya, 33 => :rbrd_gen_aya, 201 => :rbrd_gen_genesect }
    # The quest's plan; the combustion generator (1742) wants Shock and Burn in at once.
    STEPS = [
      [4, :step, "V637=10"],
      [10, :use, "V637=12"],
      [33, :use, "S1729,V637=13"],
      [88, :use, "S1729,V637=15"],
      [129, :step, "S1729,S1730,V637=15"],
      [135, :use, "S1729,S1730,V637=17"],
      [118, :use, "S1729,S1730,S1738,V637=17"],
      [135, :use, "S1729,S1730,S1735,S1738,V637=17"],
      [113, :use, "S1729,S1730,S1735,V637=17"],
      [82, :use, "S1729,S1730,S1735,S1736,V637=17"],
      [153, :step, "S1730,S1735,S1736,V637=17"],
      [82, :use, "S1730,S1735,S1736,V637=19"],
      [135, :use, "S1729,S1730,S1735,S1736,V637=19"],
      [152, :use, "S1729,S1730,S1735,S1736,S1738,V637=19"],
      [93, :use, "S1729,S1730,S1735,S1736,S1738,S1739,V637=19"],
      [170, :step, "S1729,S1730,S1731,S1735,S1736,S1738,S1739,V637=19"],
      [123, :use, "S1729,S1730,S1731,S1735,S1736,S1738,S1739,V637=21"],
      [82, :use, "S1729,S1730,S1731,S1735,S1736,S1737,S1738,S1739,V637=21"],
      [135, :use, "S1730,S1731,S1735,S1736,S1737,S1738,S1739,V637=21"],
      [175, :step, "S1730,S1731,S1735,S1736,S1737,S1739,V637=21"],
      [82, :use, "S1730,S1731,S1735,S1736,S1737,S1739,V637=23"],
      [160, :use, "S1729,S1730,S1731,S1735,S1736,S1737,S1739,V637=23"],
      [108, :use, "S1729,S1730,S1731,S1735,S1736,S1737,S1739,S1740,V637=23"],
      [82, :use, "S1729,S1730,S1731,S1734,S1735,S1736,S1737,S1739,S1740,V637=23"],
      [98, :use, "S1730,S1731,S1734,S1735,S1736,S1737,S1739,S1740,V637=23"],
      [82, :use, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1740,V637=23"],
      [135, :use, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1740,V637=23"],
      [164, :use, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1738,S1739,S1740,V637=23"],
      [82, :use, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1738,S1739,S1740,S1742,V637=23"],
      [135, :use, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1738,S1739,S1740,S1742,V637=23"],
      [196, :step, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1740,S1742,V637=23"],
      [160, :use, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1740,S1742,V637=27"],
      [161, :use, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1742,V637=27"],
      [201, :use, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1741,S1742,V637=27"]
    ]
    CELLS = { 206 => 1744, 209 => 1746, 213 => 1748 }
    EXTRA_SWITCHES = (1729..1748).to_a
    # The plan once Genesect is met: three extra generators each want their own drives in (hydro Shock and Douse,
    # supercooling Chill and Douse with Burn out, steam Burn and Douse with Chill out) to open a Zygarde Cell machine
    # (1744, 1746, 1748).
    EXTRAS = [
      [135, :use, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1741,S1742"],
      [204, :use, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1738,S1739,S1741,S1742"],
      [82, :use, "S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1738,S1739,S1741,S1742,S1743"],
      [135, :use, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1738,S1739,S1741,S1742,S1743"],
      [208, :use, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1741,S1742,S1743"],
      [206, :here, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1741,S1742,S1743,S1745"],
      [152, :use, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1739,S1741,S1742,S1743,S1744,S1745"],
      [160, :use, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1741,S1742,S1743,S1744,S1745"],
      [103, :use, "S1729,S1730,S1731,S1732,S1734,S1735,S1736,S1737,S1740,S1741,S1742,S1743,S1744,S1745"],
      [82, :use, "S1729,S1730,S1731,S1732,S1733,S1734,S1735,S1736,S1737,S1740,S1741,S1742,S1743,S1744,S1745"],
      [212, :use, "S1730,S1731,S1732,S1733,S1734,S1735,S1736,S1737,S1740,S1741,S1742,S1743,S1744,S1745"],
      [209, :here, "S1730,S1731,S1732,S1733,S1734,S1735,S1736,S1737,S1740,S1741,S1742,S1743,S1744,S1745,S1747"],
      [213, :here, "S1730,S1731,S1732,S1733,S1734,S1735,S1736,S1737,S1740,S1741,S1742,S1743,S1744,S1745,S1746,S1747"]
    ]
    TOGGLES = { SHUTTERS => CONSOLE, 1738 => 135, 1739 => 152, 1740 => 160, 1741 => 161 }

    # The state as the plan writes it: the switches on, then the quest's count until Genesect is met; after it the story
    # keeps raising the count (to 32, Map596 and this map's EV202), and EXTRAS holds for any of them.
    def self.signature(switches = SWITCHES)
      on = switches.select { |s| $game_switches[s] }.map { |s| "S#{s}" }
      n = $game_variables[QUEST].to_i
      (on + (n == 0 || n >= DONE ? [] : ["V#{QUEST}=#{n}"])).join(",")
    end

    # True once Genesect has been met.
    def self.done?
      $game_variables[QUEST].to_i >= DONE
    end

    # True once the three Zygarde Cells are taken.
    def self.cells_done?
      CELLS.values.all? { |s| $game_switches[s] }
    end

    # The plan in force and the switches its states are written with: the quest's, then the extra generators'.
    def self.plan
      done? ? [EXTRAS, EXTRA_SWITCHES] : [STEPS, SWITCHES]
    end

    # The step to take now, or nil off the plan.
    def self.step
      return nil if done? && cells_done?
      steps, switches = plan
      sig = signature(switches)
      steps.find { |s| s[2] == sig }
    end

    # Off the plan: the console or receptor whose flip brings the state back onto a step, or nil.
    def self.back
      return nil if done? && cells_done?
      list, switches = plan
      cur = signature(switches).split(",")
      steps = list.map { |s| s[2].split(",").sort }
      TOGGLES.each do |sw, id|
        flag = "S#{sw}"
        flipped = (cur.include?(flag) ? cur - [flag] : cur + [flag]).sort
        return id if steps.include?(flipped)
      end
      nil
    end

    # What to do next as [event, kind, off the plan?], or nil.
    def self.target
      s = step
      return [s[0], s[1], false] if s
      id = back
      id && [id, :use, true]
    end

    # The id of the event to go to next, with the assist.
    def self.next_id
      t = PokeAccess::Puzzles.assist? && target
      t ? t[0] : nil
    end

    # Where the next tile to stand on lies, while the plan wants one of that kind: a floor to walk onto (:step) or a
    # cell machine to use from on top (:here).
    def self.floor_at(kind = :step)
      t = target
      return nil unless t && t[1] == kind
      ev = $game_map.events[t[0]]
      ev && [ev.x, ev.y]
    end

    # A Zygarde Cell machine's name, opened or not.
    def self.cell_label(id)
      $game_switches[CELLS[id]] ? :rbrj_gen_cell_open : :rbrj_gen_cell
    end

    # The console's name, with the mode it stands in.
    def self.console_label
      [:rbrd_gen_console, { :mode => PokeAccess::I18n.t($game_switches[SHUTTERS] ? :rbrd_gen_mode_b : :rbrd_gen_mode_a) }]
    end

    # A receptor's name, with its drive and whether it is in.
    def self.receptor_label(id)
      sw, drive = RECEPTORS[id]
      state = $game_switches[sw] ? :rbrd_gen_active : :rbrd_gen_inactive
      [:rbrd_gen_receptor, { :drive => PokeAccess::I18n.t(drive), :state => PokeAccess::I18n.t(state) }]
    end

    # An iso-shutter lock's name, opened or not.
    def self.lock_label(id)
      $game_switches[LOCKS[id]] ? :rbrd_gen_lock_open : :rbrd_gen_lock
    end

    # The name of a console, receptor, lock or generator, said as the next to use with the assist.
    def self.label(ev)
      base = if ev.id == CONSOLE then console_label
             elsif RECEPTORS[ev.id] then receptor_label(ev.id)
             elsif LOCKS[ev.id] then lock_label(ev.id)
             elsif CELLS[ev.id] then cell_label(ev.id)
             else GENERATORS[ev.id][1]
             end
      return base unless next_id == ev.id
      [:rbrd_gen_next, { :what => PokeAccess::I18n.t(*Array(base)) }]
    end

    # The hint for the next thing to do.
    def self.hint
      t = target
      return nil unless t
      i18n = PokeAccess::I18n
      id, kind, off = t
      line = if kind == :step then :rbrd_gen_floor
             elsif kind == :here then :rbrj_gen_hint_cell
             elsif TALKS[id] then TALKS[id]
             elsif id == CONSOLE
               [:rbrd_gen_hint_console, { :mode => i18n.t($game_switches[SHUTTERS] ? :rbrd_gen_mode_a : :rbrd_gen_mode_b) }]
             elsif RECEPTORS[id]
               sw, drive = RECEPTORS[id]
               [$game_switches[sw] ? :rbrd_gen_hint_remove : :rbrd_gen_hint_insert, { :drive => i18n.t(drive) }]
             elsif LOCKS[id] then :rbrd_gen_hint_lock
             else [:rbrd_gen_hint_generator, { :what => i18n.t(GENERATORS[id][1]) }]
             end
      return line unless off
      [:rbrd_gen_hint_back, { :what => i18n.t(*Array(line)) }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  gen = PokeAccess::RebornGenesect
  mechanic(:state, gen::MAP, :part => :drives) do
    auto
    name [gen::CONSOLE] + gen::RECEPTORS.keys + gen::LOCKS.keys + gen::GENERATORS.keys + gen::CELLS.keys,
         lambda { |ev| gen.label(ev) }
    avoid gen::FLOORS, :assist => true
    spot :at => lambda { gen.floor_at }, :label => :rbrd_gen_floor_spot, :assist => true, :onto => true,
         :when => lambda { !gen.floor_at.nil? }
    spot :at => lambda { gen.floor_at(:here) }, :label => :rbrj_gen_cell_spot, :assist => true, :onto => true,
         :when => lambda { !gen.floor_at(:here).nil? }
    hint lambda { gen.hint }
    info { nil }
    active { PokeAccess::Puzzles.assist? && !gen.hint.nil? }
    solved(nil, :quiet => true) { gen.done? && gen.cells_done? }
  end
end
