# try
#     winpath = realpath("html/mainwin.html")
#     @assert isfile(winpath)
# catch
#     @warn "The default file mainwin.html cannot be found."
# end


function initcontents(fpath=winpath)
    contents = open(fpath, "r") do file
        read(file)
    end
    return String(contents)
end

function mainwin(fpath=winpath)
    win = Window();
    wincontent = initcontents(fpath)
    content!(win, "html", wincontent; async=false)
    return win
end

# may not work if called during interaction
getelemval(win, id) = js(win, Blink.JSString("""document.getElementById("$id").value"""))

setelemval(win, id, newval) = js(win, Blink.JSString("""el = document.getElementById("$id"); el.value = "$newval";"""); callback=false)

checkelem(win, id, newval::Bool) = js(win, Blink.JSString("""el = document.getElementById("$id"); el.checked = $newval;"""); callback=false)

disableinputelem(win, id) = js(win, Blink.JSString("""el = document.getElementById("$id"); el.disabled = true;"""); callback=false)

getforminputs(d, form) = filter(e -> (e.second.parentformid == Symbol(form)), d) 

function getpkgid(d, pkname)
    for (_, el) in d
        el.value == pkname && return el.id => pkname
    end
    return nothing
end

function getpkgids(d, pknames)
    items = [getpkgid(d, pkname) for pkname in pknames]
    return Dict([item for item in items if ! isnothing(item) ])
end

function check_entries_def_installed(win, initvals)
    pkgs = default_env_packages()
    form1 = getforminputs(initvals, :deflt_pkg)
    installed_pks = getpkgids(form1, pkgs)
    for item in keys(installed_pks)
        checkelem(win, item, true)
        # disableinputelem(win, item)
    end
    return nothing
end

handleinit_input() = nothing # println("init_input finished")

function handlefinalinput(win, finalvals, submit::Bool; make_prj = false) 
    close(win)
    submit && make_prj && return create_proj(finalvals)
    global processing_finished = true

    return nothing
end


function handlechangeevents(win, newvals, initvals, finalvals; make_prj = false)
    handle(win, "change") do arg
        if arg["reason"] == "external_link"
            openurl(arg["url"])
        else
            if arg["reason"] in ["newinput", "init_input", "finalinput"]
                id = Symbol(arg["elid"])
                eltype = Symbol(arg["eltype"])
                elclass = arg["elclass"] |> split .|> String
                inputtype = Symbol(arg["inputtype"])
                parentformid = Symbol(arg["parentformid"])
                checked = arg["elchecked"]
                v = arg["elval"]
                el = HtmlElem(id, eltype, elclass, inputtype, parentformid, v, checked)
                arg["reason"] == "newinput" && push!(newvals, id => el)
                arg["reason"] == "init_input" && push!(initvals, id => el)
                arg["reason"] == "finalinput" && push!(finalvals, id => el)
            end
            arg["reason"] == "newinput" && handleinput(win, el, (; newvals, initvals))
            arg["reason"] == "init_inputfinished" && handleinit_input()
            arg["reason"] == "finalinputfinished" && handlefinalinput(win, finalvals, true; make_prj)
            arg["reason"] == "finalinputcancelled" && handlefinalinput(win, finalvals, false; make_prj)
        end
    end
end

function wait_until_finished()
    while ! processing_finished
        sleep(0.1)
    end
    sleep(0.05)
    return nothing
end

function initwin(wpath=make_html(); make_prj = false)
    global processing_finished = false
    global may_exit_julia = false
    win = mainwin(wpath);

    initvals = Dict{Symbol, HtmlElem}()
    newvals = deepcopy(initvals)
    finalvals = deepcopy(initvals)

    changeeventhandle = handlechangeevents(win, newvals, initvals, finalvals; make_prj)
    js(win, Blink.JSString("""sendfullstate(false, false)"""))
    check_entries_def_installed(win, initvals)
    wait_until_finished()
    return (;win, initvals, newvals, finalvals, changeeventhandle, wpath)
end

function showhide(win, id, show=true, duration=100) 
    jqselector = "#$(id)"
    jqaction = show ? "show($(duration))" : "hide($(duration))"
    js(win, Blink.JSString("""jQuery("$(jqselector)").$(jqaction)"""); callback=false)
    return nothing
end