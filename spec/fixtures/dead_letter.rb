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
  in_event { {"foo" => "bar"} }

  expect("The event to not continue") do |events|
    events.size == 0
  end
end

scenario "foo=>baz" do
  in_event { {"foo" => "baz"} }

  expect("The event to not continue") do |events|
    events.size == 1
  end

end