fs = require 'fs'
path = require 'path'
{convert} = require './converter'

SLEET_FILE = '.sleet'
DEFAULT_INPUT_EXT = 'html'
MODE = 0o777 & ~process.umask()
VERSION = 'Sleet version <%= version %>'

yargs = require('yargs').usage '$0 [options] input.st [input2.st...]'
    .describe 'o', 'The output directory'
    .describe 'e', 'The file extension of input file. Default is html'
    .describe 'v', 'Show the version number'
    .describe 'h', 'Show this message'
    .alias 'o', 'output'
    .alias 'e', 'extension'
    .alias 'v', 'version'
    .alias 'h', 'help'
    .boolean 'v'
    .boolean 'h'
    .string 'e'
    .string 'o'

exports.run = ->
    argv = yargs.argv

    argv.files = argv._.slice()
    return yargs.showHelp() if argv.h
    return console.log VERSION if argv.v

    runIt argv

runIt = exports.runIt = (options) ->
    files = checkExists(options.files or [])
    return unless files.length > 0

    for file in files
        (if fs.statSync(file).isDirectory() then compileDir else compileFile) file, options

checkExists = (files) ->
    results = []
    for file in files
        if fs.existsSync file
            results.push path.resolve file
        else
            console.error "The specified file '#{file}' is not exists"
    results

compileFile = (file, options) ->
    compileIt file, getOutputFile(file, options), options

compileDir = (dir, options) ->
    for file in getDirctoryFiles path.resolve(dir), options.e or DEFAULT_INPUT_EXT
        compileIt file, getOutputFile(file, options, dir), options

getDirctoryFiles = (dir, ext) ->
    result = []
    dirfiles dir, result, ext
    result

dirfiles = (dir, result, ext) ->
    for file in fs.readdirSync dir
        name = path.join dir, file
        if fs.statSync(name).isDirectory()
            dirfiles name, result, ext
        else if isTarget(name, ext)
            result.push name

isTarget = (name, ext) ->
    path.extname(name).slice(1) is ext

compileIt = (input, out, options) ->
    console.log "#{new Date().toLocaleTimeString()} - Start to convert '#{input}'"
    content = fs.readFileSync(input, 'utf8')
    try
        output = convert content
    catch e
        return console.log e.stack

    fs.writeFileSync out, output, 'utf8'
    console.log "#{new Date().toLocaleTimeString()} - Converted '#{input}' to '#{out}'"

getOutputFile = (file, options, base) ->
    name = path.basename(file, path.extname(file)) + SLEET_FILE
    dir = path.dirname file
    base or= dir
    if options.o
        dir = path.join path.resolve('.'), options.o, path.relative(base, dir)
        mkdirp dir
        path.join dir, name
    else
        path.join dir, name

mkdirp = (dir) ->
    return if fs.existsSync(dir)
    mkdirp path.dirname(dir)
    fs.mkdir dir, MODE
