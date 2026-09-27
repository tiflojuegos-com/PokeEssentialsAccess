# The GameData-era trainer summary reads $player: name, badge count, pokedex tally.
Suite.define("contextual (gamedata): trainer info reads $player") do
  out = PokeAccess::Info.trainer_info
  match "speaks the player name", out, /Tester/
  match "speaks the badge count", out, /3/
  match "speaks the pokedex tally (owned 50)", out, /50/
end

# The GameData summary builders (classic and v22 scenes) give text for the info, stats and moves pages.
Suite.define("summary (gamedata): page builders speak content") do
  pk = Poke.build(:name => "Gardevoir", :level => 40)
  info = PokeAccess::SummaryGameData.info_text(pk)
  match "info page speaks the level", info.to_s, /40/
  stats = PokeAccess::SummaryGameData.stats_text(pk)
  truthy "stats page produces text", stats && !stats.to_s.empty?
  moves = PokeAccess::SummaryGameData.moves_text(pk)
  truthy "moves page produces text", moves && !moves.to_s.empty?
end

# TrainerCardData reads the card off $player.
Suite.define("trainer card (gamedata): TrainerCardData reads $player") do
  out = PokeAccess::TrainerCardData.text
  match "card speaks the trainer name", out.to_s, /Tester/
  match "card speaks the id (zero-padded)", out.to_s, /12345/
end
