% Licensed under the Apache License, Version 2.0 (the "License"); you may not
% use this file except in compliance with the License. You may obtain a copy of
% the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
% WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
% License for the specific language governing permissions and limitations under
% the License.

-module(couchit_httpd).

-export([handle_site_req/1, vhost_handler/2]).

-include("../couchdb/couch_db.hrl").

-import(couch_httpd,
    [send_json/2,send_json/3,send_json/4,send_method_not_allowed/2,
    start_json_response/2,send_chunk/2,last_chunk/1,end_json_response/1,
    start_chunked_response/3, send_error/4]).



% vhost target is a db
% if db isn't found we forward to a page to create it
vhost_handler(MochiReq, VhostTarget) ->
    CouchitDB = couch_config:get("couchit", "db", "couchit"),
    Path =  MochiReq:get(raw_path),
   
    {"/" ++ TargetPath, _, _} = mochiweb_util:urlsplit_path(VhostTarget),
    {DbName, _, _} = mochiweb_util:partition(TargetPath, "/"),
    
    %% get target path
    Target = case DbName of
        CouchitDB ->
            VhostTarget ++ Path;
        _ ->
            case couch_db:open(?l2b(DbName), 
                [{user_ctx, #user_ctx{roles=[<<"_admin">>]}}]) of
            {ok, _} ->
                AppPath = VhostTarget ++ "/_design/couchit/_rewrite",
                AppPath ++ Path;
            _Else ->
                "/couchit/_design/manager/_rewrite/"
            end
    end,
             
    ?LOG_DEBUG("Vhost Target: '~p'~n", [Target]),
    
    Headers = mochiweb_headers:enter("x-couchdb-vhost-path", Path, 
        MochiReq:get(headers)),

    % build a new mochiweb request
    MochiReq1 = mochiweb_request:new(MochiReq:get(socket),
                                      MochiReq:get(method),
                                      Target,
                                      MochiReq:get(version),
                                      Headers),
    % cleanup, It force mochiweb to reparse raw uri.
    MochiReq1:cleanup(),

    MochiReq1.

handle_site_req(#httpd{method='POST'}=Req) ->
    couch_httpd:validate_ctype(Req, "application/json"),
    
    {Site} = couch_httpd:json_body_obj(Req),
    ?LOG_INFO("got ~p~n", [Site]),

    case proplists:get_value(<<"name">>, Site) of
        Name when is_binary(Name), size(Name) >= 3 ->
            case create_site(Name, Site) of
                ok -> 
                    send_json(Req, 200, {[{ok, true}]});
                Error ->
                    send_json(Req, 500, {[Error]})
            end;
        Else ->
            send_json(Req, 500, {[{error, 
                ?l2b(io_lib:format("Invalid site name: [~p]", [Else]))}]})
    end;

handle_site_req(Req) ->
    send_method_not_allowed(Req, "POST PUT DELETE").


create_site(Name, Site) ->
    ?LOG_INFO("Create Site: ~p~n", [Site]),
    case couch_server:create(Name, 
            [{user_ctx, #user_ctx{roles=[<<"_admin">>]}}]) of
    {ok, Db} ->
        CanWrite = proplists:get_value(<<"can_write">>, Site, 1),
        CanUpload =  proplists:get_value(<<"can_upload">>, Site, 1),
        CanDelete =  proplists:get_value(<<"can_delete">>, Site, 1),
        SecObj = {[
            {<<"site_name">>, Name},
            {<<"guest">>, {[
                {<<"can_write">>, CanWrite},
                {<<"can_delete">>, CanDelete},
                {<<"can_upload">>, CanUpload }
            ]}}
        ]},

        SecObj1 = case proplists:get_value(<<"guest_password">>, Site) of
        <<"">> -> 
            SecObj;
        Password when is_binary(Password) ->
            GuestUser = user_doc(Name, Password),
            
            % create user
            ok = save_user(GuestUser),

            % The site is private, create a reader.
            couchit_util:extend(<<"readers">>, {[{<<"names">>, [Name]}]},
                SecObj);
        _ ->
            SecObj
        end,

        %save the security object and close the db
        ok = couch_db:set_security(Db, SecObj1),
        couch_db:close(Db),

        % finaly createthe app
        start_replication(Name),
        ok; 
    Error ->
        {error, Error}
    end.

save_user(User) ->
    UserDoc = couch_doc:from_json_obj(User),
    couch_auth_cache:exec_if_auth_db(
        fun(AuthDb) ->
            Db = couch_auth_cache:reopen_auth_db(AuthDb),
            {ok, _Rev} = couch_db:update_doc(Db, UserDoc, [])
        end,
        fun() ->
            Db = couch_auth_cache:open_auth_db(),
            {ok, _Rev} = couch_db:update_doc(Db, UserDoc, [])
        end
    ),
    ok.

user_doc(UserName, Password) ->
    user_doc(UserName, Password, []).

user_doc(UserName, Password, Roles) ->
    Salt = couch_uuids:random(),
    Hashed = couch_util:to_hex(crypto:sha(?b2l(Password) ++ ?b2l(Salt))),
    {[
        {<<"_id">>, <<"org.couchdb.user:",UserName/binary>>},
        {<<"name">>, UserName},
        {<<"salt">>, Salt},
        {<<"password_sha">>, ?l2b(Hashed)},
        {<<"type">>, <<"user">>},
        {<<"roles">>, Roles}
    ]}.



start_replication(Name) ->
    CouchitDb = ?l2b(couch_config:get("couchit", "db", "couchit")),
    {ok, RepDb} = couch_rep:ensure_rep_db_exists(),
    RepDoc = {[
            {<<"_id">>, couch_uuids:new()},
            {<<"source">>, CouchitDb},
            {<<"target">>, Name},
            {<<"doc_ids">>, [<<"_design/couchit">>]}
    ]},

    couch_db:update_doc(RepDb, couch_doc:from_json_obj(RepDoc), []),
    ok.

