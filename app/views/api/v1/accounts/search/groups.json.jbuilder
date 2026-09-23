json.payload do
  json.groups do
    json.array! @result[:groups] do |group|
      json.partial! 'group', formats: [:json], group: group
    end
  end
end
