# Aggregates transactions into a single event
# Takes as a parameter the amount of time to wait beforing flushing an
# incomplete transaction

api_version 1

def setup(params)
  @transactions = Hash.new do |h,k| 
    h[k] = {
      :id => k, 
      :last_updated => nil, 
      :parts => [], 
      :total_parts => nil
    }
  end
  @flush_idle_after = params["flush_idle_after"] || 300 # Seconds
end

def on_event(event)
  transaction_id = event.get("transaction_id")
  
  return [event] unless transaction_id
  
  transaction = @transactions[transaction_id]
  transaction[:parts] << event
  transaction[:last_updated] = Time.now
  
  if event.get('transaction_total_parts')
    transaction[:total_parts] = event.get('transaction_total_parts')
  end
  
  if transaction[:total_parts] && transaction[:parts].size == transaction[:total_parts]
    event = finalize_transaction(transaction)
    # Implicit return
    [event]
  else
    # Implicit return
    []
  end
end

def flush(final)
  cutoff = Time.now - @flush_idle_after
  
  flushed_events = []
  @transactions.each do |id, transaction|
    # On final flush flush everything
    # Otherwise, wait till the cutoff has been passed
    if final || transaction[:last_updated] < cutoff
      flushed_events << finalize_transaction(transaction)
    end
  end
  
  flushed_events
end

def finalize_transaction(transaction)
  result = Event.new
  
  transaction_parts = @transactions[transaction[:id]][:parts]
  
  result.set('transaction_id', transaction[:id])
  
  sorted_events = transaction_parts.sort do |a,b| 
    a.get('transaction_sequence') <=> b.get('transaction_sequence')
  end
  result.set('parts', sorted_events.map(&:to_hash))
  
  @transactions.delete(transaction[:id])
  
  result
end

scenario "aggregating a transaction" do
  test_options do 
    # We make everything expired so that in tests the flush affects everything
    # That wasn't handled by the filter function
    { "flush_idle_after" => -1 }
  end
  
  test_events do 
    [
      Event.new("transaction_id" => 123, "transaction_total_parts" => 2, "message" => "Uno"),
      Event.new("transaction_id" => 123, "message" => "Dos"),
      Event.new("transaction_id" => 456, "transaction_total_parts" => 2, "message" => "Ein")
    ]
  end
  
  assert_on_event("There to be one out event") do |events| 
    events.size == 1
  end
  
  assert_on_event("Single out event to have 2 parts") do |events| 
    events.first.get("parts").size == 2
  end
  
  assert_on_event("The parts to be in order") do |events|
    parts = events.first.get("parts")
    parts[0]["message"] == "Uno"
    parts[1]["message"] == "Dos"
  end
  
  expect("To return the incomplete, but expired, message") do |events,flushed_events|
    flushed_events.first.get("parts").first["message"]
  end
end
