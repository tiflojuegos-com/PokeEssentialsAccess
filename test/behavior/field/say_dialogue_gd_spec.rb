# The modern message path: Essentials v19+ dropped the Kernel prefix, so dialogue flows through a bare
# top-level pbMessageDisplay. The toolkit must wrap THAT one, and never mistake the singleton its own gen-6
# wrap would create by aliasing for the engine's entry: that mistake left six GameData games mute with the
# whole suite green, because nothing drove this path. Runs only in the gamedata pass.
Suite.define("dialogue: the modern bare pbMessageDisplay is hooked and no Kernel singleton is invented") do
  PokeAccess.instance_variable_set(:@last_say, nil)
  PokeAccess.instance_variable_set(:@last_say_t, nil)
  truthy "the bare function is wrapped", Object.private_method_defined?(:pbMessageDisplay__pa_inst)
  falsy "no Kernel singleton was made up by the mod", Kernel.respond_to?(:pbMessageDisplay)

  SpeakCapture.clear
  eq "the wrapper hands the engine's own result back", pbMessageDisplay(nil, "Bienvenido a Pueblo Anil"), "Bienvenido a Pueblo Anil"
  spoke "a line the engine shows is voiced", /Pueblo Anil/
  eq "queued, like every dialogue line", SpeakCapture.log[0][1], false
  eq "and it feeds the repeat key", PokeAccess.last_dialogue, "Bienvenido a Pueblo Anil"

  SpeakCapture.clear
  pbMessageDisplay(nil, "Bienvenido a Pueblo Anil")
  silent "the engine re-showing the same line within the window is not read twice"
end
