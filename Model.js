function pluginName(plugin) {
    if (!plugin) return "Plugin"
    return String(plugin.name || plugin.id || "Plugin")
}

function kindLabel(kind) {
    var labels = {
        "bar-widget": "Bar widget",
        "bar": "Bar",
        "panel": "Panel",
        "service": "Service",
        "overlay": "Overlay",
        "menu": "Menu"
    }
    var value = String(kind || "").trim()
    return labels[value] || value.replace(/[-_]+/g, " ").replace(/\b\w/g, function(letter) {
        return letter.toUpperCase()
    })
}

function pluginMetadata(plugin) {
    if (!plugin) return ""
    var kinds = Array.isArray(plugin.kinds) ? plugin.kinds : []
    var labels = []
    for (var i = 0; i < kinds.length; i++) {
        var label = kindLabel(kinds[i])
        if (label && labels.indexOf(label) === -1) labels.push(label)
    }
    return labels.join(" · ")
}

function sortPlugins(plugins) {
    if (!Array.isArray(plugins)) return []

    var manageable = plugins.filter(function(plugin) {
        return plugin && typeof plugin.id === "string" && plugin.id.trim() !== ""
            && plugin.canDisable !== false
    })

    manageable.sort(function(a, b) {
        var partyOrder = (a.firstParty ? 1 : 0) - (b.firstParty ? 1 : 0)
        if (partyOrder !== 0) return partyOrder

        var nameOrder = pluginName(a).localeCompare(pluginName(b))
        return nameOrder !== 0 ? nameOrder : String(a.id).localeCompare(String(b.id))
    })

    return manageable
}

if (typeof module !== "undefined") {
    module.exports = {
        pluginName: pluginName,
        kindLabel: kindLabel,
        pluginMetadata: pluginMetadata,
        sortPlugins: sortPlugins
    }
}
