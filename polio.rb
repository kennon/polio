require 'rubygems'
require 'sinatra/base'
require 'redis'
require 'mustache/sinatra'
require 'yajl'

module Polio 
  
  class Application < Sinatra::Base
    register Mustache::Sinatra
    require 'views/layout'
  
    dir = File.dirname(File.expand_path(__FILE__))

    configure do
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

    before do
      if params[:username]
        @username = session[:username] = params[:username]
      else
        @username = session[:username] || "kennon"
      end
    end

    helpers do
      def redis
        return @redis if @redis
        @redis = Redis.new(:host => '127.0.0.1', :port => 6379, :thread_safe => true)
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
  
    get "/" do
      mustache :index
    end
  
    post "/create" do
      # create, redirect to poll view page
      id = next_id
      poll = {
        :id => id,
        :question => params[:question], 
        :creator => @username, 
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
      @poll = decode(redis.get("Polio:polls:#{id}"))

      @votes = {}
      @voters = {}
      
      if @username == @poll['creator'] or redis.sismember("Polio:voted:#{@username}", id)      
        (0..3).each do |i|
          @votes[i] = redis.scard("Polio:polls:#{id}:votes:#{i}")
          @voters[i] = redis.smembers("Polio:polls:#{id}:votes:#{i}")
        end

        mustache :results
      else
        mustache :poll
      end
    end

    post "/vote/:id" do |id|
      puts params.inspect
      @poll = decode(redis.get("Polio:polls:#{id}"))

      unless @username == @poll['creator'] or redis.sismember("Polio:voted:#{@username}", id)
        puts "voting..."
#        redis.multi do
          redis.sadd "Polio:polls:#{id}:votes:#{params[:option]}", @username
          redis.sadd "Polio:voted:#{@username}", id
#        end
      end
      
      redirect "/poll/#{id}"
    end
  end
end

#Polio.run!