# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# This PortGroup accommodates golang projects hosted at GitHub.
# Assumes use with github-1.0 PortGroup.

options go.vendors

options go.binary_name
default go.binary_name  {${name}}

default use_configure   no

default depends_build   port:go

default build.cmd       go
default build.target    build
default build.env       {"GOPATH=${gopath} CC=${configure.cc}"}

# go.vendors-append name1 ver1 name2 ver2...
# When a glide.lock is present:
# $ curl https://raw.githubusercontent.com/${github.author}/${github.project}/${version}/glide.lock |
#   ruby -r yaml -e 'YAML.load(ARGF)["imports"].each{|d| puts d["name"]+" "+d["version"]}'
proc go.vendors-append {args} {
    global go.vendors

    foreach {imp_name vers} ${args} {
        set vlist [split ${imp_name} /]

        set vdomain [lindex ${vlist} 0]
        set vuser [lindex ${vlist} 1]
        set vname [lindex ${vlist} 2]

        switch -exact ${vdomain} {
            github.com { set ghuser ${vuser} }
            golang.org { set ghuser golang }
            gopkg.in {
                if {$vname eq ""} {
                    set vname [regsub -- \\..*$ ${vuser} ""]
                    set ghuser go-${vname}
                } else {
                    set vname [regsub -- \\..*$ ${vname} ""]
                    set ghuser ${vuser}
                }
            }
        }

        set sha1_short [string range ${vers} 0 6]
        lappend go.vendors [list ${sha1_short} ${imp_name} ${vers}]

        global ${vname}.version
        set ${vname}.version ${vers}

        set fname ${ghuser}-${vname}
        master_sites-append https://github.com/${ghuser}/${vname}/tarball/${vers}:${fname}
        distfiles-append    ${fname}-${vers}.tar.gz:${fname}
    }
}

# setup build sources as gopath style:
#   workpath/
#       ${name}-${version}/
#       gopath/src/github.com/
#           author1/project1/
#           author2/project2/
#             :
set gopath      ${workpath}/gopath
post-extract {
    file mkdir ${gopath}/src/github.com/${github.author}
    ln -s ${worksrcpath} ${gopath}/src/github.com/${github.author}/${github.project}

    foreach vlist ${go.vendors} {
        set sha1_short [lindex ${vlist} 0]
        set imp_name [lindex ${vlist} 1]
        file mkdir ${gopath}/src/[file dirname ${imp_name}]
        move [glob ${workpath}/*-${sha1_short}] ${gopath}/src/${imp_name}
    }
}

destroot {
    xinstall -m 755 ${worksrcpath}/${go.binary_name} ${destroot}${prefix}/bin
}
