Context = require './context'
parser = require './parser'

util =
    getHash: (attributes = []) ->
        for attr in attributes when attr.type is 'html_attribute' and attr.value and attr.name is 'id'
            if attr.value.length is 1 and attr.value[0].type is 'text'
                attr.used = true
                return attr.value[0].value.trim()
        return false

    getDots: (attributes = []) ->
        dots = []
        for attr in attributes when attr.type is 'html_attribute' and attr.value and attr.name is 'class'
            for v in attr.value when v.type is 'text'
                v.used = true
                dots = dots.concat v.value.split(/\s+/)
        (dot for dot in dots when dot)

    checkChildrenOfHanlebarsBlockWithinHtmlAttribute: (children) ->
        for item in children when item.type isnt 'html_attribute'
            throw new Error('The children of handlebars block which is placed in html attributes can only contains html attributes')
typeMap =
    'doctype': converter.doctype
    'comment': converter.comments
    'html': converter.htmlTag
    'handlebars': converter.handlebarsTag
    'text': converter.textTag

converter =
    doctype: (tag, parent, indent, context, index) ->
        context.indent(indent).push('doctype ').push('html').eol()

    comments: (tag, parent, indent, context, index) ->
        context.indent(indent)
        if tag.value.length is 1
            return context.push('# ').push(tag.value[0]).eol()
        context.indent(indent).push '#.'
        context.indent(indent + 1).push(item.trim()).eol() for item in tag.value when item

    textTag: (tag, parent, indent, context, index) ->
        if index is 0 and tag.value.length is 1
            return context.push(' ').push(tag.value[0].trim()).eol()
        if tag.value.length is 1
            return context.indent(indent).push('| ').push(tag.value[0].trim()).eol()
        context.indent(indent).push '|.'
        context.indent(indent + 1).push(item.trim()).eol() for item in tag.value when item

    htmlTag: (tag, parent, indent, context, index) ->
        context.indent(indent).push(tag.name)
        hash = util.getHash(tag.attributes)
        context.push('#').push(hash) if hash
        dots = util.getDots(tag.attributes)
        for dot in dots
            context.push('.').push dot

        converter.htmlAttributes(tag.attributes, tag, indent, context)
        converter.children(tag.children, tag, indent + 1, context)

    htmlAttributes: (attributes, parent, indent, context) ->
        handlebarsBlockInHtmlAttributes attributes, parent, indent, context
        for attr in attributes when not attr.used

    handlebarsBlockInHtmlAttributes: (attributes, parent, indent, context) ->
        for attr in attributes when attr.type is 'handlebars'
            attr.used = true
            checkChildrenOfHanlebarsBlockWithinHtmlAttribute(attr.children)
            converter.htmlAttributes(attr.children)
            context.push('&').push(attr.name)
            converter.handlebarsAttributes(attr.attributes, attr, indent, context)

    handlebarsTag: (tag, parent, indent, context, index) ->

    handlebarsAttributes: (attributes, parent, indent, context) ->

    children: (children, parent, indent, context) ->
        typeMap[item.type] item, parent, indent, context, i for item, i in children


exports.convert = (input, options = {}) ->
    context = new Context(options.indentToken, options.newlineToken)
    try
        tags = parser.parse input
    catch e
        if e instanceof parser.SyntaxError
            throw new Error("#{e.message} [line: #{e.line}, column: #{e.column}]")
        else
            throw e
    converter.children tags, {}, 0, context
