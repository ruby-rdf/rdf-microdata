# coding: utf-8
$:.unshift "."
require 'spec_helper'
require 'rdf/spec/format'

describe RDF::Microdata::Format do
  it_behaves_like 'an RDF::Format' do
    let(:format_class) {RDF::Microdata::Format}
  end

  describe ".for" do
    formats = [
      :microdata,
      'etc/doap.html',
      {:file_name      => 'etc/doap.html'},
      {file_extension: 'html'},
      {:content_type   => 'text/html'},
    ].each do |arg|
      it "discovers with #{arg.inspect}" do
        expect([RDF::Microdata::Format, RDF::RDFa::Format]).to include RDF::Format.for(arg)
      end
    end

    {
      microdata: '<div itemref="bar"></div>',
    }.each do |sym, str|
      it "detects #{sym}" do
        expect(described_class.for {str}).to eq described_class
      end
    end
  end

  describe "#to_sym" do
    specify {expect(described_class.to_sym).to eq :microdata}
  end

  describe ".detect" do
    {
      itemprop:  '<div itemprop="bar"></div>',
      itemtype:  '<div itemtype="bar"></div>',
      itemref:   '<div itemref="bar"></div>',
      itemscope: '<div itemscope=""></div>',
      itemid:    '<div itemid="bar"></div>',
    }.each do |sym, str|
      it "detects #{sym}" do
        expect(described_class.detect(str)).to be_truthy
      end
    end

    {
      :n3             => "@prefix foo: <bar> .\nfoo:bar = {<a> <b> <c>} .",
      nquads: "<a> <b> <c> <d> . ",
      rdfxml: '<rdf:RDF about="foo"></rdf:RDF>',
      jsonld: '{"@context" => "foo"}',
      :about    => '<div about="foo"></div>',
      :typeof   => '<div typeof="foo"></div>',
      resource: '<div resource="foo"></div>',
      :vocab    => '<div vocab="foo"></div>',
      :prefix   => '<div prefix="foo"></div>',
      property: '<div property="foo"></div>',
      :ntriples         => "<a> <b> <c> .",
      :multi_line       => '<a>\n  <b>\n  "literal"\n .',
      :turtle           => "@prefix foo: <bar> .\n foo:a foo:b <c> .",
      :STRING_LITERAL1  => %(<a> <b> 'literal' .),
      :STRING_LITERAL2  => %(<a> <b> "literal" .),
      :STRING_LITERAL_LONG1  => %(<a> <b> '''\nliteral\n''' .),
      :STRING_LITERAL_LONG2  => %(<a> <b> """\nliteral\n""" .),
    }.each do |sym, str|
      it "does not detect #{sym}" do
        expect(described_class.detect(str)).to be_falsey
      end
    end
  end
end
