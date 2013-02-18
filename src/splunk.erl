-module(splunk).

-export([access_common/1]).

access_common(Payload) ->
    splunk_serv:send({access_common, Payload}).

