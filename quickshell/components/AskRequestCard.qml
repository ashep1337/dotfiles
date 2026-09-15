import QtQuick
import QtQuick.Controls
import qs
import qs.services

Rectangle {
    id: card
    required property var request
    readonly property var params: request.params
    readonly property bool questions: request.method === "item/tool/requestUserInput"
    readonly property bool elicitation: request.method === "mcpServer/elicitation/request"
    readonly property bool permissions: request.method === "item/permissions/requestApproval"
    readonly property bool form: elicitation && params.mode === "form"
    readonly property var fields: {
        if (questions) return params.questions || []
        if (!form) return []
        var schema = params.requestedSchema || {}
        var properties = schema.properties || {}
        var result = []
        for (var key in properties) {
            var field = properties[key]
            result.push({ id: key, question: field.title || key,
                description: field.description || "", valueType: field.type,
                required: (schema.required || []).indexOf(key) !== -1,
                options: (field.enum || (field.type === "boolean" ? [true, false] : [])).map(function(v) {
                    return { label: String(v), description: "" }
                }) })
        }
        return result
    }
    property string validationError: ""
    readonly property var values: Ask.requestDrafts[String(request.id)] || ({})
    readonly property bool canAccept: {
        if (elicitation && params.mode !== "form" && params.mode !== "url") return false
        if (form) {
            for (var i = 0; i < fields.length; i++)
                if (["string", "number", "integer", "boolean"].indexOf(fields[i].valueType) === -1) return false
        }
        if (request.method !== "item/commandExecution/requestApproval") return true
        return !params.availableDecisions || params.availableDecisions.indexOf("accept") !== -1
    }

    function answer(key, value) { Ask.saveRequestDraft(request.id, key, value) }
    function submit(accept) {
        validationError = ""
        if (questions || form) {
            var answers = {}
            for (var i = 0; i < fields.length; i++) {
                var field = fields[i]
                var value = values[field.id] || ""
                if (accept && !value.trim() && (questions || field.required)) {
                    validationError = "Please answer: " + field.question
                    return
                }
                if (questions) answers[field.id] = { answers: accept ? [value] : [] }
                else if (accept && value !== "") {
                    if (field.options && field.options.length && !field.options.some(function(o) { return o.label === value })) {
                        validationError = "Choose an option for " + field.question
                        return
                    }
                    if (field.valueType === "number" || field.valueType === "integer") {
                        var number = Number(value)
                        if (!isFinite(number) || (field.valueType === "integer" && Math.floor(number) !== number)) {
                            validationError = "Enter a valid number for " + field.question
                            return
                        }
                        answers[field.id] = number
                    } else if (field.valueType === "boolean") answers[field.id] = value === "true"
                    else answers[field.id] = value
                }
            }
            Ask.respond(request.id, questions ? { answers: answers }
                        : { action: accept ? "accept" : "decline", content: accept ? answers : null })
        } else if (permissions) {
            Ask.respond(request.id, { permissions: accept ? params.permissions : {}, scope: "turn" })
        } else if (elicitation) {
            Ask.respond(request.id, { action: accept ? "accept" : "decline", content: null })
        } else {
            var decision = accept ? "accept" : "decline"
            if (!accept && params.availableDecisions && params.availableDecisions.indexOf(decision) === -1) {
                Ask.cancel()
                return
            }
            Ask.respond(request.id, { decision: decision })
        }
    }

    height: body.implicitHeight + 20
    radius: 6
    color: Theme.colPopupInset
    border.color: Theme.colPurpleGlow
    Column {
        id: body
        x: 10
        y: 10
        width: parent.width - 20
        spacing: 8
        Text {
            width: parent.width
            text: card.questions ? "Codex has a question" : (card.elicitation
                ? "Request from " + card.params.serverName : "Codex needs your approval")
            textFormat: Text.PlainText
            color: Theme.colPurpleGlow
            font.family: Theme.fontFamily
            font.bold: true
            wrapMode: Text.Wrap
        }
        TextEdit {
            width: parent.width
            readOnly: true
            selectByMouse: true
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            color: Theme.colFg
            font.family: Theme.fontFamily
            font.pixelSize: 12
            text: {
                var p = card.params
                var parts = []
                if (p.reason) parts.push(p.reason)
                if (p.message) parts.push(p.message)
                if (p.networkApprovalContext) parts.push("Network access: " + p.networkApprovalContext.host
                                                       + " (" + p.networkApprovalContext.protocol + ")")
                if (p.command) parts.push(p.command)
                if (p.cwd) parts.push("Directory: " + p.cwd)
                if (p.grantRoot) parts.push("Allow changes under: " + p.grantRoot)
                if (p.additionalPermissions) parts.push(JSON.stringify(p.additionalPermissions, null, 2))
                if (card.permissions) parts.push(JSON.stringify(p.permissions, null, 2))
                if (card.request.item && card.request.item.type === "fileChange") {
                    var changes = card.request.item.changes || []
                    for (var i = 0; i < changes.length; i++) parts.push(changes[i].path + "\n" + changes[i].diff)
                }
                if (p.url) parts.push("Complete the request at this URL, then confirm:\n" + p.url)
                if (card.elicitation && !card.canAccept) parts.push("This form type is not supported. You can decline the request.")
                return parts.join("\n\n")
            }
            visible: text !== ""
        }
        Repeater {
            model: card.fields
            Column {
                id: field
                required property var modelData
                width: body.width
                spacing: 5
                Text {
                    width: parent.width
                    text: field.modelData.question
                    textFormat: Text.PlainText
                    color: Theme.colFg
                    wrapMode: Text.Wrap
                }
                Repeater {
                    model: field.modelData.options || []
                    Button {
                        required property var modelData
                        width: field.width
                        text: modelData.label + (modelData.description ? " — " + modelData.description : "")
                        contentItem: Text {
                            text: parent.text
                            textFormat: Text.PlainText
                            color: Theme.colFg
                            wrapMode: Text.Wrap
                        }
                        background: Rectangle { color: Theme.colPurple; radius: 4 }
                        onClicked: card.answer(field.modelData.id, modelData.label)
                    }
                }
                TextField {
                    width: parent.width
                    text: card.values[field.modelData.id] || ""
                    placeholderText: "Your answer"
                    echoMode: field.modelData.isSecret ? TextInput.Password : TextInput.Normal
                    color: Theme.colFg
                    placeholderTextColor: Theme.colFgDim
                    background: Rectangle { color: Theme.colPopupBg; radius: 4 }
                    onTextEdited: card.answer(field.modelData.id, text)
                    Keys.onEscapePressed: Ask.cancel()
                }
            }
        }
        Text {
            visible: card.validationError !== ""
            text: card.validationError
            textFormat: Text.PlainText
            width: parent.width
            wrapMode: Text.Wrap
            color: Theme.colRed
        }
        Row {
            spacing: 8
            Button {
                text: card.questions || card.form ? "Submit" : "Allow once"
                visible: card.canAccept
                enabled: !Ask.cancelling
                onClicked: card.submit(true)
            }
            Button {
                text: card.questions ? "Skip" : "Decline"
                enabled: !Ask.cancelling
                onClicked: card.submit(false)
            }
            Button {
                text: "Cancel turn"
                enabled: !Ask.cancelling
                onClicked: Ask.cancel()
            }
        }
    }
}
