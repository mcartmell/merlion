# Merlion

Merlion is a poker server written in Ruby. It's a work in progress.

It uses:

* [EventMachine](https://github.com/eventmachine/eventmachine)
* WebSockets (via [em-websocket](https://github.com/igrigorik/em-websocket))
* Fibers

# TODO

* Handle split pots correctly
* Check that win amount is right
* Record betting history for current hand
* Record all games in database
* Run on Heroku
