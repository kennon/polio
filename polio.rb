require 'rubygems'
require 'sinatra/base'
require 'redis'
require 'mustache/sinatra'
require 'yajl'
require 'twitter_oauth'

module Polio 
  
  class Application < Sinatra::Base
    register Mustache::Sinatra
    require 'views/layout'
  
    dir = File.dirname(File.expand_path(__FILE__))

    configure do
      @@config = YAML.load_file("config.yml") rescue nil || {}
      
      set :sessions, true
      set :environment, :development

      set :public,    "#{dir}/public"
      set :static,    true

      set :mustache, {
        :namespace => Object,
        :views => 'views/',
        :templates => 'templates/'
      }
    end
    
    enable :sessions

    helpers do
      def username
        session[:username]
      end
      
      def twitter
        return @client if @client
        @client = TwitterOAuth::Client.new(
          :consumer_key => ENV['CONSUMER_KEY'] || @@config['consumer_key'],
          :consumer_secret => ENV['CONSUMER_SECRET'] || @@config['consumer_secret'],
          :token => session[:access_token],
          :secret => session[:secret_token]
        )
      end
      
      def redis
        return @redis if @redis
        @redis = Redis.new(:host => @@config['redis_host'] || '127.0.0.1', :port => @@config['redis_port'] || 6379, :thread_safe => true)
      end
      
      def next_id
        redis.incr("Polio:next_id").to_s(36)
      end
      
      def encode(object)
        Yajl::Encoder.encode(object)
      end

      def decode(object)
        Yajl::Parser.parse(object)# rescue nil
      end      
    end    
    
    before do
      @username = session[:username]
    end
  
    get "/" do
      mustache :index
    end
  
    post "/create" do
      redirect('/') unless session[:username]
      
      # create, redirect to poll view page
      id = next_id
      poll = {
        :id => id,
        :question => params[:question], 
        :creator => username, 
        :created_at => Time.now,
        :options => {
          0 => params[:options]['0'],
          1 => params[:options]['1'],
          2 => params[:options]['2'],
          3 => params[:options]['3'],
        }
      }
      
      redis.set("Polio:polls:#{id}", encode(poll))
      redirect "/poll/#{id}"
    end

    get "/poll/:id" do |id|
      session[:return_to] = "/poll/#{id}" unless username      
      
      @poll = decode(redis.get("Polio:polls:#{id}")) rescue redirect('/')

      @votes = {}
      @voters = {}
      
      if username == @poll['creator'] or redis.sismember("Polio:voted:#{username}", id)
        (0..3).each do |i|
          @votes[i] = redis.scard("Polio:polls:#{id}:votes:#{i}")
          @voters[i] = redis.smembers("Polio:polls:#{id}:votes:#{i}")
        end

        mustache :results
      else
        @voted = redis.get("Polio:num_votes:#{id}")
        mustache :poll
      end
    end

    post "/vote/:id" do |id|
      redirect('/') unless session[:username]
      
      @poll = decode(redis.get("Polio:polls:#{id}")) rescue redirect('/')

      unless username == @poll['creator'] or redis.sismember("Polio:voted:#{username}", id)
        puts "voting..."
#        redis.multi do
          redis.sadd "Polio:polls:#{id}:votes:#{params[:option]}", username
          redis.sadd "Polio:voted:#{username}", id
          redis.incr "Polio:num_votes:#{id}"
#        end
      end
      
      redirect "/poll/#{id}"
    end
    
    #
    # oauth integration shamelessly copied from (i mean, inspired by) http://github.com/moomerman/sinitter    
    #
    
    get '/login' do
      request_token = twitter.request_token(
        :oauth_callback => ENV['CALLBACK_URL'] || @@config['callback_url']
      )
      session[:request_token] = request_token.token
      session[:request_token_secret] = request_token.secret
      redirect request_token.authorize_url.gsub('authorize', 'authenticate') 
    end

    # auth URL is called by twitter after the user has accepted the application
    # this is configured on the Twitter application settings page
    get '/auth' do
      # Exchange the request token for an access token.

      begin
        @access_token = twitter.authorize(
          session[:request_token],
          session[:request_token_secret],
          :oauth_verifier => params[:oauth_verifier]
        )
      rescue OAuth::Unauthorized
      end

      if twitter.authorized?
          # Storing the access tokens so we don't have to go back to Twitter again
          # in this session.  In a larger app you would probably persist these details somewhere.
          session[:access_token] = @access_token.token
          session[:secret_token] = @access_token.secret
          session[:username] = twitter.info["screen_name"]
          session[:info] = twitter.info
          
          # redirect to where you auth'd from
          return_to = session[:return_to]
          session[:return_to] = nil
          redirect (return_to || '/')
        else
          redirect '/'
      end
    end

    get '/logout' do
      session[:username] = nil
      session[:return_to] = nil
      session[:request_token] = nil
      session[:request_token_secret] = nil
      session[:access_token] = nil
      session[:secret_token] = nil
      redirect '/'
    end
    
  end
end

#Polio.run!