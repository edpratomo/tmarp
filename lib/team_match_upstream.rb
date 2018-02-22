require 'faraday'
require 'faraday_middleware'
require 'rack'

class TeamMatchUpstream
  def initialize(app)
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env.clone)
    match_id = req.path_info.split('/').last
    unless match_id =~ /^\d+$/
      return ["404", {"Content-Type" => "application/json"}, 
              ['{"message":"Data provider not found for key \"/pub/match\".","code":0}']
             ]
    end

    status, headers, body = @app.call(env)

    conn = Faraday.new(url: team_match_api_url(match_id)) do |c|
             c.use FaradayMiddleware::FollowRedirects, limit: 3
             c.use Faraday::Response::RaiseError # raise exceptions on 40x, 50x responses
             c.use Faraday::Adapter::NetHttp
             c.headers['Content-Type'] = "application/json"
           end
    response = conn.get
    [response.status, {"Content-Type" => "application/json"}, [response.body]]
  end

  private
  def team_match_api_url(match_id)
    "https://api.chess.com/pub/match/#{match_id}"
  end
end
