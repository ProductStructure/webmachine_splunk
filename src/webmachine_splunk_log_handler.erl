-module(webmachine_splunk_log_handler).

-behaviour(gen_event).

%% gen_event callbacks
-export([init/1,
         handle_call/2,
         handle_event/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-compile([{parse_transform, lager_transform}]).
-include_lib("webmachine/include/webmachine_logger.hrl").

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-record(state, {hourstamp, filename, handle}).

-define(FILENAME, "perf.log").

%% ===================================================================
%% gen_event callbacks
%% ===================================================================

%% @private
init([]) ->
  aws_credentials:s3(),
  {ok, {}}.

%% @private
handle_call({_Label, MRef, get_modules}, State) ->
    {ok, {MRef, [?MODULE]}, State};
handle_call({refresh, Time}, State) ->
    {ok, ok,State};
handle_call(_Request, State) ->
    {ok, ok, State}.

%% @private
handle_event({log_access, LogData = #wm_log_data{response_code = {500,_}}}, State) ->
  %HANDLE 500 HERE!
  Msg   = format_req(LogData),
  case application:get_env(splunk,sns_topic) of
    {ok, Topic} ->
      Ref   = make_ref(),
      aws_credentials:s3(),
      lager:error("Web Error ~p ~p", [Ref,lager:pr(LogData, ?MODULE)]),
      R     = sns:publish(Topic, "WebAPI Webmachine 500", io_lib:format("Error: ~p, Ref ~p", [LogData,Ref])),
      lager:info("AWS Response ~p",  [R]);
    undefined -> ok
  end,
  splunk:access_common(Msg),
  {ok, State};
handle_event({log_access, LogData}, State) ->
  Msg = format_req(LogData),
  splunk:access_common(Msg),
  {ok, State};
handle_event(_Event, State) ->
  {ok, State}.

%% @private
handle_info(_Info, State) ->
    {ok, State}.

%% @private
terminate(_Reason, _State) ->
    ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

-spec(format_req(#wm_log_data{}) -> iolist()).
format_req(#wm_log_data{resource_module = Mod,
                        start_time      = StartTime,
                        method          = Method,
                        peer            = Peer,
                        path            = Path,
                        version         = Version,
                        response_code   = ResponseCode,
                        response_length = ResponseLength,
                        end_time        = EndTime,
                        finish_time     = FinishTime}) ->
    Time        = webmachine_log:fmtnow(),
    Status      = case ResponseCode of
                      {Code, _ReasonPhrase} when is_integer(Code)  ->
                          integer_to_list(Code);
                      _ when is_integer(ResponseCode) ->
                          integer_to_list(ResponseCode);
                      _ ->
                          ResponseCode
                  end,
    Length      = integer_to_list(ResponseLength),
    TTPD        = webmachine_util:now_diff_milliseconds(EndTime, StartTime),
    TTPS        = webmachine_util:now_diff_milliseconds(FinishTime, EndTime),
    fmt_plog(Time, 
             Peer, 
             atom_to_list(Method),
             Path,
             Version,
             Status,
             Length,
             atom_to_list(Mod),
             integer_to_list(TTPD),
             integer_to_list(TTPS)).


fmt_plog(Time, Ip,  Method, Path, {VM,Vm}, Status, Length, Mod, TTPD, TTPS) ->
    [webmachine_log:fmt_ip(Ip), " - ", [$\s], Time, [$\s, $"], Method, " ", Path,
     " HTTP/", integer_to_list(VM), ".", integer_to_list(Vm), [$",$\s],
     Status, [$\s], Length, " " , Mod, " ", TTPD, " ", TTPS, $\n].
