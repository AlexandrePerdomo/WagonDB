# frozen_string_literal: true

class PagesController < ApplicationController
  require 'nokogiri'

  def home; end

  def convert_from_xml
    @phrases = ConvertXmlToSchema.new(params[:xml]).extract_tables_data
  end

  def convert_from_schema
    @builder = ConvertSchemaToXml.generate_xml_schema(params)
  end
end
