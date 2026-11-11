{{#ret}}{{ret}} {{/ret}}{{name}}({{params}}){{#async}} async{{/async}} {
{{#decor.requires}}
  final denied = Guards.check({{decor.requires.args}});
  if (denied != null) return Left({{#ret_info.err_is.string}}denied{{/ret_info.err_is.string}}{{^ret_info.err_is.string}}{{ret_info.err}}(message: denied){{/ret_info.err_is.string}});
{{/decor.requires}}
{{#decor.acl}}
  final forbidden = {{#async}}await Guards.verify{{/async}}{{^async}}Guards.check{{/async}}({{decor.acl.args}});
  if (forbidden != null) return Left({{#ret_info.err_is.string}}forbidden{{/ret_info.err_is.string}}{{^ret_info.err_is.string}}{{ret_info.err}}(message: forbidden){{/ret_info.err_is.string}});
{{/decor.acl}}
  {{body}}
}
