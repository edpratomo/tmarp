require 'faraday'
require 'faraday_middleware'
require 'json'

class TeamMatchFixup
  def initialize(app)
    @updated_players = {}
    @score = {"team1" => 0, "team2" => 0}
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    match = JSON.parse(body.inject('') {|m,o| m << o;m})
    if match["status"] == "finished"
      [ status, headers, body ]
    else
      processed = process(match)
      [status, headers, [ JSON.generate(processed) ]]
    end
  end

  private

  def process(match)
    team1_players = match["teams"]["team1"]["players"].map {|e| e["username"]}.inject({}){|m,o| m[o]=true;m}
    boards = match["teams"]["team1"]["players"].map {|e| e["board"]}
    boards.each do |url|
      board = retrieve(url)
      board["games"].each do |game|
        if game.has_key?("end_time")
          @updated_players[url] ||= {"team1" => {}, "team2" => {}}
          which_color_win = %w[white black].find {|e| game[e]["result"] == "win" }
          unless which_color_win
            # draw
            @score["team1"] += 0.5
            @score["team2"] += 0.5
          else
            if team1_players[ game[which_color_win]["@id"].split('/').last ]
              # point for team1
              @score["team1"] += 1.0
            else
              @score["team2"] += 1.0
            end
          end

          if team1_players[ game["white"]["@id"].split('/').last ]
            @updated_players[url]["team1"]["played_as_white"] = game["white"]["result"]
            @updated_players[url]["team2"]["played_as_black"] = game["black"]["result"]
          else
            @updated_players[url]["team1"]["played_as_black"] = game["black"]["result"]
            @updated_players[url]["team2"]["played_as_white"] = game["white"]["result"]
          end
        end
      end
    end
    
    out = match.clone
    if @score["team1"] + @score["team2"] == boards * 2.0
      out["status"] = "finished"
    end
    %w[team1 team2].each do |team|
      out["teams"][team]["players"].each do |player|
        %w[played_as_white played_as_black].each do |played_as|
          if @updated_players[player["board"]][team][played_as]
            player[played_as] = @updated_players[player["board"]][team][played_as]
          end
        end
      end
    end
    return out
  end
  
  def retrieve(url)
    conn = Faraday.new(url: url) do |c|
             c.use FaradayMiddleware::ParseJson
             c.use FaradayMiddleware::FollowRedirects, limit: 3
             c.use Faraday::Response::RaiseError # raise exceptions on 40x, 50x responses
             c.use Faraday::Adapter::NetHttp
             c.headers['Content-Type'] = "application/json"
           end
    response = conn.get
    response.body
  end
end
