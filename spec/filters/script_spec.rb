# encoding: utf-8
require_relative '../spec_helper'
require "logstash/filters/script"

describe LogStash::Filters::Script do
  let(:fixtures_path) { File.join(File.dirname(__FILE__), '../fixtures/') }
  let(:script_filename) { 'field_multiplier.rb' }
  let(:script_path) { File.join(fixtures_path, script_filename)}
  let(:script_params) { { 'field' => 'foo', 'multiplier' => 2 } }
  let(:filter_params) { { 'file' => script_path, 'script_params' => script_params} }
  let(:incoming_event) { ::LogStash::Event.new('foo' => 42) }
  
  subject(:filter) { ::LogStash::Filters::Script.new(filter_params) }
  
  describe "basics" do
    it "should register cleanly" do
      expect do
        filter.register
      end.not_to raise_error
    end
    
    describe "filtering" do
      before(:each) do
        filter.register
        filter.filter(incoming_event)
      end
      
      it "should filter data as expected" do
        expect(incoming_event.get('foo')).to eq(84)
      end
    end
    
    describe "flushing" do
      before(:each) do
        filter.register 
      end
      
      subject { filter.flush }
      
      it "should return the flush result" do
        expect(subject.first.get("multiply_flush")).to eq(true)
      end
      
      it "should flush the expected number of events" do 
        expect(subject.size).to eq(1)
      end
    end
  end
  
  describe "scripts with failing test suites" do
    let(:script_filename) { 'broken.rb' }
    
    it "should error out during register" do
      expect do 
        filter.register
      end.to raise_error(LogStash::Filters::Script::ScriptError)
    end
  end
  
  describe "transaction_aggregator.rb" do
    let(:script_filename) { 'transaction_aggregator.rb' }
    
      it "should not error out during register" do
      expect do 
        filter.register
      end.not_to raise_error
    end
  end

  describe "scripts with DLQ tests" do
    let(:script_filename) { 'dead_letter.rb' }

    it "should not error out during register" do
      expect do
        filter.register
      end.not_to raise_error
    end
  end

  describe "scripts with no API Version" do
    let(:script_filename) { 'no_api_version.rb' }

    it "should error out during register" do
      expect do
        filter.register
      end.to raise_error(::LogStash::ConfigurationError)
    end
  end

  describe "scripts with a bad API version" do
    let(:script_filename) { 'bad_api_version.rb' }

    it "should error out during register" do
      expect do
        filter.register
      end.to raise_error(::LogStash::ConfigurationError)
    end
  end
end
