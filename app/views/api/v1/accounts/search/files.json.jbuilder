json.payload do
  json.files do
    json.array! @result[:files] do |attachment|
      json.partial! 'file', formats: [:json], attachment: attachment
    end
  end
end
