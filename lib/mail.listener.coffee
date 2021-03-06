util             = require "util"
{EventEmitter}   = require "events"
# {MailParser}     = require "mailparser"
{ImapConnection} = require "imap"

# MailListener class. Can `emit` events in `node.js` fashion.
class MailListener extends EventEmitter

  constructor: (@account, @settings) ->
    throw new Error('MailListener: settings.mailbox not specified.') unless typeof @settings.mailbox == 'string'
    throw new Error('MailListener: settings.startDate not specified.') unless typeof @settings.startDate == 'object'
    
    @imap = new ImapConnection @account
  # start listener
  start: => 
    # 1. connect to imap server  
    @imap.connect (err) =>
      if err
        util.log "error connecting to mail server #{err}"
        @emit "error", err
      else
        util.log "successfully connected to mail server"
        @emit "server:connected"
        # set some error event listeners
        @imap.on 'close', (err) =>
          # console.log 'close', util.inspect(err)
          @emit 'server:close', err
        @imap.on 'error', (err) =>
          # console.log 'error', util.inspect(err)
          @emit 'server:error', err
        # 2. open mailbox
        util.log "open mailbox #{@settings.mailbox}"
        @imap.openBox @settings.mailbox, false, (err) =>
          if err
            util.log "error opening mail box #{err}"
            @emit "error", err
          else
            @emit "mailbox:connected"
            util.log "successfully opened mail box"
            # 3a. listen for mail changes
            @imap.on 'msgupdate', (msg) =>
              util.log "changed msg: ", util.inspect(msg)
              @emit 'mail:msgupdate', msg
            # 3b. listen for new emails in the inbox
            @search()
            @imap.on "mail", (id) =>
              util.log "new mail arrived with id #{id}"
              @emit "mail:arrived", id
              # 4. Search Emails
              @search()
  search: =>
    date = @settings.startDate
    date.setDate(date.getDate() - 1)
    console.log "Searchching #{@account.email} since: #{date}"
    # console.log "canflags: ", @imap.permFlags
    @imap.search [ 'ALL', ['SINCE', date] ], (err, searchResults) =>
      # console.log "searchResults: ", searchResults
      if err
        util.log "error searching emails #{err}"
        @emit "error", err
      else
        try
          util.log "found #{searchResults.length} emails"
          # 5. fetch emails
          self = @

          if searchResults.length > 0
            fetch = @imap.fetch searchResults,
              headers: parse: false
              body: true
              cb: (fetch) ->
                # 6. email was fetched. Parse it!   
                fetch.on "message", (msg) =>
                  raw = ""
                  msg.on "data", (data) ->
                    raw += data.toString()
                  msg.on "end", =>
                    # util.log "message flags: ", msg.flags
                    # util.log "message id: #{msg.uid}"
                    # util.log "fetched message: " + util.inspect(msg, false, 5)
                    # util.log "msg seqno", msg.seqno
                    # util.log "msg uid", msg.uid
                    # self.emit "mail:msgupdate", msg.uid, msg.flags
                    self.emit "mail:parsed", raw, msg.uid, msg.flags
        catch error
          util.log "Error fetching Emails from Account: #{error}"
                    
  # stop listener
  stop: =>
    @imap.logout =>
      @emit "server:disconnected"

module.exports = MailListener
