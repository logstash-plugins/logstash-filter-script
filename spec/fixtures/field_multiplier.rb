concurrency :shared 

register do |params|
  @field = params['field']
  @multiplier = params['multiplier']
end

filter do |event|
  event.set(@field, event.get(@field) * @multiplier)
  # Filter blocks must return any events that are to be passed on
  # return a nil or [] here if all events are to be cancelled
  # You can even return one or more brand new events here!
  [event]
end

# This is just here to show how the flush function works
# It just creates a meaningless event
flush do
  [::LogStash::Event.new("multiply_flush" => true)]
end

test "standard flow" do
  parameters do 
    { "field" => "myfield", "multiplier" => 3 }
  end
  
  in_event { { "myfield" => 123 } }
  
  expect("there to be only one result event") do |events| 
    events.size == 1
  end
  
  expect("result to be equal to 123*3(369)") do |events| 
    events.first.get("myfield") == 369
  end
end
