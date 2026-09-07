pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Unread mail via ~/bin/gmail-unread (IMAP).
// Polls rather than pushes; 2 minutes is well under any rate limit.
// The `checking` guard matters because IMAP logins are slow — without it a
// stalled connection would stack up a process per timer tick.
Singleton {
    id: gmail

    property int count: 0
    property var messages: []
    property string error: ""
    property bool checking: false

    function check() {
        if (gmail.checking) return
        gmail.checking = true
        mailProc.running = true
    }

    Process {
        id: mailProc
        command: [Quickshell.env("HOME") + "/bin/gmail-unread"]
        stdout: StdioCollector {
            id: mailOut
            onStreamFinished: {
                try {
                    var r = JSON.parse(mailOut.text.trim())
                    if (r.error) {
                        gmail.error = r.error
                        gmail.count = 0
                        gmail.messages = []
                    } else {
                        gmail.error = ""
                        gmail.count = r.count || 0
                        gmail.messages = r.messages || []
                    }
                } catch (e) {
                    gmail.error = "bad output from gmail-unread"
                }
            }
        }
        onExited: gmail.checking = false
    }
    Timer {
        interval: 120000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: gmail.check()
    }

    // ── Reading one message in place ──────────────────────────────────
    // The uid is the IMAP UID from the list; it stays valid as the mailbox
    // changes, unlike a sequence number.
    property string bodyUid: ""
    property string bodyFrom: ""
    property string bodySubject: ""
    property string bodyDate: ""
    property string bodyMsgid: ""
    property string bodyText: ""
    property string bodyError: ""
    property bool bodyLoading: false

    function openBody(m) {
        if (!m || !m.uid) return
        gmail.bodyUid = m.uid
        gmail.bodyFrom = m.from
        gmail.bodySubject = m.subject
        gmail.bodyDate = m.date || ""
        gmail.bodyMsgid = m.msgid || ""
        gmail.bodyText = ""
        gmail.bodyError = ""
        gmail.bodyLoading = true
        bodyProc.command = [Quickshell.env("HOME") + "/bin/gmail-unread",
                            "body", m.uid]
        bodyProc.running = true
    }
    function closeBody() {
        bodyProc.running = false
        gmail.bodyUid = ""
        gmail.bodyText = ""
        gmail.bodyError = ""
        gmail.bodyLoading = false
    }

    Process {
        id: bodyProc
        stdout: StdioCollector {
            id: bodyOut
            onStreamFinished: {
                try {
                    var r = JSON.parse(bodyOut.text.trim())
                    if (r.error) gmail.bodyError = r.error
                    else gmail.bodyText = r.body || ""
                } catch (e) {
                    gmail.bodyError = "bad output from gmail-unread"
                }
            }
        }
        onExited: gmail.bodyLoading = false
    }

    Process { id: openProc }

    // Opens the message itself in Gmail via its RFC822 Message-ID
    function openCurrentInGmail() {
        var url = "https://mail.google.com/"
        if (gmail.bodyMsgid !== "") {
            url += "mail/u/0/#search/rfc822msgid:"
                 + encodeURIComponent(gmail.bodyMsgid)
        }
        gmail.closeBody()
        gmail.openInBrowser(url)
    }
    function openInBrowser(url) {
        openProc.command = ["xdg-open", url || "https://mail.google.com/"]
        openProc.running = true
    }
}
