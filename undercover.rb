# Created by Eloy Duran (e.duran@superalloy.nl)
# You can redistribute it and/or modify it under the Ruby's license or the GPL2.

require 'xmlrpc/client'
require 'cgi'

class Cia
  SERVER = "cia.vc"
  
  def initialize(data)
    @data = data
  end
  
  def send_commit_messages!
    server = XMLRPC::Client.new(SERVER)
    commit_messages.each { |message| server.call("hub.deliver", message) }
  rescue XMLRPC::FaultException => e
    #puts "XMLRPC Error: #{e.message}"
    # FIXME: Might be GitHub specific
  end
  
  def commit_messages
    @data[:commits].collect do |sha, commit|
      %{
        <message xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="schema.xsd">
          <generator>
            <name>Undercover: CIA Ruby agent for GitHub</name>
            <version>1.0</version>
          </generator>
          <source>
            <project>#{h @data[:repository][:name]}</project>
            <branch>#{h @data[:ref].split('/').last}</branch>
          </source>
          <timestamp>#{h commit[:timestamp].to_i}</timestamp>
          <body>
            <commit>
              <author>#{h commit[:author][:name]} (#{h commit[:author][:email]})</author>
              <revision>#{h sha}</revision>
              <log>#{h commit[:message]}</log>
              <url>#{h commit[:url]}</url>
            </commit>
          </body>
        </message>
      }
    end
  end

  private

  def h(input)
    CGI.escapeHTML(input.to_s)
  end
end

if __FILE__ == $0
  # Sample data taken from a GitHub guide.
  TIMESTAMP = Time.now
  DATA = {
    :before => "5aef35982fb2d34e9d9d4502f6ede1072793222d",
    :repository => {
      :url => "http://github.com/alloy/undercover",
      :name => "undercover",
      :owner => {
        :email => "e.duran@superalloy.nl",
        :name => "alloy"
      }
    },
    :commits => {
      '41a212ee83ca127e3c8cf465891ab7216a705f59' => {
        :url => "http://github.com/alloy/undercover/commit/41a212ee83ca127e3c8cf465891ab7216a705f59",
        :author => {
          :email => "e.duran@superalloy.nl",
          :name => "Eloy Duran"
        },
        :message => "duck for cover",
        :timestamp => TIMESTAMP
      },
      'de8251ff97ee194a289832576287d6f8ad74e3d0' => {
        :url => "http://github.com/alloy/undercover/commit/de8251ff97ee194a289832576287d6f8ad74e3d0",
        :author => {
          :email => "e.duran@superalloy.nl",
          :name => "Eloy Duran"
        },
        :message => "the company posted a message",
        :timestamp => TIMESTAMP
      }
    },
    :after => "de8251ff97ee194a289832576287d6f8ad74e3d0",
    :ref => "refs/heads/master"
  }
  
  # Try it out!
  #
  # cia = Cia.new(DATA)
  # cia.send_commit_messages!
  
  require "test/unit"
  require "rubygems"
  require "mocha"
  require "rexml/document"
  
  class TestUndercover < Test::Unit::TestCase
    def setup
      @cia = Cia.new(DATA)
    end
    
    def test_should_create_a_message_for_each_commit
      assert_equal 2, @cia.commit_messages.length
      @cia.commit_messages.each { |cm| assert_instance_of String, cm }
    end
    
    def test_should_create_xml_which_describes_the_commit
      @cia.commit_messages.each_with_index do |cm, idx|
        @message = REXML::Document.new(cm).root
        
        assert_equal 'undercover', elm('source/project')
        assert_equal 'master',     elm('source/branch')
        
        assert_equal TIMESTAMP.to_i.to_s, elm('timestamp')
        
        sha, commit = DATA[:commits].to_a[idx]
        assert_equal "Eloy Duran (e.duran@superalloy.nl)", elm('body/commit/author')
        assert_equal sha, elm('body/commit/revision')
        assert_equal commit[:message], elm('body/commit/log')
        assert_equal commit[:url], elm('body/commit/url')
      end
    end
    
    def test_should_post_the_commit_messages_to_the_cia_server
      server = mock('CIA XMLRPC Server')
      XMLRPC::Client.expects(:new).with(Cia::SERVER).returns(server)
      @cia.commit_messages.each { |message| server.expects(:call).with('hub.deliver', message) }
      
      @cia.send_commit_messages!
    end
    
    def test_should_not_break_if_a_xmlrpc_exception_occurs
      XMLRPC::Client.stubs(:new).raises XMLRPC::FaultException.new('foo', 'bar')
      assert_nothing_raised(Exception) { @cia.send_commit_messages! }
    end
    
    private
    
    def elm(xpath)
      @message.elements[xpath].text
    end
  end
end
