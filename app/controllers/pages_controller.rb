class PagesController < ApplicationController
  require 'nokogiri'

  def home
  end

  def convert_from_xml
    @phrases = []
    #Ouverture du XML
    document = Nokogiri::XML(params[:xml])
    #Analyse du XML
    final = []
    return unless document.root
    document.root.xpath('table').each do |table|
      column_name = []
      relation_with = []
      datatype = []
      hash = {}
      table.xpath('row').each_with_index do |row, i|
        #On supprime la colonne id car on ne la veut pas
        if row['name'] != "id"
          column_name[i] = row.attr('name')
          datatype[i] = row.xpath('datatype').text
          relation_with[i] = row.at('relation') != nil ? row.at('relation').attr('table') : nil
        else
          column_name[i] = nil
          relation_with[i] = nil
        end
      end
      #Conversion type donnée DB vers ceux de PG
      datatype.each_with_index do |type, i|
        datatype[i] = "string" if type == "CHAR"
        datatype[i] = "string" if type == "VARCHAR"
        datatype[i] = "integer" if type == "TINYINT"
        datatype[i] = "integer" if type == "SMALLINT"
        datatype[i] = "integer" if type == "MEDIUMINT"
        datatype[i] = "integer" if type == "INT"
        datatype[i] = "integer" if type == "BIGINT"
        datatype[i] = "integer" if type == "DECIMAL"
        datatype[i] = "integer" if type == "Single precision"
        datatype[i] = "integer" if type == "Double precision"
        datatype[i] = "datetime" if type == "YEAR"
        datatype[i] = "integer" if type == "TIMESTAMP"
        datatype[i] = "boolean" if type == "BINARY"
        datatype[i] = "boolean" if type == "VARBINARY"
        datatype[i] = "integer" if type == "ENUM"
      end
      #Type de données ok, on réunit tout dans un array
      table_complete = []
      column_name.each_with_index do |name, i|
        next if name == nil
        if relation_with[i] == nil
          table_complete[i] = name + ":" + datatype[i].downcase
        else
          3.times do
            name = name.chop
          end
          table_complete[i] = name + ":references"
        end
      end

      phrase = ""
      table_complete.each do |x|
        phrase = phrase + " " + "#{x}"
      end
      relation_with.delete_if {|relation| relation == nil }
      hash = {:name =>table["name"], :phrase => "rails g model #{table["name"]}#{phrase}", :depend =>relation_with}
      final << hash
      p column_name
      p table_complete
    end
    table_crées = []
    count = 0
    while (final.count != 0 && count < 1000)
      final.each_with_index do |x, index|
        if x[:depend] - table_crées == []
          @phrases << x[:phrase]
          table_crées << x[:name]
          final.delete_at(index)
        end
      end
      count += 1
    end
  end

  def convert_from_schema
    models = []
    table = {}
    ref = []
    tables_avec_references = []
    count_table = 0
    params[:schema].each_line do |line|
      #Ligne 1 permet de choper le nom de la table
      match_data1 = line.scan(/[create]{6}[_]{1}[table]{5}.{1}["]{1}(.{1,200})["]{1}/)
      #Ligne 2 permet de choper le t.info + nom de la colonne
      match_data2 = line.scan(/[t][.]([a-z]{1,15})\s{1,10}["]{1}(\S{1,200})["]{1}/)
      #Permet de matcher avec add_foreign_key et de choper les 2 tables liées
      match_data3 = line.scan(/[add]{3}[_]{1}[foreign]{7}[_]{1}[key]{3}[\s]{1,15}["]{1}(\S{1,100})["]{1}[,][\s]{1,15}["]{1}(\S{1,100})["]{1}/)
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
    models.each_with_index do |model,i|
      model_name = model[:table_name]
      for i in 0..50
        if model["column_#{i}"]
          name = model["column_#{i}"][:name]
          3.times do
            name = name.chop
          end
          model_ref = name.pluralize
          if ref.include? [model_name, model_ref]
            model["column_#{i}"][:references] = model_ref
          end
        end
      end
    end
    builder = Nokogiri::XML::Builder.new(:encoding => 'utf-8') do |xml|
      xml.sql {
        models.each_with_index do |model, i|
          y = (i+1)/4*100
          if (i+1)%4 == 0
            x = 950
          elsif (i+1)%3 == 0
            x = 650
          elsif (i+1)%2 == 0
            x = 350
          elsif (i+1)%1 == 0
            x = 50
          end
          xml.table('x' => x, 'y' => y, 'name' => model[:table_name]){
            xml.row('name' => "id", 'null' => "1", 'autoincrement' => "1"){
              xml.datatype "INTEGER"
              xml.default "NULL"
            }
            for i in 0..50
              if model["column_#{i}"]
                xml.row('name' => model["column_#{i}"][:name], 'null' => "1", 'autoincrement' => "0"){
                  xml.datatype model["column_#{i}"][:type]
                  xml.default "NULL"
                  if model["column_#{i}"][:references]
                    xml.relation('table' => model["column_#{i}"][:references], 'row' => "id")
                  end
                }
              end
            end
            xml.key('type' => "PRIMARY", 'name'=> ""){
              xml.part "id"
            }
          }
        end
      }
    end
    @builder = builder.to_xml
  end

end



