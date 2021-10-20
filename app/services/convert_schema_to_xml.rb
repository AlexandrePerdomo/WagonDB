# frozen_string_literal: true

# Service to convert XML to rails model generators
class ConvertSchemaToXml
  require 'nokogiri'

  TABLE_NAME_REGEXP = Regexp.new('create_table "(\w{1,200})"')
  ATTRIBUTE_TYPE_NAME_REGEXP = Regexp.new('t[.]([a-z]{1,15})\s{1,10}"{1}(\S{1,200})"{1}')
  # FOREIGN_KEY_REGEXP = Regexp.new(
  #   'add_foreign_key\s{1,15}"{1}(\S{1,100})"{1},\s{1,15}"{1}(\S{1,100})"{1}'
  # )
  # FOREIGN_KEY_CUSTOM_NAME_REGEXP = Regexp.new(
  #   'add_foreign_key\s{1,15}"{1}(\S{1,100})"{1},\s{1,15}"{1}(\S{1,100})"{1}$'
  # )

  REMOVE_TIMESTAMPS_ATTRIBUTES = %w[created_at updated_at].freeze
  REMOVE_DEVISE_ATTRIBUTES = %w[encrypted_password reset_password_token reset_password_sent_at
                                remember_created_at sign_in_count current_sign_in_at last_sign_in_at
                                current_sign_in_ip last_sign_in_ip confirmation_token confirmed_at
                                confirmation_sent_at unconfirmed_email].freeze

  def self.extract_tables_from_schema(params)
    tables_datas = []
    table = {}
    params[:schema].each_line do |line|
      match_data1 = line.scan(TABLE_NAME_REGEXP)
      match_data2 = line.scan(ATTRIBUTE_TYPE_NAME_REGEXP)
      table, tables_datas = get_table_name_and_attributes(match_data1[0], match_data2[0], table, tables_datas)
    end
    tables_datas
  end

  def self.get_table_name_and_attributes(match_data1, match_data2, table, tables_datas)
    if !match_data1.nil?
      table = { table_name: match_data1[0] }
    elsif !match_data2.nil?
      return [table, tables_datas] if remove_attributes(match_data2[1])

      table["column_#{table.length}"] = { type: match_data2[0], name: match_data2[1] }
    elsif table != {}
      tables_datas << table
      table = {}
    end
    [table, tables_datas]
  end

  def self.remove_attributes(attribute_name)
    (REMOVE_TIMESTAMPS_ATTRIBUTES.include? attribute_name) || (REMOVE_DEVISE_ATTRIBUTES.include? attribute_name)
  end

  def self.generate_xml_schema(params)
    tables_datas = extract_tables_from_schema(params)
    model_names = tables_datas.map { |x| x[:table_name] }
    tables_datas = generate_references(tables_datas, model_names)
    nokogiri_builder(tables_datas)
  end

  def self.generate_references(tables_datas, model_names)
    tables_datas.each do |table_data|
      (0..50).each do |count|
        next unless table_data["column_#{count}"]

        model_ref = table_data["column_#{count}"][:name][0...-3].pluralize
        table_data["column_#{count}"][:references] = model_ref.singularize.camelize if model_names.include? model_ref
      end
    end
    tables_datas
  end

  def self.nokogiri_builder(tables_datas)
    builder = Nokogiri::XML::Builder.new(encoding: 'utf-8') do |xml|
      xml.sql do
        tables_datas.each_with_index do |table_data, table_position|
          x = generate_x_position(table_position)
          y = generate_y_position(tables_datas, table_position)
          xml.table('x' => x, 'y' => y, 'name' => table_data[:table_name].singularize.camelize) do
            xml.row('name' => 'id', 'null' => '1', 'autoincrement' => '1') do
              xml.datatype 'INTEGER'
              xml.default 'NULL'
            end
            (0..50).each do |i|
              next unless table_data["column_#{i}"]

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

  def self.generate_x_position(table_position, columns = 4)
    25 + 300 * (table_position % columns)
  end

  def self.generate_y_position(table_datas, table_position, columns = 4)
    table_keys = []
    while table_position.positive?
      table_position -= columns
      table_keys << table_position if table_position >= 0
    end
    y = 0
    table_keys.each do |table_key|
      y += ((table_datas[table_key].length + 1) * 20 + 30)
    end
    y
  end
end
