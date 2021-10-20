# frozen_string_literal: true

# Service to convert XML to rails model generators
class ConvertXmlToSchema
  require 'nokogiri'

  NUMERIC_EQUIVALENCE = {
    "INTEGER": 'integer',
    'INT': 'integer',
    'TINYINT': 'integer',
    'MEDIUMINT': 'integer',
    "SMALLINT": 'integer',
    "BIGINT": 'integer',
    "DECIMAL": 'decimal',
    "SERIAL": 'integer',
    "BIGSERIAL": 'integer',
    "FLOAT": 'float',
    "DOUBLE": 'integer',
    'Single precision': 'integer',
    'Double precision': 'integer',
    'ENUM': 'integer'
  }.freeze

  CHARACTER_EQUIVALENCE = {
    "CHAR": 'string',
    "VARCHAR": 'string',
    "TEXT": 'text',
    "BYTEA": 'string',
    'BINARY': 'boolean',
    "BOOLEAN": 'boolean',
    'VARBINARY': 'boolean'
  }.freeze

  DATE_EQUIVALENCE = {
    "DATE": 'date',
    "TIME": 'time',
    "TIME WITH TIME ZONE": 'time',
    "INTERVAL": 'timestamp',
    "TIMESTAMP": 'timestamp',
    "TIMESTAMP WITH TIME ZONE": 'datetime',
    "TIMESTAMP WITHOUT TIME ZONE": 'datetime'
  }.freeze

  XML_PG_EQUIVALENCE = [NUMERIC_EQUIVALENCE, DATE_EQUIVALENCE, CHARACTER_EQUIVALENCE].inject(&:merge)

  REMOVED_MODEL_ATTRIBUTES = %w[id created_at updated_at].freeze

  def initialize(xml_file)
    @document = Nokogiri::XML(xml_file)
  end

  def extract_tables_data
    return [] unless @document.root

    datas = []
    @document.root.xpath('table').each do |table|
      datas << extract_table_data(table)
    end

    extract_phrases(datas)
  end

  private

  def extract_phrases(datas)
    table_names, phrases = Array.new(2) { [] }
    500.times do
      datas.each_with_index do |data, i|
        next unless data[:depend] - table_names == []

        phrases << data[:phrase]
        table_names << data[:name]
        datas.delete_at(i)
      end
    end
    phrases
  end

  def extract_attribute_name(row)
    row.attr('name')
  end

  def extract_relation(row)
    row.at('relation').nil? ? nil : row.at('relation').attr('table')
  end

  def extract_datatype(row)
    XML_PG_EQUIVALENCE[row.xpath('datatype').text.to_sym] || 'string'
  end

  def generate_model_creation_sentence(table, table_attributes, table_relations, table_datatypes)
    phrase = "rails g model #{table['name']}"
    table_attributes.each_with_index do |attribute_name, i|
      attribute_sentence = if table_relations[i].nil?
                             " #{attribute_name}:#{table_datatypes[i].downcase}"
                           else
                             " #{attribute_name[0...-3]}:references"
                           end
      phrase += attribute_sentence
    end
    phrase
  end

  def extract_table_data(table)
    table_attributes, table_relations, table_datatypes = Array.new(3) { [] }
    table.xpath('row').each_with_index do |row, _i|
      next if REMOVED_MODEL_ATTRIBUTES.include? row.attr('name')

      table_attributes << extract_attribute_name(row)
      table_relations << extract_relation(row)
      table_datatypes << extract_datatype(row)
    end
    table_relations.delete_if(&:nil?)
    { name: table['name'], depend: table_relations,
      phrase: generate_model_creation_sentence(table, table_attributes, table_relations, table_datatypes) }
  end
end
