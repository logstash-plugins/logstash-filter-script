api_version 1

def on_event(event)
  if event.get("foo") == "bar"
    dead_letter(event, "Foo == bar!")
    []
  else
    [event]
  end
end

scenario "foo=>bar" do
  test_event { Event.new("foo" => "bar") }

  expect("The event to not continue") do |events|
    events.size == 0
  end
end

scenario "foo=>baz" do
  test_event { Event.new("foo" => "baz") }

  assert_on_event("The event to not continue") do |events|
    events.size == 1
  end

end