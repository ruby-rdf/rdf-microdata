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
      include Spira::Resource
      type MF["ManifestEntry"]

      property :name,     :predicate => MF["name"],         :type => XSD.string
      property :comment,  :predicate => RDF::RDFS.comment,  :type => XSD.string
      has_many :action,   :predicate => MF["action"]
      property :result,   :predicate => MF.result
      property :registry, :predicate => MF.registry

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
    
    class GoodEntry < Entry
      default_source :turtle
    end

    # Note that the texts README says to use a different base URI
    tests = RDF::Repository.load(SUITE_BASE + "index.html")
    Spira.add_repository! :turtle, tests
    STDERR.puts "Loaded #{tests.count} triples: #{tests.dump(:ttl)}"
  end
end