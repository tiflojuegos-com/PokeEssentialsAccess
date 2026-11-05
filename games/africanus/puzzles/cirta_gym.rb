# Cirta's gym (map 307): five floor plates (switches 377 to 381) change where the fourteen stops of the Mudsdale lead,
# the lever of event 53 turns them off, and two swords (events 10 and 36) open the platforms to the leader. The second
# sword takes a chain of plates and rides, which the assist tells stage by stage; once both are taken (switches 382 and 383)
# the plates say no more of their rule on arriving.
PokeAccess::Game.define("africanus") do
  plates = [377, 378, 379, 380, 381]
  stages = [[[], :af_cirta_stage1], [[377], :af_cirta_stage2], [[377, 378], :af_cirta_stage3], [[378], :af_cirta_stage4],
            [[378, 379], :af_cirta_stage5], [[378, 379, 380], :af_cirta_stage6], [[378, 379, 380, 381], :af_cirta_stage7]]
  mechanic(:state, 307, :part => :plates) do
    auto
    name 25, :af_plate_blue, :assist => true
    name 29, :af_plate_green, :assist => true
    name 21, :af_plate_yellow, :assist => true
    name 31, :af_plate_cyan, :assist => true
    name 30, :af_plate_pink, :assist => true
    name [39, 38, 34, 35, 40, 32, 23, 19, 22, 16, 24, 26, 20, 12], :af_stop, :numbered => true, :assist => true
    avoid [25, 29, 21, 31, 30]
    name 53, :af_mudsdale_lever
    name [11, 17, 18, 33], :af_mudsdale
    watch :switch => 377, :label => :af_plate_blue, :on => :af_plate_on, :off => :af_plate_off
    watch :switch => 378, :label => :af_plate_green, :on => :af_plate_on, :off => :af_plate_off
    watch :switch => 379, :label => :af_plate_yellow, :on => :af_plate_on, :off => :af_plate_off
    watch :switch => 380, :label => :af_plate_cyan, :on => :af_plate_on, :off => :af_plate_off
    watch :switch => 381, :label => :af_plate_pink, :on => :af_plate_on, :off => :af_plate_off
    arrival_hint :af_cirta_rule
    solved { $game_switches[382] && $game_switches[383] }
    stages.each do |on, hint|
      phase(lambda { !$game_switches[383] && plates.all? { |s| ($game_switches[s] ? true : false) == on.include?(s) } },
            :hint => hint)
    end
    phase(lambda { !$game_switches[383] }, :hint => :af_cirta_reset)
  end

  mechanic(:state, 307, :part => :swords) do
    auto
    name [10, 36], :af_sword
    on_use 58, [:af_mosaic, { :name => "Aerodactyl" }]
    on_use 59, [:af_mosaic, { :name => "Ho-Oh" }]
    count :af_mosaics, :switches => [374, 375]
    watch :switch => 376, :say => :af_sword_appeared
    solved(nil) { $game_switches[382] && $game_switches[383] }
  end
end
