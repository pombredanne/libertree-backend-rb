require 'spec_helper'
require 'net/http'

describe Libertree::Server::Responder::Member do
  describe 'rsp_member' do
    include_context 'with an INTRODUCEd and AUTHENTICATEd requester'

    context 'and the member is known' do
      before :each do
        @member = Libertree::Model::Member.create(
          FactoryGirl.attributes_for(:member, :server_id => @requester.id)
        )

        Libertree::Server.stub(:conf) { Hash.new }
        Net::HTTP.any_instance.stub(:get)
        Net::HTTPResponse.any_instance.stub(:body)
        Socket.stub(:getaddrinfo) { [ [nil,nil,nil,@requester.ip] ] }
        File.stub(:open)
      end

      it 'with a missing username it responds with MISSING PARAMETER' do
        h = {
          'avatar_url' => 'http://libertree.net/images/avatars/1.png',
          'profile' => {
            'name_display' => '',
            'description'  => '',
          }
        }
        @s.process "MEMBER #{h.to_json}"
        @s.should have_responded_with_code('MISSING PARAMETER')
      end

      it 'with a blank username it responds with MISSING PARAMETER' do
        h = {
          'username' => '',
          'avatar_url' => 'http://libertree.net/images/avatars/1.png',
          'profile' => {
            'name_display' => '',
            'description'  => '',
          }
        }
        @s.process "MEMBER #{h.to_json}"
        @s.should have_responded_with_code('MISSING PARAMETER')
      end

      it 'with a blank profile display name, it responds with ERROR' do
        h = {
          'username' => 'someuser',
          'avatar_url' => 'http://libertree.net/images/avatars/1.png',
          'profile' => {
            'name_display' => '',
            'description'  => '',
          }
        }
        @s.process "MEMBER #{h.to_json}"
        @s.should have_responded_with_code('ERROR')
      end

      it 'with valid data it responds with OK' do
        h = {
          'username' => 'someuser',
          'avatar_url' => 'http://libertree.net/images/avatars/1.png',
          'profile' => {
            'name_display' => 'Some User',
            'description'  => '',
          }
        }
        @s.process "MEMBER #{h.to_json}"
        @s.should have_responded_with_code('OK')
      end
    end
  end
end
