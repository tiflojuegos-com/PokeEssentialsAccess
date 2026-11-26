# Amontillado Factory F2 (map 112, Case Thirteen): the Swinub Tiramisu (five events) is launched from the two seesaws
# (events 5, 13), lowering the red spikes (events 3, 11) and the blue ones (event 15) on the way to the roof (event 17).
# The green switch (event 10) lowers spikes no way needs. The jump tile (3, 9, event 6) is hidden: assist only.
module PokeAccess
  module AshenFactory
    MAP = 112
    TIRAMISU = [2, 4, 7, 12, 16]
    SPIKES = { 3 => :afc_factory_red_spikes, 11 => :afc_factory_red_spikes, 9 => :afc_factory_green_spikes,
               15 => :afc_factory_blue_spikes }
    JUMP = [3, 9]
    CASE_VAR = 175

    # Whether a self switch of an event of this map is on.
    def self.on?(id, letter)
      $game_self_switches[[MAP, id, letter]] ? true : false
    end

    # A spikes event's name: its colour, lowered once its self switch A is on.
    def self.spikes_label(ev)
      key = SPIKES[ev.id]
      on?(ev.id, "A") ? [:afc_factory_lowered, { :spikes => PokeAccess::I18n.t(key) }] : key
    end

    # Whether the floor is still to cross: the way to the roof not yet taken.
    def self.open?
      $game_variables[CASE_VAR].to_i < 2
    end

    # The step due now, from what the game has done so far.
    def self.step
      return :talk unless on?(2, "A")
      return :jump unless on?(6, "A")
      return :red unless on?(8, "B")
      return :sparkle unless on?(14, "A")
      :roof
    end

    # Whether the assist is on and a step is due.
    def self.due?(name)
      PokeAccess::Puzzles.assist? && open? && step == name
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  factory = PokeAccess::AshenFactory
  mechanic(:state, factory::MAP, :part => :tiramisu) do
    name factory::TIRAMISU, :afc_factory_tiramisu
    name [5, 13], :afc_factory_seesaw
    name 14, :afc_factory_sparkle, :when => lambda { |_ev| !PokeAccess::AshenFactory.on?(14, "A") }
    name 8, :afc_factory_red_switch
    name 10, :afc_factory_green_switch
    name factory::SPIKES.keys, lambda { |ev| PokeAccess::AshenFactory.spikes_label(ev) }
    watch :self => [11, "A"], :say => :afc_factory_red_down
    watch :self => [9, "A"], :say => :afc_factory_green_down
    watch :self => [15, "A"], :say => :afc_factory_blue_down
    phase lambda { PokeAccess::AshenFactory.due?(:talk) }, :hint => :afc_factory_hint_talk
    phase lambda { PokeAccess::AshenFactory.due?(:jump) }, :hint => :afc_factory_hint_jump,
          :spots => [{ :at => factory::JUMP, :label => :afc_factory_jump, :onto => true }]
    phase lambda { PokeAccess::AshenFactory.due?(:red) }, :hint => :afc_factory_hint_red
    phase lambda { PokeAccess::AshenFactory.due?(:sparkle) }, :hint => :afc_factory_hint_sparkle
    phase lambda { PokeAccess::AshenFactory.due?(:roof) }, :hint => :afc_factory_hint_roof
    solved(nil, :quiet => true) { !PokeAccess::AshenFactory.open? }
  end
end
