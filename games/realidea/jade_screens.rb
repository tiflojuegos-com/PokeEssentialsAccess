# Ciudad Jade's screens: the theatre's choreography sheet (Baileoricorios), captured from its constructor to its
# loop; the dance it is checked against (map 113, event 10's move routes for events 2 to 5), told as the routes are
# set; the gym's cry helper (Pokemonysusgritos), whose chosen species is read on each input frame; and the rhythm
# game two of the gym's battles open (Idol).
module PokeAccess
  module ReaJade
    # The species the helper's three sprites show for each value of $game_variables[91]; the constructor's 035 is an
    # octal literal, so the second sprite of the first trio is species 29.
    TRIOS = { 1 => [209, 29, 742], 2 => [175, 546, 281], 3 => [703, 183, 755] }

    # The theatre's map, and the dancers' events from left to right, Oricorio 1 to 4.
    DANCE_MAP = 113
    DANCERS = [2, 3, 4, 5]
    # Move route codes of a step: down, left, right, up and jump; turns and waits are not steps.
    STEP_KEYS = { 1 => :dir_down, 2 => :dir_left, 3 => :dir_right, 4 => :dir_up, 14 => :rea_ori_jump }

    @routes = {}
    @dance = nil

    # The sheet's columns as one line: "Oricorio 1: Arriba, Salto, ..." per column.
    def self.sheet_text(rows)
      cols = (rows || []).map do |r|
        lines = r.to_s.split("\n").map { |l| l.strip }.reject { |l| l.empty? }
        next nil if lines.empty?
        lines.length > 1 ? "#{lines[0]}: #{lines[1..-1].join(', ')}" : lines[0]
      end
      cols.compact.join(". ")
    end

    # The species under the cursor and its position among the three, or nil off the table.
    def self.cry_text(sel, group)
      ids = TRIOS[group.to_i]
      return nil unless ids && sel.is_a?(Integer) && sel >= 1 && sel <= ids.length
      name = (PokeAccess::Data.species_name(ids[sel - 1]) rescue nil)
      name = "Pokémon #{sel}" if name.nil? || name.to_s.empty?
      PokeAccess::Verbosity.list_entry(name, sel, ids.length)
    end

    # The steps of a move route as spoken words.
    def self.steps_of(route)
      list = (route.list rescue nil) || []
      list.map { |c| STEP_KEYS[(c.code rescue nil)] }.compact.map { |k| PokeAccess::I18n.t(k) }
    end

    # A Set Move Route of the dance (command 209 on map 113 for a dancer): kept, and once the four are set the whole
    # dance is told, led by the key that opens the sheet, which is only open while the dance runs.
    def self.route_set(character, route)
      return unless ($game_map.map_id rescue 0) == DANCE_MAP && DANCERS.include?(character)
      @routes = {} if character == DANCERS.first
      @routes[character] = steps_of(route)
      return unless DANCERS.all? { |id| @routes[id] }
      @dance = PokeAccess::I18n.t(:rea_ori_dance, :list => dance_list)
      hint = PokeAccess::KeyHints.localize(PokeAccess::I18n.t(:rea_ori_sheet_key))
      PokeAccess.speak(PokeAccess::Verbosity.hints? ? PokeAccess.sentences([hint, @dance]) : @dance, true)
    rescue StandardError
      nil
    end

    # "Oricorio 1: arriba, salto, ...; Oricorio 2: ..." for the four routes kept.
    def self.dance_list
      (0...DANCERS.length).map do |i|
        PokeAccess::I18n.t(:rea_ori_dancer, :n => i + 1, :steps => @routes[DANCERS[i]].join(", "))
      end.join("; ")
    end

    # The last dance told, for the info key while its question is up; nil before any.
    def self.dance; @dance; end

    # True while the theatre's supervisor runs the dance and its question: event 10's self switch A, which the right
    # answer leaves on as it turns B on for the reward.
    def self.dance_live?
      return false if @dance.nil? || ($game_map.map_id rescue 0) != DANCE_MAP
      sw = $game_self_switches
      ((sw[[DANCE_MAP, 10, "A"]] rescue false) && !(sw[[DANCE_MAP, 10, "B"]] rescue false)) ? true : false
    end

    # The notes' arrows, by the names the song gives them.
    NOTE_KEYS = { "up" => :dir_up, "down" => :dir_down, "left" => :dir_left, "right" => :dir_right }

    @idol = nil

    def self.hold_idol(scene); @idol = scene; end
    def self.release_idol; @idol = nil; end

    # Each frame of the rhythm game: the arrow of each note as it comes within its reach of the selector (30 px
    # either side, the window a press counts in), once per note, in the song's order.
    def self.idol_poll
      s = @idol
      return unless s
      notes = PokeAccess.ivar(s, :@notes)
      sel = PokeAccess.sprite(s, "selector")
      return unless notes.is_a?(Array) && sel
      sx = Graphics.width / 2 - sel.bitmap.width / 2
      done = PokeAccess.ivar(s, :@pa_idol_note) || -1
      notes.each_with_index do |n, i|
        next if i <= done
        key = NOTE_KEYS[(n.note rescue nil).to_s]
        next unless key && !(n.hit rescue true) && ((n.x rescue 9999) - sx).abs < ((n.range rescue 30) || 30)
        s.instance_variable_set(:@pa_idol_note, i)
        PokeAccess.speak(PokeAccess::I18n.t(key), true)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  before("Baileoricorios", :initialize, :optional => true) { |_s, _a| PokeAccess::PaintCapture.arm(:rea_oricorios) }
  before("Baileoricorios", :actu, :optional => true) do |_s, _a|
    rows = PokeAccess::PaintCapture.take(:rea_oricorios, :dtex)
    PokeAccess.speak_clean(PokeAccess::ReaJade.sheet_text(rows), true)
  end
  before("Interpreter", :command_209, :optional => true) do |interp, _a|
    params = PokeAccess.ivar(interp, :@parameters)
    PokeAccess::ReaJade.route_set(params[0], params[1]) if params.is_a?(Array)
  end
  puzzle(PokeAccess::ReaJade::DANCE_MAP, :kind => :stages,
         :stages => [{ :when => lambda { PokeAccess::ReaJade.dance_live? },
                       :title => lambda { PokeAccess::ReaJade.dance }, :quiet => true }])

  before("Pokemonysusgritos", :initialize, :optional => true) { |s, _a| PokeAccess::Cursor.reset(s, :rea_cry) }
  after("Pokemonysusgritos", :input, :optional => true) do |scene, _r, _a|
    sel = PokeAccess.ivar_i(scene, :@seleccion)
    t = PokeAccess::ReaJade.cry_text(sel, ($game_variables[91] rescue nil))
    PokeAccess::Cursor.announce(scene, :rea_cry, sel, true) { t } if t
  end

  around("Idol", :pbStartScene, :optional => true) do |_s, nxt, _a|
    PokeAccess::PaintCapture.speak_around(:rea_idol, false) { nxt.call }
  end
  around("Idol", :pbUpdate, :optional => true) do |s, nxt, _a|
    PokeAccess::ReaJade.hold_idol(s)
    begin
      nxt.call
    ensure
      PokeAccess::ReaJade.release_idol
    end
  end
  poll_each_frame { PokeAccess::ReaJade.idol_poll }
end
