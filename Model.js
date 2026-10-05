function sortPlugins(plugins) {
    var filtered = plugins.filter(function(p) { return p.canDisable !== false })

    var thirdParty = []
    var firstParty = []

    for (var i = 0; i < filtered.length; i++) {
        var p = filtered[i]
        if (p.firstParty) firstParty.push(p)
        else thirdParty.push(p)
    }

    thirdParty.sort(function(a, b) { return a.name.localeCompare(b.name) })
    firstParty.sort(function(a, b) { return a.name.localeCompare(b.name) })

    return thirdParty.concat(firstParty)
}
