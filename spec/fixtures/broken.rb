api_version 1

def on_event(event)
  event.set('foo', 'bar')
  [event]
end

scenario "setting the field" do
  in_event { { "myfield" => 123 } }
  
  # This should fail!
  expect("foo to equal baz") do |events| 
    events.first.get('foo') == 'baz'
  end
end
