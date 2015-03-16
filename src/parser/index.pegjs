start
    = __ tags: tags? __ {
        return tags;
    }

tags
    = start: tag rest: (__ tag: tag __ { return tag; }) * {
        return rest.unshift(start) && rest;
    }

tag
    = doctype / comment / html / handlebars / text_tag

doctype
    = '<!DOCTYPE'i __ text: $(!'>' .)* '>' {
        return {type: 'doctype', value: text};
    }
    / '<?xml'i __ (!'?>' .)* '?>' {
        return {type: 'doctype', value: 'xml'};
    }

comment
    = '<!--' __ text: $(!'-->' .)* __ '-->' {
        return {type: 'comment', value: text.split('\n')};
    }

html
    = '<' name: identifier __ attr: html_attr? __ '>' __ tags: tags __ '</' close: identifier & {
        return close === name;
    } _ '>' {
        return {type: 'html', name: name, attributes: attr, children: tags, selfClosing: false};
    }
    / '<' name: identifier __ attr: html_attr? __ '/>' {
        return {type: 'html', name: name, attributes: attr, selfClosing: true};
    }

html_attr
    = first: ha rest: (__ h: ha {return h;})* {
        return rest.unshift(first) && rest;
    }

ha 'html attribute'
    = name: identifier __ '=' __ value: hav {
        return {type: 'html_attribute', name: name, value: value}
    }

hav 'html attribute value'
    = quoted_string / $(![ \'\">] .)+ {
        return text();
    }

handlebars
    = '{{#' name: identifier __ '}}' __ tags: tags __ '{{/' close: identifier & {
        return name === close;
    } _ '}}' {
        return {type: 'handlebars', name: name, attributes: '', children: tags, selfClosing: false};
    }
    / '{{{' name: identifier __ '}}}' {
        return {type: 'handlebars', name: name, attributes: '', selfClosing: true, unescape: true}
    }
    / '{{' name: identifier __ '}}' {
        return {type: 'handlebars', name: name, attributes: '', selfClosing: true}
    }

text_tag
    = text: $(!tag_start .)+ {
        return {type: 'text', value: text.trim().split('\n')}
    }

tag_start
    = '<!--' / '<!' / handlebars_start / html_start

handlebars_start
    = ( '{{{' / '{{#' / '{{/' / '{{') & identifier

html_start
    = ( '</' / '<') & identifier



///////////////////////
// basic rules start //
///////////////////////

_
    = ws*

__ "White spaces"
    = (ws / eol)*

identifier "Identifier"
    = start: [a-zA-Z$@_] rest: $[a-zA-Z0-9$_-]* {
        return start + rest;
    }

text_to_end "Text to end of line"
    = (!eol .)* {
        return text();
    }

eol "End of line"
    = '\n' / '\r' / '\r\n'

ws "Whitespace"
    = '\t' / ' ' / '\v' / '\f'

quoted_string "Quoted string"
    = '"' chars: $dqs* '"' { return chars; }
    / "'" chars: $sqs* "'" { return chars; }

dqs "Double quoted string char"
    = !('"' / '\\' / eol) . { return text(); }
    / '\\' char: ec { return char; }

sqs "Single quoted string char"
    = !("'" / '\\' / eol) . { return text(); }
    / '\\' char: ec { return char; }

ec "Escaped char"
    = '0' ![0-9] { return '\0' }
    / '"' / "'" / '\\'
    / c: [bnfrt] { return '\\' + c; }
    / 'b' { return '\x0B' }

/////////////////////
// basic rules end //
/////////////////////
