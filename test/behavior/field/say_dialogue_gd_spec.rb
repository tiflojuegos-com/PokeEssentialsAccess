# The modern message path (v19+): the bare top-level pbMessageDisplay is wrapped, and no Kernel singleton is made up.
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

# The diag counters on the modern engine name the bare function as the only wrapped form.
Suite.define("dialogue: on the modern engine the diag names the bare function as the wrapped entry") do
  eq "the bare function is the wrap", PokeAccess.dialogue_wraps, [:bare]
  eq "and the forms the game defines say bare only", PokeAccess::Keys.dialogue_forms, [:bare]
  before = PokeAccess.dialogue_seen
  PokeAccess.say_dialogue("A different line #{before}")
  eq "a line through the bare function counts", PokeAccess.dialogue_seen, before + 1
end
