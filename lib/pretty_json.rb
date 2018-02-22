require 'json'

class PrettyJSON
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env.clone)
    out = JSON.pretty_generate(JSON.parse(body.inject('') {|m,o| m << o;m}))
    [ "200", {"Content-Type" => "application/json"}, [out]]
  end
end
