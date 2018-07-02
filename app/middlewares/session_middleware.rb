require 'addressable/uri'
require 'json'
require 'net/http'

module Middlewares
  class SessionMiddleware

    def initialize(app)
      @app = app
      @open_timeout = 6
      @read_timeout = 6
      @retry_on = ['408', '502', '503', '504']
      @retries = 2
    end


    def call(env)
      puts "Session processing, Thread Id: #{Thread.current.object_id}"
      request = Rack::Request.new(env)
      unless skip_request?(request)
        http = Net::HTTP.new( request.host, request.port)
        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout
        request = Net::HTTP.const_get("Post").new("/custom_session/session")

        request['Accept'] = 'application/json'

        response = http.request(request)
        if response.code == '200'
          session_data = JSON.parse(response.body)
          puts session_data
        end
      end

      @app.call(env)
    end

    def skip_request?(request)
      excluded_path = %w( /custom_session )
      request.path_info.start_with?(*excluded_path)
    end
  end
end