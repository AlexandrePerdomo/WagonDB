# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'pages#home'
  post 'convert_from_xml' => 'pages#convert_from_xml'
  post 'convert_from_schema' => 'pages#convert_from_schema'
end
