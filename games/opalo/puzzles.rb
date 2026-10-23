# Opalo's gyms. Map 46: two machines and two levers (175, 177); a machine sets 174, or 178 once 174 is on, and nothing
# turns them off. Map 36, the psychic gym: a sensor lights the safe path for a step, switch 313 on the way to the
# leader and 314 north. Neither has a win: the leaders' doors have no condition.
module PokeAccess
  # Each machine of map 46 is three events in a row under one 3x3 graphic, the same page in each, which also sets
  # the machine's own switch (243 west, 244 east), the one its empty second page waits for: they go out of use
  # together, so the locator lists the machine once.
  module OpaloMachines
    # The puzzles' targets with the touching controls of one name merged into the middle one, the rest as they come.
    def self.merged(targets)
      ctrls, rest = targets.partition { |t| t.is_a?(PokeAccess::Locator::SurfaceTarget) && t.key == :puzzle_control }
      groups = PokeAccess::Util.union_groups(ctrls.length) { |i, j| touching?(ctrls[i], ctrls[j]) }
      groups.sort_by { |idxs| idxs.min }.map { |idxs| middle(idxs.map { |i| ctrls[i] }) } + rest
    end

    # Whether two control targets touch, diagonals too, and go by the same name.
    def self.touching?(a, b)
      (a.x - b.x).abs <= 1 && (a.y - b.y).abs <= 1 && a.name == b.name
    end

    # The middle target of a group in reading order.
    def self.middle(group)
      row = group.sort_by { |t| [t.y, t.x] }
      row[row.length / 2]
    end
  end
end

PokeAccess::Game.define("opalo") do
  mechanic(:state, 46) do
    watch :switch => 174, :label => :op_machine,  :on => :op_on, :off => :op_off
    watch :switch => 178, :label => :op_machine2, :on => :op_on, :off => :op_off
    watch :switch => 175, :label => :op_lever1,   :on => :op_on, :off => :op_off
    watch :switch => 177, :label => :op_lever2,   :on => :op_on, :off => :op_off
    controls
  end

  mechanic(:state, 36) do
    watch :switch => 313, :label => :op_lights,       :on => :op_lights_on, :off => :op_lights_off
    watch :switch => 314, :label => :op_lights_north, :on => :op_lights_on, :off => :op_lights_off
    arrival_hint :op_traps_hint
  end

  override("PokeAccess::Puzzles", :control_targets) do |_m, original, _a|
    PokeAccess::OpaloMachines.merged(original.call)
  end
end
