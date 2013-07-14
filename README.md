# Merlion

Merlion is a poker server written in Ruby. It's a work in progress.

It uses:

* [EventMachine](https://github.com/eventmachine/eventmachine)
* WebSockets (via [em-websocket](https://github.com/igrigorik/em-websocket))
* Fibers

I've written a frontend to it called [merlion-web](https://github.com/mcartmell/merlion-web).

You can see it in action, and play against Merlion bots, here: http://poker.mikec.me/

# TODO

* Handle split pots correctly
* Record betting history for current hand
* Record all games in database
* No Limit ages
