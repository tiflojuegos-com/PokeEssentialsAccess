# Kyu's autosave system (autosaveAnim, a top-level function): on each map change it saves a backup and slides a green
# "*" in, which the banner reader drops as a line with no letters; said as a notice of its own.
PokeAccess::Hooks.wrap_kernel("autosaveAnim", "plugin_kyu_autosave", :after) do |_args, _r|
  PokeAccess.speak(PokeAccess::I18n.t(:kyu_autosaved), false)
end
