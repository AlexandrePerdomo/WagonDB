# frozen_string_literal: true

# Test service to convert XML to rails model generators
require 'test_helper'

class ConvertXmlToSchemaTest < ActiveSupport::TestCase
  context '#extract_tables_data without xml' do
    should 'should return empty array' do
      assert_equal ConvertXmlToSchema.new('').extract_tables_data, []
    end
  end

  context '#extract_tables_data with xml' do
    setup do
      file = File.open("#{Rails.root}/test/services/xml_example.xml")
      @convertissor = ConvertXmlToSchema.new(file)
    end

    should 'should return phrases' do
      phrases = @convertissor.extract_tables_data
      assert_not_equal phrases, []
      assert_equal phrases[0],
                   'rails g model User first_name:string last_name:string birth_date:date hours:time alive:boolean'
      assert_equal phrases[1], 'rails g model Horse user:references'
    end
  end
end
