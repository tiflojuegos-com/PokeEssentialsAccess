# A game's maps as text, for mod developers: without a map id the list of maps; with one, the map drawn tile by tile
# with its events; with --route, the walk the mod plans between two tiles drawn over it. The route is the mod's own
# planner on the test world (the gen-6 stubs) built from the map's tiles: sides, counters, water, ledges, bridges,
# terrain tags and the events showing at the start. The game's own passability scripts are not run.
#   ruby tools/map_view.rb "<game or Data folder>"                             # the maps: id, parent and name
#   ruby tools/map_view.rb "<game or Data folder>" 42                          # map 42 and its events
#   ruby tools/map_view.rb "<game or Data folder>" 42 --area 0,0,30,20         # only that rectangle
#   ruby tools/map_view.rb "<game or Data folder>" 42 --route 3,4 18,9         # and the mod's walk from 3,4 to 18,9
#   ruby tools/map_view.rb "<game or Data folder>" 42 --route 3,4 18,9 --profile anil   # over a profile's modules
# Legend: # shut, . open, + open on some sides, C counter, ~ water, D deep water, W waterfall, V its crest,
# v ^ < > ledge by the way it is hopped (L when several), g tall grass, i ice, b bridge; events by letter.
require_relative "map_data"

WATER = { 5 => "D", 6 => "~", 7 => "~", 8 => "W", 9 => "V" }.freeze
MARKS = { 10 => "g", 12 => "i", 15 => "b" }.freeze
ARROW = { 2 => "v", 4 => "<", 6 => ">", 8 => "^" }.freeze
TRIGGERS = ["action", "player touch", "event touch", "autorun", "parallel"].freeze
LETTERS = ("a".."z").to_a + ("A".."Z").to_a

def option(name, count = 1)
  i = ARGV.index(name)
  i ? ARGV[i + 1, count] : nil
end

def point(text)
  x, y = text.to_s.split(",").map { |v| Integer(v) }
  abort "a tile is x,y: #{text.inspect}" unless x && y
  [x, y]
end

# The character a tile is drawn with.
def tile_char(g, x, y)
  return "C" if g.counter?(x, y)
  t = g.tag(x, y)
  if t == 1
    d = g.ledge_dirs(x, y)
    return d.length == 1 ? ARROW[d[0]] : "L"
  end
  return WATER[t] if WATER[t]
  open = MapData::DIRS.keys.count { |d| g.side_open?(x, y, d) }
  return "#" if open == 0
  return "+" if open < 4
  MARKS[t] || "."
end

# The map's rows inside area, with events by letter and overlay ({[x, y] => char}) on top.
def draw(g, area, events, overlay = {})
  x0, y0, x1, y1 = area
  by_tile = {}
  events.each_with_index { |e, i| by_tile[[e[2], e[3]]] ||= LETTERS[i] || "*" }
  header = "    " + (x0..x1).map { |x| (x % 10).to_s }.join
  [header] + (y0..y1).map do |y|
    format("%3d ", y) + (x0..x1).map { |x| overlay[[x, y]] || by_tile[[x, y]] || tile_char(g, x, y) }.join
  end
end

def legend(events)
  events.each_with_index.map do |(id, name, x, y, graphic, through, trigger), i|
    what = [graphic.empty? ? "no graphic" : graphic, TRIGGERS[trigger] || "trigger #{trigger}"]
    what << "through" if through
    "#{LETTERS[i] || '*'}  ##{id} #{name.inspect} at #{x},#{y}: #{what.join(', ')}"
  end
end

# Loads the mod under the gen-6 test stubs and builds the test world from the map.
def mod_world(g, events, profile)
  ENV["PA_ENGINE"] = "gen6"
  support = File.expand_path("../test/support", File.dirname(__FILE__))
  require File.join(support, "harness")
  require File.join(support, "speak_capture")
  errors = Harness.load_all(profile)
  abort "the mod failed to load: #{errors.first}" unless errors.empty?
  SpeakCapture.install
  m = $game_map
  rows = (0...g.height).map do |y|
    (0...g.width).map do |x|
      c = tile_char(g, x, y)
      c == "#" || c == "C" ? c : (WATER[g.tag(x, y)] ? "~" : ".")
    end.join
  end
  m.load_grid(rows)
  (0...g.height).each do |y|
    (0...g.width).each do |x|
      t = g.tag(x, y)
      m.set_terrain(x, y, t) if t > 1 && t != 15 && t != 6 && t != 7
      m.place_bridge(x, y) if t == 15
      if t == 1
        d = g.ledge_dirs(x, y)
        m.place_ledge(x, y, d[0]) if d.length == 1
      end
      MapData::DIRS.each do |d, (dx, dy)|
        next if g.side_open?(x, y, d) || !g.valid?(x + dx, y + dy)
        m.block_step(x, y, d)
        m.block_step(x + dx, y + dy, 10 - d)
      end
    end
  end
  events.each do |id, name, x, y, graphic, through, _trigger|
    ev = TestEvent.new(id, name, x, y)
    ev.character_name = graphic
    ev.through = through
    ev.blocking = !through && !graphic.empty?
    m.events[id] = ev
  end
  m
end

# The mod's walk from from to to: [status, the tiles stepped on, presses].
def plan(from, to, onto)
  $game_player.x, $game_player.y = from
  PokeAccess::Pathfinder.invalidate_cache(true)
  PokeAccess::World::Epoch.touch(:tiles)
  r = PokeAccess::Routes::Planner.walk(to[0], to[1], onto)
  return [r.status, [], 0] unless r.status == :found
  pf = PokeAccess::Pathfinder
  steps = PokeAccess::Routes::Moves.trace(from[0], from[1], pf.bridge_level, r.route, pf.replay_mode)
  [r.status, steps.reject { |s| s.mid }.map { |s| [s.x, s.y] }, r.route.length]
end

abort "usage: ruby tools/map_view.rb \"<game or Data folder>\" [map id] [--area x0,y0,x1,y1] [--route x,y x,y] " \
      "[--profile name]" unless ARGV[0]
game = MapData::Game.new(ARGV[0])
if ARGV[1].nil? || ARGV[1].start_with?("--")
  game.infos.each { |id, (name, parent)| puts format("%4d  %-40s parent %d", id, name, parent) }
  exit
end

g = game.map(Integer(ARGV[1]))
area = option("--area") ? option("--area")[0].split(",").map { |v| Integer(v) } : [0, 0, g.width - 1, g.height - 1]
events = g.events
puts "Map #{g.id}: #{g.name} (#{g.width}x#{g.height})"
route = option("--route", 2)
overlay = {}
if route
  from = point(route[0])
  to = point(route[1])
  onto = events.none? { |e| [e[2], e[3]] == to }
  mod_world(g, events, (option("--profile") || [])[0])
  status, tiles, presses = plan(from, to, onto)
  tiles.each { |t| overlay[t] = "*" }
  overlay[from] = "S"
  overlay[to] = "T"
  puts "Route #{from.join(',')} -> #{to.join(',')}#{onto ? '' : ' (acting on the event there)'}: #{status}" \
       "#{status == :found ? ", #{presses} presses, #{tiles.length} tiles" : ''}"
  puts "  #{tiles.map { |t| t.join(',') }.join(' ')}" unless tiles.empty?
end
puts draw(g, area, events, overlay)
puts legend(events)
