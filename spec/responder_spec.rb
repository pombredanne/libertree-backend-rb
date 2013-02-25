require 'blather'
require 'spec_helper'
require 'libertree/client'

describe Libertree::Server::Responder do
  let(:helper_class) { Class.new }
  let(:helper) { helper_class.new }
  LSR = Libertree::Server::Responder

  before :each do
    helper_class.class_eval {
      include Libertree::XML::Helper
      include LSR::Helper
    }
    @server = mock
    @server.stub :id
  end

  it 'rejects unsupported iq stanzas with "UNKNOWN COMMAND"' do
    msg = Blather::Stanza::Iq.new :set
    response = LSR.error code: 'UNKNOWN COMMAND'

    c = LSR.send :client
    LSR.should_receive(:respond) do |args|
      args[:to].should eq msg
      args[:with].to_s.should eq response.to_s
    end

    c.send :call_handler_for, :iq, msg
  end

  it 'responds with "MISSING PARAMETER" when a handler throws MissingParameter' do
    msg = helper.build_stanza( "localhost.localdomain",
                               { 'post' => { 'id' => 10 }} )
    msg.from = "test.localdomain"
    response = LSR.error({ :code => 'MISSING PARAMETER',
                           :text => 'username'
                         })

    c = LSR.send :client
    LSR.should_receive(:respond) do |args|
      args[:to].should eq msg
      args[:with].to_s.should eq response.to_s
    end

    # handler throws :halt to prevent falling through to the catch-all handler
    catch(:halt) { c.send :call_handler_for, :iq, msg }
  end

  it 'responds with "NOT FOUND" when a handler throws NotFound' do
    h = { 'comment' => {
        'id'         => 999,
        'username'   => 'nosuchusername',
        'public_key' => "WHATEVER",
        'post_id'    => 1234,
        'text'       => 'A test comment.',
      }}

    subject.instance_variable_set(:@server, @server)

    msg = helper.build_stanza( "localhost.localdomain", h )
    msg.from = "test.localdomain"
    response = LSR.error({ :code => 'NOT FOUND',
                           :text => 'Unrecognized member username: "nosuchusername"'})

    c = LSR.send :client
    LSR.should_receive(:respond) do |args|
      args[:to].should eq msg
      args[:with].to_s.should eq response.to_s
    end

    # handler throws :halt to prevent falling through to the catch-all handler
    catch(:halt) { c.send :call_handler_for, :iq, msg }
  end

  it 'handles invalid stanzas gracefully' do
    pending "upstream bug?"
    #c = LSR.send(:client)
    #expect { c.receive_data "hello" }.
    #  not_to raise_error
  end

  describe 'respond' do
    it 'writes a reply to the stream' do
      msg = Blather::Stanza::Iq.new :set
      c = LSR.send(:client)
      c.should_receive(:write)
      LSR.respond to: msg
    end

    it 'appends a given XML node to the reply' do
      msg = Blather::Stanza::Iq.new :set
      node = Nokogiri::XML.fragment "<custom>whatever</custom>"
      reply = msg.reply
      reply.add_child node

      c = LSR.send :client
      c.should_receive(:write).with reply
      LSR.respond to: msg, with: node
    end
  end

  describe 'process' do
    it 'calls valid commands with parameters' do
      xml = Nokogiri::XML.fragment helper.params_to_xml({ 'id' => 10 })
      hash = helper.xml_to_hash xml
      LSR.should_receive(:rsp_post).with(hash)
      LSR.process("post", xml)
    end

    it 'converts commands with dashes to method names with underscores' do
      xml = Nokogiri::XML.fragment helper.params_to_xml({ 'id' => 10 })
      hash = helper.xml_to_hash xml
      LSR.should_receive(:rsp_post_like_delete).with(hash)
      LSR.process("post-like-delete", xml)
    end
  end

  describe 'error' do
    it 'builds an XML document with the given error code' do
      err = LSR.error( code: "SOME CODE" ).
        serialize(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
      err.should eq "<error><code>SOME CODE</code></error>"
    end

    it 'builds an XML document with the given error message' do
      err = LSR.error( code: "ERROR", text: "Some message" ).
        serialize(:save_with => Nokogiri::XML::Node::SaveOptions::AS_XML)
      err.should eq "<error><code>ERROR</code><text>Some message</text></error>"
    end
  end
end