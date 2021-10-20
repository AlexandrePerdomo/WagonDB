# frozen_string_literal: true

# Service to convert XML to rails model generators
class ConvertSchemaToXml
  require 'nokogiri'

  TABLE_NAME_REGEXP = Regexp.new('create_table "(\w{1,200})"')
  ATTRIBUTE_TYPE_NAME_REGEXP = Regexp.new('t[.]([a-z]{1,15})\s{1,10}"{1}(\S{1,200})"{1}')
  FOREIGN_KEY_REGEXP = Regexp.new('add_foreign_key\s{1,15}"{1}(\S{1,100})"{1},\s{1,15}"{1}(\S{1,100})"{1}')
  # FOREIGN_KEY_CUSTOM_NAME_REGEXP = Regexp.new('add_foreign_key\s{1,15}"{1}(\S{1,100})"{1},\s{1,15}"{1}(\S{1,100})"{1}$')

  REMOVE_MODEL_ATTRIBUTES = %w[created_at updated_at]
  REMOVE_DEVISE_ATTRIBUTES = %w[encrypted_password reset_password_token reset_password_sent_at
                                remember_created_at sign_in_count current_sign_in_at last_sign_in_at
                                current_sign_in_ip last_sign_in_ip]

  def self.extract_tables_from_schema(params)
    tables_datas = []
    table = {}
    ref = []
    params[:schema].each_line do |line|
      match_data1 = line.scan(TABLE_NAME_REGEXP)
      match_data2 = line.scan(ATTRIBUTE_TYPE_NAME_REGEXP)
      match_data3 = line.scan(FOREIGN_KEY_REGEXP)
      if match_data1 != []
        tables_datas << table if table != {}
        table = { table_name: match_data1[0][0] }
      elsif match_data2 != []
        column = {
          type: match_data2[0][0],
          name: match_data2[0][1]
        }
        table["column_#{table.length}"] = column
      elsif match_data3 != []
        ref << [match_data3[0][0], match_data3[0][1]]
      end
    end
    tables_datas << table if table != {}
    [tables_datas, ref]
  end

  def self.generate_xml_schema(params)
    tables_datas, ref = extract_tables_from_schema(params)
    model_names = tables_datas.map { |x| x[:table_name] }
    tables_datas.each do |table_data|
      model_name = table_data[:table_name]
      (0..50).each do |count|
        next unless table_data["column_#{count}"]

        attribute_name = table_data["column_#{count}"][:name]
        3.times do
          attribute_name = attribute_name.chop
        end
        model_ref = attribute_name.pluralize
        table_data["column_#{count}"][:references] = model_ref.singularize.camelize if model_names.include? model_ref
      end
    end
    nokogiri_builder(tables_datas)
  end

  def self.nokogiri_builder(tables_datas)
    builder = Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
      xml.sql do
        tables_datas.each_with_index do |table_data, i|
          x = generate_x_position(i)
          y = generate_y_position(tables_datas, i)
          xml.table('x' => x, 'y' => y, 'name' => table_data[:table_name].singularize.camelize) do
            xml.row('name' => 'id', 'null' => '1', 'autoincrement' => '1') do
              xml.datatype 'INTEGER'
              xml.default 'NULL'
            end
            (0..50).each do |i|
              next unless table_data["column_#{i}"]
              next if REMOVE_MODEL_ATTRIBUTES.include? table_data["column_#{i}"][:name]
              next if REMOVE_DEVISE_ATTRIBUTES.include? table_data["column_#{i}"][:name]

              xml.row('name' => table_data["column_#{i}"][:name], 'null' => '1', 'autoincrement' => '0') do
                xml.datatype table_data["column_#{i}"][:type]
                xml.default 'NULL'
                if table_data["column_#{i}"][:references]
                  xml.relation('table' => table_data["column_#{i}"][:references], 'row' => 'id')
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
    builder.to_xml
  end

  def self.generate_x_position(i)
    25 + 300 * (i%4)
  end

  def self.generate_y_position(table_datas, i)
    table_keys = []
    while i > 0 do
      i -= 4
      table_keys << i if i >= 0
    end
    y = 0
    table_keys.each do |table_key|
      y += table_datas[table_key].length * 25
    end
    y
  end
end
