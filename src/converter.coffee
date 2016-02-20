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
            used = 0
            for v in attr.value when v.type is 'text'
                v.used = true
                used++
                dots = dots.concat v.value.split(/\s+/)
            attr.used = true if used is attr.value.length
        (dot for dot in dots when dot)

    checkChildrenOfHanlebarsBlockWithinHtmlAttribute: (children) ->
        for item in children when item.type isnt 'html_attribute'
            throw new Error('The children of handlebars block which is placed in html attributes can only contains html attributes')
converter =
    doctype: (tag, parent, indent, context, index) ->
        context.indent(indent).push('doctype ').push('html').eol()

    comments: (tag, parent, indent, context, index) ->
        context.indent(indent)
        if tag.value.length is 1
            return context.push('# ').push(tag.value[0]).eol()
        context.push('#.').eol()
        context.indent(indent + 1).push(item.trim()).eol() for item in tag.value when item

    textTag: (tag, parent, indent, context, index) ->
        if index is 0 and tag.value.length is 1
            return context.pop().push(' ').push(tag.value[0].trim()).eol()
        if tag.value.length is 1
            return context.indent(indent).push('| ').push(tag.value[0].trim()).eol()
        context.pop().push('.').eol()
        context.indent(indent).push(item.trim()).eol() for item in tag.value when item

    htmlTag: (tag, parent, indent, context, index) ->
        context.indent(indent).push(tag.name)
        hash = util.getHash(tag.attributes)
        context.push('#').push(hash) if hash
        dots = util.getDots(tag.attributes)
        for dot in dots
            context.push('.').push dot

        converter.htmlAttributes(tag.attributes, tag, indent, context)
        context.eol()
        return if tag.selfClosing
        converter.children(tag.children, tag, indent + 1, context)

    htmlAttributes: (attributes, parent, indent, context) ->
        return unless attributes
        converter.handlebarsBlockInHtmlAttributes attributes, parent, indent, context
        unused = (attr for attr in attributes when not attr.used)
        return if unused.length is 0
        handlebars = []
        context.push('(')
        for attr, i in unused
            hbs = converter.htmlAttribute attr, parent, indent, context, i is unused.length - 1
            handlebars = handlebars.concat hbs
        context.push(')')
        if handlebars.length > 0
            for item in handlebars
                converter.handlebarsBlockInHtmlAttributeValue item.name, item.tag, parent, indent, context

    htmlAttribute: (attribute, parent, indent, context, last) ->
        handlebars = []
        context.push(attribute.name)
        if attribute.value
            haveContent = false
            context.push '='
            for v in attribute.value when not v.used
                context.push ' + ' if haveContent
                if v.type is 'text'
                    context.push "'#{v.value}'"
                    haveContent = true
                else if v.type is 'handlebars' and v.selfClosing is true
                    context.push v.name
                    haveContent = true
                else if v.type is 'handlebars' and not v.selfClosing
                    handlebars.push name: attribute.name, tag: v
        context.push ' ' unless last
        handlebars

    handlebarsBlockInHtmlAttributes: (attributes, parent, indent, context) ->
        for attr in attributes when attr.type is 'handlebars'
            attr.used = true
            util.checkChildrenOfHanlebarsBlockWithinHtmlAttribute(attr.children)
            converter.htmlAttributes(attr.children, parent, indent, context)
            context.push('&').push(attr.name)
            converter.handlebarsAttributes(attr.attributes, attr, indent, context)

    handlebarsBlockInHtmlAttributeValue: (name, tag, parent, indent, context) ->
        context.push('(').push(name).push('=')
        haveContent = false
        for item in tag.children
            context.push ' + ' if haveContent
            if item.type is 'text'
                context.push "'#{item.value.join('')}'"
                haveContent = true
            if item.type is 'handlebars'
                context.push item.name
        context.push(')&').push tag.name
        converter.handlebarsAttributes tag.attributes, tag, indent, context

    handlebarsTag: (tag, parent, indent, context, index) ->
        context.indent(indent)
        if tag.selfClosing and not tag.attributes
            return context.push("echo(#{tag.name})").eol()

        context.push(tag.name)
        converter.handlebarsAttributes tag.attributes, tag, indent, context
        context.eol()

        return if tag.selfClosing
        converter.children tag.children, tag, indent + 1, context

    handlebarsAttributes: (attributes, parent, indent, context) ->
        return unless attributes
        context.push '('
        haveContent = false
        for item in attributes when item.type is 'handlebars_attribute'
            context.push ' ' if haveContent
            if not item.value
                context.push if item.name.type is 'quoted' then "'#{item.name.value}'" else item.name.value
                haveContent = true
            else
                context.push(item.name.value).push('=')
                context.push if item.value.type is 'quoted' then "'#{item.value.value}'" else item.value.value
                haveContent = true
        context.push ')'

    children: (children, parent, indent, context) ->
        typeMap[item.type] item, parent, indent, context, i for item, i in children

typeMap =
    'doctype': converter.doctype
    'comment': converter.comments
    'html': converter.htmlTag
    'handlebars': converter.handlebarsTag
    'text': converter.textTag

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
    context.getOutput()
