{{#ret_info.result}}
{{ret}} {{name}}({{params}}) => attempt(
      () => send(
        HttpMethod.{{#decor.get}}get{{/decor.get}}{{#decor.post}}post{{/decor.post}}{{#decor.put}}put{{/decor.put}}{{#decor.patch}}patch{{/decor.patch}}{{#decor.delete}}delete{{/decor.delete}},
        {{#deco_args.path}}{{deco_args.path}}{{/deco_args.path}}{{^deco_args.path}}''{{/deco_args.path}},
{{#param_groups.plain}}
        params: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.plain}}
{{#param_groups.path}}
        pathParams: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.path}}
{{#param_groups.query}}
        query: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.query}}
{{#param_groups.body}}
        body: {{#list}}{{name}}{{/list}},
{{/param_groups.body}}
{{#deco_args.headers}}
        headers: {{deco_args.headers}},
{{/deco_args.headers}}
{{#deco_args.cache}}
        cache: Cache({{#deco_args.cacheKey}}key: {{deco_args.cacheKey}}{{#deco_args.ttl}}, {{/deco_args.ttl}}{{/deco_args.cacheKey}}{{#deco_args.ttl}}ttl: {{deco_args.ttl}}{{/deco_args.ttl}}),
        cacheName: '{{owner}}.{{name}}',
{{/deco_args.cache}}
{{#deco_args.retry}}
        retry: {{deco_args.retry}},
{{/deco_args.retry}}
{{#decor.get}}
{{#deco_args.local or owner_decor.repository.saveLocal}}
{{#ret_info.model}}
{{^ret_info.args}}
        local: '{{owner}}.{{name}}',
{{/ret_info.args}}
{{/ret_info.model}}
{{/deco_args.local or owner_decor.repository.saveLocal}}
{{/decor.get}}
        decode: {{#ret_info.void}}Decode.none{{/ret_info.void}}{{^ret_info.void}}{{#ret_info.model}}{{#ret_info.list}}Decode.list({{ret_info.item}}.fromJson){{/ret_info.list}}{{^ret_info.list}}{{#ret_info.args}}{{#@first}}Decode.one((json) => {{ret_info.item}}.fromJson(json{{/@first}}, {{#model}}(o) => {{item}}.fromJson(o as Map<String, dynamic>){{/model}}{{^model}}(o) => o as {{type}}{{/model}}{{#@last}})){{/@last}}{{/ret_info.args}}{{^ret_info.args}}Decode.one({{ret_info.item}}.fromJson){{/ret_info.args}}{{/ret_info.list}}{{/ret_info.model}}{{^ret_info.model}}{{#ret_info.list}}Decode.values{{/ret_info.list}}{{^ret_info.list}}Decode.value{{/ret_info.list}}{{/ret_info.model}}{{/ret_info.void}},
      ),
      Right.new,
      (e) => Left({{#ret_info.err_is.string}}e.message{{/ret_info.err_is.string}}{{^ret_info.err_is.string}}{{ret_info.err}}(message: e.message){{/ret_info.err_is.string}}),
    );
{{/ret_info.result}}
{{^ret_info.result}}
{{ret}} {{name}}({{params}}) => send(
      HttpMethod.{{#decor.get}}get{{/decor.get}}{{#decor.post}}post{{/decor.post}}{{#decor.put}}put{{/decor.put}}{{#decor.patch}}patch{{/decor.patch}}{{#decor.delete}}delete{{/decor.delete}},
      {{#deco_args.path}}{{deco_args.path}}{{/deco_args.path}}{{^deco_args.path}}''{{/deco_args.path}},
{{#param_groups.plain}}
      params: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.plain}}
{{#param_groups.path}}
      pathParams: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.path}}
{{#param_groups.query}}
      query: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.query}}
{{#param_groups.body}}
      body: {{#list}}{{name}}{{/list}},
{{/param_groups.body}}
{{#deco_args.headers}}
      headers: {{deco_args.headers}},
{{/deco_args.headers}}
{{#deco_args.cache}}
      cache: Cache({{#deco_args.cacheKey}}key: {{deco_args.cacheKey}}{{#deco_args.ttl}}, {{/deco_args.ttl}}{{/deco_args.cacheKey}}{{#deco_args.ttl}}ttl: {{deco_args.ttl}}{{/deco_args.ttl}}),
      cacheName: '{{owner}}.{{name}}',
{{/deco_args.cache}}
{{#deco_args.retry}}
      retry: {{deco_args.retry}},
{{/deco_args.retry}}
{{#decor.get}}
{{#deco_args.local or owner_decor.repository.saveLocal}}
{{#ret_info.model}}
{{^ret_info.args}}
      local: '{{owner}}.{{name}}',
{{/ret_info.args}}
{{/ret_info.model}}
{{/deco_args.local or owner_decor.repository.saveLocal}}
{{/decor.get}}
      decode: {{#ret_info.void}}Decode.none{{/ret_info.void}}{{^ret_info.void}}{{#ret_info.model}}{{#ret_info.list}}Decode.list({{ret_info.item}}.fromJson){{/ret_info.list}}{{^ret_info.list}}{{#ret_info.args}}{{#@first}}Decode.one((json) => {{ret_info.item}}.fromJson(json{{/@first}}, {{#model}}(o) => {{item}}.fromJson(o as Map<String, dynamic>){{/model}}{{^model}}(o) => o as {{type}}{{/model}}{{#@last}})){{/@last}}{{/ret_info.args}}{{^ret_info.args}}Decode.one({{ret_info.item}}.fromJson){{/ret_info.args}}{{/ret_info.list}}{{/ret_info.model}}{{^ret_info.model}}{{#ret_info.list}}Decode.values{{/ret_info.list}}{{^ret_info.list}}Decode.value{{/ret_info.list}}{{/ret_info.model}}{{/ret_info.void}},
    );
{{/ret_info.result}}
{{#deco_args.cache}}

void purge{{name|pascal}}() => purgeCache({{#deco_args.cacheKey}}{{deco_args.cacheKey}}{{/deco_args.cacheKey}}{{^deco_args.cacheKey}}'{{owner}}.{{name}}'{{/deco_args.cacheKey}});
{{/deco_args.cache}}
{{#decor.get}}
{{#deco_args.local or owner_decor.repository.saveLocal}}
{{#ret_info.model}}
{{^ret_info.args}}

/// What `{{name}}` last answered for these arguments, from the local database: no request.
{{#ret_info.result}}
{{ret}} {{name}}AsLocal({{params}}) => attempt(
      () => recall(
        '{{owner}}.{{name}}',
        {{#deco_args.path}}{{deco_args.path}}{{/deco_args.path}}{{^deco_args.path}}''{{/deco_args.path}},
{{#param_groups.plain}}
        params: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.plain}}
{{#param_groups.path}}
        pathParams: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.path}}
{{#param_groups.query}}
        query: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.query}}
        decode: {{#ret_info.list}}Decode.list({{ret_info.item}}.fromJson){{/ret_info.list}}{{^ret_info.list}}Decode.one({{ret_info.item}}.fromJson){{/ret_info.list}},
      ),
      Right.new,
      (e) => Left({{#ret_info.err_is.string}}e.message{{/ret_info.err_is.string}}{{^ret_info.err_is.string}}{{ret_info.err}}(message: e.message){{/ret_info.err_is.string}}),
    );
{{/ret_info.result}}
{{^ret_info.result}}
{{ret}} {{name}}AsLocal({{params}}) => recall(
      '{{owner}}.{{name}}',
      {{#deco_args.path}}{{deco_args.path}}{{/deco_args.path}}{{^deco_args.path}}''{{/deco_args.path}},
{{#param_groups.plain}}
      params: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.plain}}
{{#param_groups.path}}
      pathParams: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.path}}
{{#param_groups.query}}
      query: {{{#list}}'{{name}}': {{name}}{{^@last}}, {{/@last}}{{/list}}},
{{/param_groups.query}}
      decode: {{#ret_info.list}}Decode.list({{ret_info.item}}.fromJson){{/ret_info.list}}{{^ret_info.list}}Decode.one({{ret_info.item}}.fromJson){{/ret_info.list}},
    );
{{/ret_info.result}}
{{/ret_info.args}}
{{/ret_info.model}}
{{/deco_args.local or owner_decor.repository.saveLocal}}
{{/decor.get}}
