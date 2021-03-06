require 'spec_helper'

describe Libertree::Server::Responder::Dispatcher do
  describe 'process' do
    it 'responds to malformed requests' do
      @s.process "malformed"
      @s.should have_responded_with_code('BAD REQUEST')
    end

    it 'responds to requests with non-JSON parameters' do
      @s.process 'SOME-COMMAND invalid;JSON'
      @s.should have_responded_with_code('BAD PARAMETER')
      @s.response['message'].should =~ /unexpected token at 'invalid;JSON'/
    end

    it 'responds to unknown commands' do
      @s.process 'NO-SUCH-COMMAND { "data": "foo" }'
      @s.should have_responded_with_code('UNKNOWN COMMAND')
    end

    context 'when the requester has not INTRODUCEd itself' do
      it 'returns ERROR for all commands besides INTRODUCE' do
        commands = Libertree::Server::Responder::Dispatcher::VALID_COMMANDS - ['INTRODUCE',]
        commands.each do |command|
          @s.process %|#{command} { "anything": "anything" }|
          @s.should have_responded_with_code('ERROR')
          @s.response['message'].should =~ /introduce/i
        end
      end
    end

    context 'when the requester has INTRODUCEd but not AUTHENTICATEd itself' do
      include_context 'with an INTRODUCEd requester'

      it 'returns ERROR' do
        commands = Libertree::Server::Responder::Dispatcher::VALID_COMMANDS - ['INTRODUCE', 'AUTHENTICATE',]
        commands.each do |command|
          @s.process %|#{command} { "anything": "anything" }|
          @s.should have_responded_with_code('ERROR')
          @s.response['message'].should =~ /authenticate/i
        end
      end
    end

    context "when the requester is not a member of any of the receiver's forests" do
      include_context 'with an INTRODUCEd and AUTHENTICATEd unknown requester'

      it 'responds with UNRECOGNIZED SERVER' do
        @s.stub(:challenge_new) { 'abcdefghijklmnopqrstuvwxyz' }
        commands = Libertree::Server::Responder::Dispatcher::VALID_COMMANDS - ['INTRODUCE', 'AUTHENTICATE', 'FOREST',]
        commands.each do |command|
          @s.process %|#{command} { "anything": "anything" }|
          @s.should have_responded_with_code('UNRECOGNIZED SERVER')
        end
      end

      it 'does not respond with UNRECOGNIZED SERVER to FOREST commands' do
        @s.stub(:challenge_new) { 'abcdefghijklmnopqrstuvwxyz' }
        @s.process %|FOREST { "anything": "anything" }|
        @s.should_not have_responded_with_code('UNRECOGNIZED SERVER')
      end
    end
  end
end
