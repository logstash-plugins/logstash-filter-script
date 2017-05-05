api_version 1

def on_event(event)
  event.set('foo', 'bar')
  [event]
end

scenario "setting the field" do
  test_event { Event.new("myfield" => 123) }
  
  # This should fail!
  assert_on_event("foo to equal baz") do |events| 
    events.first.get('foo') == 'baz'
  end
end
