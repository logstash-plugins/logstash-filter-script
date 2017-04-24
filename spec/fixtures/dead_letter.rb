api_version 1

filter do |event|
  if event.get("foo") == "bar"
    dead_letter(event, "Foo == bar!")
    []
  else
    [event]
  end
end

test "foo=>bar" do
  in_event { {"foo" => "bar"} }

  expect("The event to not continue") do |events|
    events.size == 0
  end
end

test "foo=>baz" do
  in_event { {"foo" => "baz"} }

  expect("The event to not continue") do |events|
    events.size == 1
  end

end