# Base Ranger 01 (maps 46 and 47): five tests of type weaknesses, switches 154 to 158 in turn. Each shows a type icon
# (a tile on map 46, a botontipo sheet frame on map 47) and two or three floor tiles painted with types; the one whose
# type is super effective against the icon's opens the next barrier, and any other sends the player back to the
# entrance of map 46 (16, 22). The types were read off the tileset and the sheets. On map 47 a green teleport pad
# painted on the floor (41, 27, event 33 with no sprite), like the one the entrance lands on, sends there too.
module PokeAccess
  module RevivalRanger
    ENTRANCE = [16, 22]
    # Map => [[stage switch, icon event, icon type, right tile, its type, { wrong tile => its type }], ...].
    STAGES = {
      46 => [[154, 4, :GRASS, 1, :FIRE, { 2 => :WATER, 3 => :GRASS }]],
      47 => [[155, 2, :NORMAL, 11, :FIGHTING, { 10 => :DRAGON, 56 => :ELECTRIC }],
             [156, 12, :FAIRY, 6, :POISON, { 17 => :PSYCHIC, 18 => :ROCK }],
             [157, 29, :GROUND, 19, :GRASS, { 26 => :STEEL, 28 => :ELECTRIC }],
             [158, 30, :DRAGON, 27, :DRAGON, { 31 => :GHOST, 32 => :BUG }]]
    }
    # The pad on map 47 that sends back to the entrance: its event and its tile.
    PAD = [33, [41, 27]]

    # The stage of this map an event belongs to, and the type it shows; nil for any other event.
    def self.piece(ev)
      (STAGES[$game_map.map_id] || []).each do |stage|
        _sw, icon, icon_type, right, right_type, wrong = stage
        return [stage, :icon, icon_type] if ev.id == icon
        return [stage, :right, right_type] if ev.id == right
        return [stage, :wrong, wrong[ev.id]] if wrong[ev.id]
      end
      nil
    end

    # A type's name in the game's language.
    def self.type(id)
      PokeAccess::Data.type_name(id)
    end

    # An icon's or a floor tile's name by the type it shows.
    def self.name(ev)
      p = piece(ev)
      return nil unless p
      PokeAccess::I18n.t(p[1] == :icon ? :rv_ranger_icon : :rv_ranger_tile, :type => type(p[2]))
    end

    # Whether the stage an event belongs to is still to pass.
    def self.open_stage?(ev)
      p = piece(ev)
      p ? !$game_switches[p[0][0]] : false
    end

    # Whether an event is listed: an icon or tile of a stage still to pass, a wrong tile not with the assist.
    def self.listed?(ev)
      open_stage?(ev) && !(piece(ev)[1] == :wrong && PokeAccess::Puzzles.assist?)
    end

    # The first stage of this map still to pass, or nil.
    def self.current
      (STAGES[$game_map.map_id] || []).find { |stage| !$game_switches[stage[0]] }
    end

    # The assist's answer for a stage: the icon's type and the tile to step on.
    def self.answer(stage)
      PokeAccess::I18n.t(:rv_ranger_answer, :type => type(stage[2]), :right => type(stage[4]))
    end
  end
end

PokeAccess::Game.define("revival") do
  ranger = PokeAccess::RevivalRanger
  ranger::STAGES.each do |map, stages|
    pieces = stages.map { |s| [s[1], s[3]] + s[5].keys }.flatten
    wrong = stages.map { |s| s[5].keys }.flatten
    mechanic(:state, map) do
      auto
      name pieces, lambda { |ev| ranger.name(ev) }, :when => lambda { |ev| ranger.listed?(ev) }
      hide wrong, :assist => true, :when => lambda { |ev| ranger.open_stage?(ev) }
      avoid wrong
      stages.each do |stage|
        phase lambda { ranger.current.equal?(stage) }, :quiet => true, :hint => lambda { ranger.answer(stage) }
      end
      if map == 46
        sent_back :rv_ranger_wrong, :to => ranger::ENTRANCE, :events => wrong
        sent_back :rv_ranger_pad_back, :maps => [47], :from => ranger::PAD[1], :to => ranger::ENTRANCE
        sent_back :rv_ranger_wrong, :maps => [47], :to => ranger::ENTRANCE
      else
        name ranger::PAD[0], :rv_ranger_pad, :when => false
        avoid ranger::PAD[0]
      end
      solved { stages.all? { |s| $game_switches[s[0]] } }
    end
  end
end
