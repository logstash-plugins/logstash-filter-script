# You *must* declare the API version this script is written to
# This prevents scripts from incorrectly running under other API versions
api_version 1

# Disables mutex around the `filter` function
# Only use this if you know your code is threadsafe!
concurrency :shared 

def setup(params)
  @field = params['field']
  @multiplier = params['multiplier']
end

def on_event(event)
  event.set(@field, event.get(@field) * @multiplier)
  # Filter blocks must return any events that are to be passed on
  # return a nil or [] here if all events are to be cancelled
  # You can even return one or more brand new events here!
  [event]
end

# This is just here to show how the flush function works
# It just creates a meaningless event
def flush(final)
  [::LogStash::Event.new("multiply_flush" => true)]
end

scenario "standard flow" do
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
