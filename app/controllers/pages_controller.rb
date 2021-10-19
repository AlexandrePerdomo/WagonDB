# frozen_string_literal: true

class PagesController < ApplicationController
  require 'nokogiri'

  def home; end

  def convert_from_xml
    @phrases = ConvertXmlToSchema.new(params[:xml]).extract_tables_data
  end

  def convert_from_schema
    models = []
    table = {}
    ref = []
    tables_avec_references = []
    count_table = 0
    params[:schema].each_line do |line|
      # Ligne 1 permet de choper le nom de la table
      match_data1 = line.scan(/[create]{6}_{1}[table]{5}.{1}"{1}(.{1,200})"{1}/)
      # Ligne 2 permet de choper le t.info + nom de la colonne
      match_data2 = line.scan(/t[.]([a-z]{1,15})\s{1,10}"{1}(\S{1,200})"{1}/)
      # Permet de matcher avec add_foreign_key et de choper les 2 tables liées
      match_data3 = line.scan(/[add]{3}_{1}[foreign]{7}_{1}[key]{3}\s{1,15}"{1}(\S{1,100})"{1},\s{1,15}"{1}(\S{1,100})"{1}/)
      if match_data1 != []
        models << table if table != {}
        count_table = 0
        table = {}
        table[:table_name] = match_data1[0][0]
      elsif match_data2 != []
        column = {}
        count_table += 1
        column[:type] = match_data2[0][0]
        column[:name] = match_data2[0][1]
        table["column_#{count_table}"] = column
      elsif match_data3 != []
        ref << [match_data3[0][0], match_data3[0][1]]
      end
    end
    models << table if table != {}
    models.each_with_index do |model, _i|
      model_name = model[:table_name]
      (0..50).each do |i|
        next unless model["column_#{i}"]

        name = model["column_#{i}"][:name]
        3.times do
          name = name.chop
        end
        model_ref = name.pluralize
        model["column_#{i}"][:references] = model_ref if ref.include? [model_name, model_ref]
      end
    end
    builder = Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
      xml.sql do
        models.each_with_index do |model, i|
          y = (i + 1) / 4 * 100
          if ((i + 1) % 4).zero?
            x = 950
          elsif ((i + 1) % 3).zero?
            x = 650
          elsif (i + 1).even?
            x = 350
          elsif ((i + 1) % 1).zero?
            x = 50
          end
          xml.table('x' => x, 'y' => y, 'name' => model[:table_name]) do
            xml.row('name' => 'id', 'null' => '1', 'autoincrement' => '1') do
              xml.datatype 'INTEGER'
              xml.default 'NULL'
            end
            (0..50).each do |i|
              next unless model["column_#{i}"]

              xml.row('name' => model["column_#{i}"][:name], 'null' => '1', 'autoincrement' => '0') do
                xml.datatype model["column_#{i}"][:type]
                xml.default 'NULL'
                if model["column_#{i}"][:references]
                  xml.relation('table' => model["column_#{i}"][:references], 'row' => 'id')
                end
              end
            end
            xml.key('type' => 'PRIMARY', 'name' => '') do
              xml.part 'id'
            end
          end
        end
      end
    end
    @builder = builder.to_xml
  end
end
