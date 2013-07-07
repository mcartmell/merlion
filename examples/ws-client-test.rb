require 'faye/websocket'
require 'eventmachine'

EM.run {
  ws = Faye::WebSocket::Client.new('ws://127.0.0.1:11111/')

  ws.on :open do |event|
    p [:open]
    ws.send('list')
  end

  ws.on :message do |event|
    puts event.data
  end

  ws.on :close do |event|
    p [:close, event.code, event.reason]
    ws = nil
  end
}
