# Bill's Lighthouse cyberspace (map 423): Porygon (event 1) jumps elsewhere when spoken to facing a way with an exit from the
# state in variable 54 (0 to 13); a way with no exit does nothing. From state 12 facing down it reaches 13 and sets switch
# 112, and Bill (map 384) then gives a Porygon. The table is read off event 1's page.
PokeAccess::Game.define("infinitefusion") do
  exits = {
    0 => { :up => 1, :right => 3 },
    1 => { :up => 4, :right => 4, :left => 2 },
    2 => { :down => 5, :right => 0, :left => 7 },
    3 => { :down => 4, :right => 4, :left => 5 },
    4 => { :down => 3, :up => 1 },
    5 => { :down => 10, :left => 2 },
    6 => { :down => 10, :right => 2, :left => 11 },
    7 => { :down => 9, :up => 8, :left => 8 },
    8 => { :up => 7, :left => 9 },
    9 => { :down => 6, :left => 8 },
    10 => { :up => 5, :right => 5, :left => 6 },
    11 => { :down => 12, :right => 6, :left => 12 },
    12 => { :down => 13, :right => 5 }
  }
  ways = lambda do |from|
    seen = { from => [] }
    queue = [from]
    until queue.empty?
      state = queue.shift
      return seen[13] if state == 13
      (exits[state] || {}).each do |facing, to|
        next if seen.key?(to)
        seen[to] = seen[state] + [facing]
        queue.push(to)
      end
    end
    seen[13]
  end
  porygon = lambda { PokeAccess::Data.species_name(137) rescue nil }
  words = {}
  (1..13).each { |state| words[state] = :ifq_porygon_jumped }
  words[0] = :ifq_porygon_home
  advice = lambda do
    way = ways.call($game_variables[54].to_i)
    next "" unless way
    names = way.map { |facing| PokeAccess::I18n.t("ifq_face_#{facing}".to_sym) }
    [:ifq_porygon_hint, { :n => way.length, :ways => names.join(", ") }]
  end

  mechanic(:state, 423) do
    auto
    name 6, :ifq_cyber_exit
    watch :var => 54, :label => lambda { porygon.call }, :words => words
    arrival_hint :ifq_porygon_rule
    solved(nil, :quiet => true) { $game_switches[112] }
    hint advice
  end
end
