# Engine.era_scene on the GameData engine, which only the *_gd_spec files reach: a lone name binds the reader it
# belongs to on either era (PokeBattle_Scene in a v18 game), and a gen-6 reader never takes the modern name alone.
Suite.define("scene aliases on GameData: a lone name is its own reader's, the modern one never the gen-6 reader's") do
  eng = PokeAccess::Engine
  Object.const_set(:PaSpecGdBase, Class.new) unless Object.const_defined?(:PaSpecGdBase)
  Object.const_set(:PaSpecGdAlias, Class.new(PaSpecGdBase)) unless Object.const_defined?(:PaSpecGdAlias)

  truthy "this pass runs the GameData engine", eng.gamedata?
  eq "a lone name binds its own reader, whichever era that reader is",
     [eng.era_scene(:gamedata, "PaSpecGdBase", "PaSpecGdNope"), eng.era_scene(:gen6, "PaSpecGdBase", "PaSpecGdNope")],
     ["PaSpecGdBase", "PaSpecGdBase"]
  eq "a gen-6 reader never takes the other era's lone name here",
     eng.era_scene(:gen6, "PaSpecGdNope", "PaSpecGdBase"), ""
  eq "both present: the GameData reader takes the ancestral name and the gen-6 one nothing",
     [eng.era_scene(:gamedata, "PaSpecGdAlias", "PaSpecGdBase"), eng.era_scene(:gen6, "PaSpecGdAlias", "PaSpecGdBase")],
     ["PaSpecGdBase", ""]
  eq "the modern summary binds and the gen-6 one does not",
     [PokeAccess::SummaryV21::SCENE.empty?, PokeAccess::SummaryGen6::SCENE.empty?], [false, true]
end
