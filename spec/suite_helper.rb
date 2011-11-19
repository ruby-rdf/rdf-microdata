$:.unshift "."
require 'spec_helper'
require 'spira'
require 'rdf/turtle'
require 'open-uri'

module Fixtures
  module SuiteTest
    class MF < RDF::Vocabulary("http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#"); end
    SUITE_BASE = File.expand_path(File.dirname(__FILE__))  + "/test-suite/"

    class Manifest < Spira::Base
      type MF.Manifest
      property :entry_list, :predicate => MF['entries']
      property :comment,    :predicate => RDFS.comment
    end

    class Entry
      attr_accessor :debug
      attr_accessor :compare
      include Spira::Resource
      type MF["Entry"]

      property :name,     :predicate => MF["name"],         :type => XSD.string
      property :comment,  :predicate => RDF::RDFS.comment,  :type => XSD.string
      property :result,   :predicate => MF.result
      has_many :action,   :predicate => MF["action"]

      def input
        Kernel.open(self.inputDocument.to_s)
      end
      
      def output
        self.result ? Kernel.open(self.result.to_s) : ""
      end

      def inputDocument
        self.class.repository.first_object(:subject => self.action.first)
      end

      def base_uri
        inputDocument.to_s
      end
      
      def inspect
        "[#{self.class.to_s} " + %w(
          subject
          name
          comment
          result
          inputDocument
        ).map {|a| v = self.send(a); "#{a}='#{v}'" if v}.compact.join(", ") +
        "]"
      end
    end

    class Good < Manifest
      default_source :turtle

      def entries
        RDF::List.new(entry_list, self.class.repository).map { |entry| entry.as(GoodEntry) }
      end
    end
    
    class Bad < Manifest
      default_source :turtle_bad

      def entries
        RDF::List.new(entry_list, self.class.repository).map { |entry| entry.as(BadEntry) }
      end
    end

    class GoodEntry < Entry
      default_source :turtle
    end

    class BadEntry < Entry
      default_source :turtle_bad
    end

    # Note that the texts README says to use a different base URI
    tests = RDF::Repository.load(SUITE_BASE + "manifest.ttl")
    Spira.add_repository! :turtle, tests
    
    tests_bad = RDF::Repository.load(SUITE_BASE + "manifest-bad.ttl")
    Spira.add_repository! :turtle_bad, tests_bad
  end
end