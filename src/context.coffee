module.exports = class Context
    constructor: (@indentToken = '    ', @newlineToken = '\n') ->
        @result = []
        @defaultLevel = 0

    getIndent: (level) ->
        idt = ''
        idt += @indentToken for i in [0...level + @defaultLevel]
        idt

    indent: (level) ->
        @indented = true
        idt = @getIndent level
        @result.push idt if idt.length > 0
        @

    eol: ->
        @result.push @newlineToken
        @

    push: (text) ->
        @result.push text
        @

    pop: ->
        @result.pop()
        @

    last: (length) ->
        @result.slice -length

    getOutput: ->
        @result.join('')
