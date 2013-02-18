-module(splunk).

-export([send/1]).

send(Payload) ->
    splunk_serv:send(Payload).
