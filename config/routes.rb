Rails.application.routes.draw do
  root to: "pages#home"
  post 'xml' => "pages#convert_from_xml"
  post 'schema' => "pages#convert_from_schema"
end
