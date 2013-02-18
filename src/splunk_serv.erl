%%%-------------------------------------------------------------------
%%% @author Zachary Kessin <>
%%% @copyright (C) 2013, Zachary Kessin
%%% @doc
%%%
%%% @end
%%% Created : 18 Feb 2013 by Zachary Kessin <>
%%%-------------------------------------------------------------------
-module(splunk_serv).

-behaviour(gen_server).

%% API
-export([start_link/0, send/1, get_config/0, send_to_splunk/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {access_token, project_id}).

%%%===================================================================
%%% API
%%%===================================================================
send({access_common, Payload}) ->
    gen_server:cast(?MODULE, {access_common, Payload}).
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

init([]) ->
    State = get_config(),
    {ok, State}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.


%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({access_common, Msg}, State) ->
    send_to_splunk(Msg, State),
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

get_config() ->
    PrivDir		= code:priv_dir(splunk),
    KeyFile		= filename:join([PrivDir, "keys.config"]),
    {ok, [Keys]}	= file:consult(KeyFile),
    #state{access_token	= proplists:get_value(access_token, Keys),
	   project_id	= proplists:get_value(project_id,   Keys)}.


send_to_splunk(Msg, State) ->
    Url			= restc:construct_url(
					    "https://api.splunkstorm.com/1/inputs/http",
					    [{"index", State#state.project_id}, 
					     {"sourcetype", "access_common"}]),
    AuthHeader		= auth_header("X", binary_to_list(State#state.access_token)),
    ContentType		= "text/plain",
    Headers		= [AuthHeader, {"Content-Type", ContentType}],
    {ok, {{_, 200, "OK"},
	  Props, 
	  Payload}}	= httpc:request(post, 
					{Url, Headers, ContentType, Msg}, [], []),
    
    {Props,Payload}.

auth_header(User, Pass) ->
    Encoded		= base64:encode_to_string(lists:append([User,":",Pass])),
    {"Authorization","Basic " ++ Encoded}.
