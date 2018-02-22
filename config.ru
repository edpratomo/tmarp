
require './lib/team_match_upstream'
require './lib/pretty_json'

use Rack::Reloader
use Rack::CommonLogger

map "/pretty" do
  use PrettyJSON # last order of execution
  use TeamMatchUpstream

  run ->(env) { [200, {"Content-Type" => "application/json"}, []] }
end
