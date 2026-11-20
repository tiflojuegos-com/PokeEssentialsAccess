module PokeAccess
  # The treasure hook (0170_TreasureHook, TreasureHookScene, maps 61 and 103): the hook sinks on its own down one of
  # five lanes (@corsia), left and right move it, and rows of rocks and seaweed, or a single Pokemon swimming across,
  # come up towards it; the treasure lies at the bottom. Says the lane, each row as it comes into sight, what lies ahead
  # in a lane the hook moves to, and the hits the seaweed takes from it.
  module XenoverseHook
    LANES = 5
    KINDS = { 0 => :xenoverse_hook_mon, 1 => :xenoverse_hook_rock, 2 => :xenoverse_hook_alga, 3 => :xenoverse_hook_alga2 }

    # Starts reading a game that opens.
    def self.open
      @lane, @hits, @seen = nil, 0, {}
    end

    # Forgets the game as it closes.
    def self.close
      @lane, @seen = nil, nil
      PokeAccess::Info.clear_text
    end

    # Reads one frame: the lane on opening and on each change, the hits, and the rows that came into sight.
    def self.poll(scene)
      return if @seen.nil?
      sprites = PokeAccess.ivar(scene, :@sprites)
      hook = sprites.is_a?(Hash) ? sprites["hook"] : nil
      return unless hook
      lane = PokeAccess.ivar(hook, :@corsia)
      return unless lane.is_a?(Integer)
      objects = sprites.keys.select { |k| k.to_s =~ /\Aobs\d+\z/ }.map { |k| sprites[k] }.compact
      moved(lane, hook, objects)
      damaged(hook)
      sighted(objects)
    end

    # Says the lane as the game opens, and on each change with what lies ahead in it.
    def self.moved(lane, hook, objects)
      return if lane == @lane
      first = @lane.nil?
      @lane = lane
      if first
        text = PokeAccess::I18n.t(:xenoverse_hook_start, :n => lane)
        PokeAccess.speak(PokeAccess::Verbosity.with_hint(text, PokeAccess::I18n.t(:xenoverse_hook_help)), true)
        return
      end
      what = ahead(lane, hook, objects)
      label = PokeAccess::I18n.t(:xenoverse_hook_lane, :n => lane)
      PokeAccess.speak(what ? PokeAccess::I18n.t(:xenoverse_named, :name => label, :text => what) : label, true)
    end

    # Says each new hit the seaweed gives the hook, out of the three that break it.
    def self.damaged(hook)
      hits = (hook.hits rescue nil)
      return unless hits.is_a?(Integer) && hits > @hits
      @hits = hits
      PokeAccess.speak(PokeAccess::I18n.t(:xenoverse_hook_hits, :n => [hits, 3].min), true)
    end

    # Says the objects that came into sight this frame, by kind, each with its lanes.
    def self.sighted(objects)
      bottom = (Graphics.height rescue 384)
      fresh = objects.select { |o| !@seen[o.object_id] && y_of(o) && y_of(o) < bottom }
      return if fresh.empty?
      fresh.each { |o| @seen[o.object_id] = true }
      parts = []
      kinds(fresh).each do |key, lanes|
        parts.push(PokeAccess::I18n.t(:xenoverse_named, :name => PokeAccess::I18n.t(key), :text => lanes.join(", ")))
      end
      PokeAccess.speak(PokeAccess.sentences(parts), false) unless parts.empty?
    end

    # The fresh objects grouped by kind, in a fixed order, each kind with its sorted lanes.
    def self.kinds(objects)
      order = [:xenoverse_hook_chest, :xenoverse_hook_mon, :xenoverse_hook_rock, :xenoverse_hook_alga, :xenoverse_hook_alga2]
      groups = {}
      objects.each do |o|
        key = kind(o)
        (groups[key] ||= []).push(lane_of(o)) if key
      end
      order.select { |k| groups[k] }.map { |k| [k, groups[k].compact.uniq.sort] }
    end

    # The key naming an object: the treasure, else its obstacle type.
    def self.kind(o)
      return :xenoverse_hook_chest if o.class.name == "Treasure"
      KINDS[(o.type rescue nil)]
    end

    # The kind of the nearest object still ahead of the hook in a lane and in sight, or nil.
    def self.ahead(lane, hook, objects)
      top = (hook.position[1] rescue nil)
      return nil unless top.is_a?(Numeric)
      bottom = (Graphics.height rescue 384)
      near = objects.select do |o|
        y = y_of(o)
        y && y < bottom && y + height_of(o) >= top && lane_of(o) == lane
      end
      o = near.min_by { |x| y_of(x) }
      o && kind(o) ? PokeAccess::I18n.t(kind(o)) : nil
    end

    # The lane under an object's middle, 1 to 5.
    def self.lane_of(o)
      x = (o.position[0] rescue nil)
      return nil unless x.is_a?(Numeric)
      width = (Graphics.width rescue 512) / 6.0
      lane = ((x + width_of(o) / 2.0) / width + 0.5).floor
      [[lane, 1].max, LANES].min
    end

    def self.y_of(o)
      y = (o.position[1] rescue nil)
      y.is_a?(Numeric) ? y : nil
    end

    def self.width_of(o)
      (o.image.width rescue 0).to_i
    end

    def self.height_of(o)
      (o.image.height rescue 0).to_i
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  # The text the braille box draws as dots (0239_Misc, map 680), said as a line of dialogue so the history keeps it.
  kernel("pbDisplayBrailleText") do |args, _r|
    PokeAccess.say_dialogue(PokeAccess::I18n.t(:xenoverse_braille, :text => PokeAccess.clean(args[0].to_s)))
  end

  before("TreasureHookScene", :pbStartScene) { |_scene, _a| PokeAccess::XenoverseHook.open }
  before("TreasureHookScene", :update) { |scene, _a| PokeAccess::XenoverseHook.poll(scene) }
  before("TreasureHookScene", :pbEndScene) { |_scene, _a| PokeAccess::XenoverseHook.close }
end
