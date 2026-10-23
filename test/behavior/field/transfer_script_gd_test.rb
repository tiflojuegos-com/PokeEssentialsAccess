# The script-transfer registry under the GameData-era stubs; the cases live in transfer_script_cases.rb.
require File.expand_path("transfer_script_cases", File.dirname(__FILE__))

class TransferScriptGdTest < PokeAccessTest
  TransferScriptCases.define(self)
end
