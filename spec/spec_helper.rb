if RUBY_VERSION =~ /^1\.9/
  require 'ruby-debug'
end
require 'libertree/db'

########################
# FIXME: M4DBI wants us to connect to the db before defining models.  As model
# definitions are loaded when 'libertree/server' is required, we have to do
# this first.
Libertree::DB.load_config "#{File.dirname( __FILE__ ) }/../database.yaml"
Libertree::DB.dbh
########################

require 'libertree/server'
require_relative 'factories'

class MockServer
  include Libertree::Server

  attr_reader :responses

  def initialize
    @ip_remote = '192.168.0.100'
    @responses = []
    @public_key = 'public-key-of-mock-server'
    Libertree::Server.log = File.open( 'test-server.log', 'a+' )
  end

  def respond(data)
    @responses << data.to_json
  end

  def close_connection_after_writing
    # noop in testing
  end

  def response
    JSON.parse @responses[-1]
  end

  def has_responded_with?(hash)
    response.should == hash
  end

  def has_responded_with_code?(code)
    has = ( response['code'] == code )
    if ! has
      $stderr.puts "Expected #{code.inspect}, got #{response['code'].inspect}.  Error message: #{response['message'].inspect}"
    end
    has
  end
end

if ENV['LIBERTREE_ENV'] != 'test'
  $stderr.puts "Refusing to run specs in a non-test environment.  Comment out the exit line if you know what you're doing."
  exit 1
end

RSpec.configure do |config|
  config.before(:each) do
    @s = MockServer.new
    Libertree::Server.conf = {}
    Libertree::DB.dbh.execute "SET client_min_messages TO 'warning';"
    Libertree::DB.dbh.execute 'TRUNCATE posts CASCADE'
    Libertree::DB.dbh.execute 'TRUNCATE servers CASCADE'
  end

  config.after(:each) do
    @s.unbind
  end
end

shared_context 'requester not in any forest' do
  before :each do
    @requester = Libertree::Model::Server.create( FactoryGirl.attributes_for(:server) )
  end
end

shared_context 'requester in a forest' do
  before :each do
    @forest = Libertree::Model::Forest.create( FactoryGirl.attributes_for(:forest) )
    @requester = Libertree::Model::Server.create( FactoryGirl.attributes_for(:server) )
    @forest.add @requester
  end
end

shared_context 'requester sent INTRODUCE' do
  before :each do
    @s.stub(:challenge_new) { 'abcdefghijklmnopqrstuvwxyz' }
    @s.process %<INTRODUCE { "public_key": #{@requester.public_key.to_json} } >
  end
end

shared_context 'requester sent AUTHENTICATE' do
  before :each do
    @s.process 'AUTHENTICATE { "response": "abcdefghijklmnopqrstuvwxyz" }'
  end
end

shared_context 'with an INTRODUCEd requester' do
  include_context 'requester in a forest'
  include_context 'requester sent INTRODUCE'
end

shared_context 'with an INTRODUCEd unknown requester' do
  include_context 'requester not in any forest'
  include_context 'requester sent INTRODUCE'
end

shared_context 'with an INTRODUCEd and AUTHENTICATEd requester' do
  include_context 'with an INTRODUCEd requester'
  include_context 'requester sent AUTHENTICATE'
end

shared_context 'with an INTRODUCEd and AUTHENTICATEd unknown requester' do
  include_context 'with an INTRODUCEd unknown requester'
  include_context 'requester sent AUTHENTICATE'
end
